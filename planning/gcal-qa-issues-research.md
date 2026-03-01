# Google Calendar Integration — QA Issues Research & Proposals

**Date**: March 1, 2026  
**Status**: Research complete — awaiting review before implementation

---

## 1. Email Collection Not Always Enforced

### Root Cause
Email enforcement is **prompt-only** — there is no backend guard. The system prompt marks email as "REQUIRED" for GCal via the `isGoogleCalendar` flag in two places:

- `utils.ts:1201` — `getIntakeTypeInstructions('email')` appends: *"This is REQUIRED so appointment confirmation and reminders can be sent via email — do not skip this step."*
- `utils.ts:1350` — `savingCallerInfoSection` appends: *"REQUIRED so appointment confirmation and reminders can be sent via email"*

However, neither the `submit_intake_answers` endpoint nor the `google-calendar-create-event` endpoint validates that an email was actually collected. The LLM can skip email collection (especially under conversational pressure or if the caller declines) and still create the event.

### Proposed Fix
**Two-layer approach:**

1. **Prompt strengthening** (low effort): Add a pre-booking gate in the GCal workflow section (`utils.ts:1861`). Before the line "Only use the create_google_calendar_event tool AFTER you have confirmed..." add email as an explicit prerequisite:
   > "You MUST have the caller's email address before creating an appointment. If the caller declines to provide an email, explain that it's needed for appointment confirmation and reminders, and ask once more. If they still decline, proceed without booking and offer a callback instead."

2. **Backend guard** (medium effort): In the `google-calendar-create-event` endpoint (`server.ts:11946`), check if `attendeeEmail` is present. If not, and the location has GCal connected, return a 400 error:
   ```
   "Email address is required for Google Calendar appointments. Please collect the caller's email before creating the event."
   ```
   This gives the LLM a tool-level error message that forces it to go back and collect email.

**Recommendation**: Do both. The prompt fix handles 95% of cases; the backend guard catches the rest.

---

## 2. Agent Says "2026" During Calls (Sounds Robotic)

### Root Cause
The current date/time context block injected in `server.ts:9440-9451` uses `toLocaleString` with `year: 'numeric'`, producing:

```
The current date and time is: Saturday, March 1, 2026, 12:09 AM (America/Los_Angeles timezone).
```

The LLM reads this context and then naturally includes the year when discussing appointment dates: *"I have an opening on Tuesday, March 4th, 2026."* This sounds robotic because humans don't say the year for near-future dates.

Additionally, the GCal workflow section in `utils.ts:1838` shows ISO 8601 examples with years: `"2025-11-10T14:00:00-08:00"` which further primes the LLM to include years.

### Proposed Fix
**Prompt-only fix** — add a speaking instruction to the GCal workflow section in `utils.ts`, near the CALENDAR BEST PRACTICES block (~line 1928):

```
**DATE PRONUNCIATION**:
- When speaking dates aloud to callers, do NOT say the year unless the appointment is more than 6 months away.
- ✅ CORRECT: "Tuesday, March 4th at 10 AM"
- ❌ WRONG: "Tuesday, March 4th, 2026 at 10 AM"
- The year sounds robotic in phone conversation. Callers know what year it is.
```

This is purely a speech behavior issue — the LLM still needs the year in the system prompt for correct date math, and still passes it in ISO format to tools. We only suppress it in spoken output.

---

## 3. Reschedule Without Checking Availability (Overlap)

### Root Cause
The reschedule flow is **entirely prompt-driven**. The system prompt instructs (`utils.ts:1887`):

> "If the new time conflicts with availability, suggest alternatives before rescheduling."

But the `google-calendar-update-event` endpoint (`server.ts:12632`) performs **no server-side availability check**. It accepts any `startDateTime`/`endDateTime` and directly PUTs to Google Calendar. The LLM is supposed to call `check-availability` first, but there's no enforcement.

The prompt section on rescheduling (`utils.ts:1881-1887`) says to use `reschedule_google_calendar_event` but doesn't explicitly mandate calling `check_google_calendar_availability` first.

### Proposed Fix
**Two-layer approach:**

1. **Prompt fix** (low effort): In the RESCHEDULING APPOINTMENTS section (`utils.ts:1881`), add an explicit mandate:
   ```
   **MANDATORY**: Before rescheduling, you MUST call check_google_calendar_availability for the new time slot. 
   Do NOT call update_google_calendar_event_details or reschedule until availability is confirmed.
   If the new time is not available, suggest alternatives — do NOT proceed with the reschedule.
   ```

2. **Backend guard** (medium effort): In the `google-calendar-update-event` endpoint (`server.ts:12769`), when `startDateTime` and `endDateTime` are provided, perform a server-side freeBusy check before updating. If the slot conflicts, return a 409 Conflict:
   ```json
   { "message": "The requested time slot is not available. There is a conflicting appointment." }
   ```
   This ensures overlap is impossible regardless of LLM behavior.

**Recommendation**: Do both. The backend guard is the critical fix — prompt-only is not reliable for data integrity.

---

## 4. Reschedule/Update Must Respect Business Hours

### Root Cause
The `google-calendar-update-event` endpoint (`server.ts:12632`) has **no business hours validation**. It accepts any time and forwards it to Google Calendar. Business hours enforcement is prompt-only (`utils.ts:1826-1833`):

> "You MUST check if the requested appointment time falls within business hours BEFORE calling the check_google_calendar_availability tool."

But this instruction only references availability checking, not the update/reschedule flow. The reschedule section (`utils.ts:1881-1887`) does not mention business hours at all.

### Proposed Fix
**Two-layer approach:**

1. **Prompt fix** (low effort): Add business hours validation to the RESCHEDULING section:
   ```
   **BUSINESS HOURS**: The same business hours rules apply to rescheduling. 
   Do NOT reschedule to a time outside business hours. Check the BUSINESS HOURS section above first.
   ```

2. **Backend guard** (medium effort): In the `google-calendar-update-event` endpoint, when time fields are provided:
   - Load the location's `googlePlaceDetails` business hours
   - Parse the new `startDateTime` into day-of-week and time
   - Compare against business hours
   - Return 400 if outside hours: `"The requested time falls outside business hours."`
   
   This requires the `getLocationWithGoogleCalendarConnection` query to also select `googlePlaceDetails` (currently it only selects `id` and `timezone`).

**Recommendation**: Do both. Backend guard prevents out-of-hours bookings completely.

---

## 5. Appointment Duration Safeguard

### Root Cause
The `google-calendar-create-event` endpoint (`server.ts:11972-11980`) validates `durationMinutes` is `> 0` and `<= 1440` (24 hours), but does NOT compare it against the location's `defaultAppointmentMinutes`. A caller could ask for a 3-hour appointment when the location is configured for 90-minute slots, and the LLM would honor it.

The prompt says "Use this as the duration when creating events **unless the caller specifies a different duration**" (`utils.ts:1820`), which explicitly allows overrides.

### Proposed Fix
**Backend guard** (low effort): In the `google-calendar-create-event` endpoint, after resolving `finalEndDateTime`:

```typescript
// Validate appointment duration against location max
const actualDurationMs = new Date(finalEndDateTime).getTime() - new Date(resolvedStartDateTime).getTime();
const actualDurationMin = actualDurationMs / (60 * 1000);
const maxDuration = getDefaultAppointmentDuration(location);
const maxAllowed = maxDuration * 2; // Allow up to 2x default as reasonable margin

if (actualDurationMin > maxAllowed) {
  return res.status(400).json({
    eventId: '',
    message: `Appointment duration (${actualDurationMin} minutes) exceeds the maximum allowed (${maxAllowed} minutes). The default appointment duration is ${maxDuration} minutes.`
  });
}
```

Also update the prompt to remove the "unless the caller specifies" allowance, or cap it:
```
- Default appointment duration: **${defaultAppointmentMinutes} minutes**. 
  Do NOT book appointments longer than this without explicit approval from the business. 
  If a caller requests a longer block, inform them of the standard duration.
```

**Recommendation**: Backend guard with 2x multiplier (allows reasonable flexibility for double-bookings like complex jobs) plus prompt update.

---

## 6. Cannot Update Event Summary/Description

### Root Cause — **Confirmed bug**
The `google-calendar-update-event` endpoint and the Python tool are both missing `summary` and `description` parameters.

**Contract** (`internal-api.contract.ts:514-523`): `updateEventRequestBodySchema` only has `location`, `startDateTime`, `endDateTime`, `timeZone`, `calendarId`, `roomName`. No `summary` or `description`.

**Python tool** (`google_calendar_update_event.py:21-28`): Only exposes `event_id`, `location`, `start_date_time`, `end_date_time`, `time_zone`, `calendar_id`. No `summary` or `description`.

**Backend** (`server.ts:12644`): Validates only `location`, `startDateTime`, `endDateTime`. Lines 12758-12760 even have a comment:
```typescript
// Future fields (not yet implemented, but structure is ready):
// - summary: Compare existingEvent.summary with newSummary (if provided)
// - description: Compare existingEvent.description with newDescription (if provided)
```

Despite the system prompt telling the agent it can update summary and description (`utils.ts:1889-1914`), the actual tool and endpoint don't support it.

### Proposed Fix
**Three files need changes:**

1. **Contract** (`internal-api.contract.ts`): Add to `updateEventRequestBodySchema`:
   ```typescript
   summary: z.string().optional().describe('New event title/summary'),
   description: z.string().optional().describe('New event description/notes'),
   ```

2. **Backend** (`server.ts`, update-event handler): 
   - Destructure `summary` and `description` from `req.body`
   - Update validation: accept `summary` or `description` as valid update fields
   - Add to `updatedEvent` object: `if (summary) updatedEvent.summary = summary;`
   - Add to `changedFields` tracking
   - Add to success message

3. **Python tool** (`google_calendar_update_event.py`): Add parameters:
   ```python
   summary: Optional[str] = None,
   description: Optional[str] = None,
   ```
   Pass them in the JSON body. Update the docstring and validation.

**Recommendation**: Implement all three. This is a clear feature gap that the prompt already advertises.

---

## 7. Store Intake Answers on Google Calendar Events (Discovery)

### Current State
Currently, intake answers are stored in:
- `CallRecord.intakeAnswers` (JSON field) via `submit_intake_answers`
- `CallerAddress` table (address)
- `Caller` table (name, email, phone)

Google Calendar events already use `extendedProperties.shared` for `callerPhoneNumber`, `callerId`, `callerAddressId`, and `source` (`server.ts:12331-12381`).

### Proposal
Add intake answers to `extendedProperties.shared` on the Google Calendar event. Google Calendar supports up to **32 shared extended properties** per event, each with a key max of 44 characters and value max of 124 characters.

**Implementation**: In the `google-calendar-create-event` endpoint, after the event is created, look up the most recent `submit_intake_answers` call from `callRecord.toolCalls` (similar to the existing `validatedAddress` extraction). Map intake answers to shared properties:

```typescript
// Example: if intake collected "preferred_time" and "how_urgent"
sharedProperties.intake_preferred_time = "Tuesday morning";
sharedProperties.intake_how_urgent = "Not urgent";
```

**Limitations**: Values capped at 124 chars each. Custom questions with long answers would need truncation.

**Recommendation**: Low priority. Useful for businesses that view calendar events directly in Google Calendar and want intake data visible there. Implement after the critical fixes.

---

## 8. Booking Limits (Prevent Calendar Flooding)

### Current State
There is **no limit** on how many appointments a single caller can create. A caller could theoretically book dozens of future appointments.

### Analysis
The `fetchCallerCalendarEvents` function (`server.ts:11458`) already queries events by `callerPhoneNumber` via `extendedProperties.shared`, so we have the data to count active appointments.

### Recommendation: **Implement a per-caller booking limit**

**Proposed limits:**
- **Max 3 active future appointments per caller** (covers most legitimate use cases: initial visit + follow-up + another property)
- **Max 1 appointment per day per caller** (prevents slot-hoarding)

**Implementation**: In the `google-calendar-create-event` endpoint, before creating the event:

```typescript
// Count caller's existing future appointments
const existingEvents = await makeGoogleCalendarRequest(
  connection.connectionId, 'GET',
  `/calendars/${calId}/events`,
  undefined,
  {
    sharedExtendedProperty: `callerPhoneNumber=${normalizedPhone}`,
    timeMin: new Date().toISOString(),
    timeMax: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(),
    singleEvents: 'true',
  }
);
const futureCount = (existingEvents?.items || []).length;

if (futureCount >= 3) {
  return res.status(400).json({
    eventId: '',
    message: `You already have ${futureCount} upcoming appointments. Please cancel or reschedule an existing appointment before booking a new one.`
  });
}

// Check same-day limit
const requestDate = new Date(resolvedStartDateTime).toISOString().split('T')[0];
const sameDayEvents = (existingEvents?.items || []).filter((e: any) => {
  const eventDate = (e.start?.dateTime || '').split('T')[0];
  return eventDate === requestDate;
});
if (sameDayEvents.length >= 1) {
  return res.status(400).json({
    eventId: '',
    message: `You already have an appointment on ${requestDate}. Only one appointment per day is allowed.`
  });
}
```

**Recommendation**: Implement both limits. The 3-appointment cap is essential for preventing abuse. The same-day cap prevents duplicate bookings from confused callers. Both can be configurable per-location in the future.

---

## 9. Business Hour Bleed (Appointment Extends Past Closing)

### Current State
Neither the prompt nor the backend prevents an appointment from extending past closing time. Example: a 90-minute appointment starting at 4:00 PM when closing is 5:00 PM would create a 4:00–5:30 PM event that bleeds 30 minutes past closing.

The `check-availability` endpoint only checks freeBusy conflicts — it does not validate against business hours. Business hours validation is prompt-only and only applies to the **start** time.

### Recommendation: **Prevent bleed**

Appointments should NOT extend past closing. If a 90-minute slot starts at 4:00 PM and closing is 5:00 PM, the agent should say: *"Our last available slot for a 90-minute appointment would be at 3:30 PM so we can finish before closing at 5:00."*

**Implementation — two layers:**

1. **Prompt fix** (low effort): Add to the BUSINESS HOURS VALIDATION section:
   ```
   **APPOINTMENT END TIME**: The entire appointment must fit within business hours. 
   Do NOT book if the appointment end time would extend past closing. 
   For example, if the default duration is 90 minutes and the business closes at 5 PM, 
   the latest start time is 3:30 PM.
   ```

2. **Backend guard** (medium effort): In `google-calendar-create-event`, after computing `finalEndDateTime`:
   - Load business hours from `googlePlaceDetails`
   - Determine closing time for the day of the appointment
   - Compare `finalEndDateTime` against closing time
   - Return 400 if it bleeds: `"The appointment would extend past closing time (5:00 PM). The latest start time for a 90-minute appointment is 3:30 PM."`

**Recommendation**: Do both. The backend guard is critical — this protects the business from after-hours appointments that the prompt fails to catch.

---

## 10. Prevent Updating/Cancelling Past Events

### Current State
Neither the `google-calendar-update-event` nor `google-calendar-cancel-event` endpoints check whether the event is in the past. A caller could ask to reschedule an appointment that already happened, and the backend would process it.

### Proposed Fix
**Backend guard** (low effort): In both endpoints, after fetching the existing event, check:

```typescript
// Prevent modifying past events
const eventStart = existingEvent.start?.dateTime || existingEvent.start?.date;
if (eventStart) {
  const eventDate = new Date(eventStart);
  if (eventDate < new Date()) {
    return res.status(400).json({
      message: 'This appointment has already occurred and cannot be modified. If you need to schedule a new appointment, I can help with that.'
    });
  }
}
```

Apply to:
- `google-calendar-update-event` (`server.ts:12632`) — after line 12700 (existing event fetched)
- `google-calendar-cancel-event` (`server.ts:12487`) — after line 12540 (existing event fetched)

**Recommendation**: Implement in both endpoints. Simple guard, prevents confusion.

---

## 11. Replace `check_availability` with `get_availability` — Slot-Based Availability

### Decision: One Tool, Not Two

The old `check_google_calendar_availability` tool is a **single-slot yes/no checker**. The new `get_availability` tool **replaces it entirely** — it returns all available slots for a day, which answers every availability question:

- "Is 2pm free?" → LLM checks if 2pm is in the slots list. If not, it already has alternatives.
- "What times do you have?" → LLM presents the full list.
- "Do you have mornings available?" → LLM filters the list.

Keeping both tools creates tool-selection confusion for the LLM and risks inconsistent answers (the old tool has the buffer bug, doesn't enforce business hours, etc.). One tool is simpler and strictly more capable.

### How Google Calendar freeBusy Works (Background)

Google Calendar's `/freeBusy` API is a **binary availability checker**. You give it a time window and a list of calendars, and it returns a list of **busy periods** within that window. That's it.

**Request:**
```json
{
  "timeMin": "2026-03-03T09:00:00-08:00",
  "timeMax": "2026-03-03T17:00:00-08:00",
  "timeZone": "America/Los_Angeles",
  "items": [{ "id": "primary" }]
}
```

**Response:**
```json
{
  "calendars": {
    "primary": {
      "busy": [
        { "start": "2026-03-03T10:00:00-08:00", "end": "2026-03-03T11:30:00-08:00" },
        { "start": "2026-03-03T14:00:00-08:00", "end": "2026-03-03T15:30:00-08:00" }
      ]
    }
  }
}
```

The API does NOT return available slots — only busy ones. You must compute available slots yourself by subtracting busy periods from business hours.

### Why the Old Tool Is Being Replaced

The old `google-calendar-check-availability` endpoint (`server.ts:11652`) has multiple problems:

1. **Single-slot yes/no** — LLM must guess-and-check times one by one. "Do you have anything Monday?" requires 3-5+ tool calls.
2. **Buffer time is dead code** — `getLocationWithGoogleCalendarConnection` doesn't select `settings`, so `getBufferMinutes()` always returns 0.
3. **No business hours awareness** — the backend doesn't know if the requested time is within hours.
4. **No alternatives** — if the time is busy, the agent has no idea what IS available.

### Proposed Design: `get-availability` Endpoint

**Replaces**: `POST /internal/tools/google-calendar-check-availability`  
**New endpoint**: `POST /internal/tools/google-calendar-get-availability`

**Request:**
```json
{
  "locationId": "clxyz...",
  "date": "2026-03-03",
  "timeZone": "America/Los_Angeles",
  "calendarId": "primary"
}
```

Note: No `startDateTime`/`endDateTime` or `durationMinutes` needed — the backend knows the appointment duration and business hours from location settings.

**Backend logic:**

```
1. Load location with settings and googlePlaceDetails via getLocationWithGoogleCalendarConnection
2. Read appointmentDuration from location settings:
   - location.settings.appointmentSettings.defaultMinutes (set by PATCH /me/locations/:locationId)
   - Default: 60 minutes if not set
   This is the SAME getDefaultAppointmentDuration() used by create-event and get-next-available.
3. Read bufferMinutes from location settings (settings.appointmentSettings.bufferMinutes, default 0)
4. Compute effectiveSlotMinutes = appointmentDuration + bufferMinutes
   (e.g., 90-min appointment + 15-min buffer = 105-min minimum free window needed)
5. Parse business hours from location.googlePlaceDetails for the requested day-of-week
   - If the day is closed → return "The business is closed on [day]."
6. Call Google freeBusy for the full business hours window (e.g., 9am-5pm)
7. Get back busy periods: [{10:00-11:30}, {14:00-15:30}]
8. Compute free windows by subtracting busy periods from business hours:
   - 9:00–10:00 (60 min free)
   - 11:30–14:00 (150 min free)
   - 15:30–17:00 (90 min free)
9. Apply effectiveSlotMinutes to determine bookable start times within each window:
   - effectiveSlotMinutes = 105 min (90-min appointment + 15-min buffer)
   - Window 9:00–10:00 (60 min): too short for 90-min appointment → no slots
   - Window 11:30–14:00 (150 min): 
     - Slot 1: 11:30–13:00 ✅ (buffer after = 13:15, next slot starts 13:15)
     - Slot 2: would need 13:15–14:45 but window ends at 14:00 → no
     - → 1 slot: 11:30 AM
   - Window 15:30–17:00 (90 min):
     - Slot 1: 15:30–17:00 ✅ (exactly fits, appointment ends at closing)
     - → 1 slot: 3:30 PM
   Note: the LAST slot of the day does NOT need buffer after it (buffer is spacing
   between consecutive appointments, not a padding after closing).
10. Return human-readable available time ranges with duration context
```

**Key detail**: The slot size is driven entirely by the **location's configured appointmentDuration**. The caller and LLM never specify duration — the backend reads it from `getDefaultAppointmentDuration(location)`. This is the same function that `google-calendar-create-event` uses when no explicit duration is passed, ensuring consistency across all scheduling tools.

**Response:**
```json
{
  "date": "2026-03-03",
  "dayOfWeek": "Monday",
  "businessHours": "9:00 AM - 5:00 PM",
  "appointmentDuration": 90,
  "bufferMinutes": 15,
  "availableSlots": [
    { "start": "11:30 AM", "end": "1:00 PM" },
    { "start": "3:30 PM", "end": "5:00 PM" }
  ],
  "message": "Available appointment times on Monday, March 3rd: 11:30 AM and 3:30 PM (90-minute appointments). The business is open 9 AM to 5 PM, but other times are booked."
}
```

The `message` field is what the LLM sees — a natural-language summary the agent can relay directly.

### Python Tool (Replaces `google_calendar_check_availability`)

```python
@function_tool()
async def google_calendar_check_availability(
    ctx: RunContext,
    date: str,  # YYYY-MM-DD format
    time_zone: Optional[str] = None,
    calendar_id: Optional[str] = None,
) -> str:
    """
    Check calendar availability for a specific day. Returns all bookable appointment 
    slots based on business hours, existing appointments, appointment duration, and 
    buffer time.

    Use this for ANY availability question:
    - "Do you have anything on Monday?" → returns all open slots
    - "Is 2pm available?" → returns all slots; you can check if 2pm is among them
    - "What mornings are open this week?" → call once per day, filter morning slots

    Args:
        date: The date to check availability for, in YYYY-MM-DD format (e.g., 2026-03-03)
        time_zone: Timezone (e.g., America/Los_Angeles). Defaults to business timezone.
        calendar_id: Calendar ID. Defaults to primary calendar.
    """
```

**Note**: We keep the function name `google_calendar_check_availability` to minimize prompt changes and avoid breaking the existing tool registration pattern. The signature changes from `(start_date_time, end_date_time)` to `(date)` and the backend endpoint changes, but the tool name stays the same.

### Prompt Updates

Replace the entire AVAILABILITY CHECKING section in `utils.ts` with:

```
**CHECKING AVAILABILITY**:
- For ANY availability question, use the **check_google_calendar_availability** tool 
  with the date (YYYY-MM-DD format). It returns all bookable appointment slots for 
  that day, factoring in business hours, existing appointments, and buffer time.
- "Do you have anything on Monday?" → call with Monday's date, present slots naturally.
- "Is 2pm available?" → call with that date, check if 2pm is in the returned slots.
  If not, you already have alternatives to offer.
- "What mornings do you have?" → call with the date, filter for morning slots.
- Present results naturally: "On Monday, we have openings at 11:30 AM and 3:30 PM. 
  Which works better for you?"
- If no slots are available: "Unfortunately, we're fully booked on Monday. Would you 
  like me to check another day, or find the next available opening?"
```

### Migration: What Gets Removed

- **Delete**: `POST /internal/tools/google-calendar-check-availability` endpoint (server.ts)
- **Delete**: `livekit-python/tools/google_calendar_check_availability.py` (old tool file)
- **Create**: `POST /internal/tools/google-calendar-get-availability` endpoint (new)
- **Create**: `livekit-python/tools/google_calendar_check_availability.py` (rewritten with new signature)
- **Update**: Contract in `internal-api.contract.ts`
- **Update**: Tool registration in `server.ts` and `tools/__init__.py`
- **Update**: Test mock in `conftest.py` and test prompt in `prompts.py`

---

## 12. "Next Available" Appointment — Find First Open Slot

### Current State

The "next available" flow is **entirely prompt-driven** (`utils.ts:1841`):

> "If the caller asks for 'next available', 'first available', 'earliest available', or similar, check the calendar for the next available time slot that is ALSO within business hours."

The LLM is expected to guess dates and call the availability tool repeatedly. In practice, this means **3-5+ tool calls** for a simple "when's the next opening?" and the LLM often gets confused.

### Proposed Design: `get-next-available` Endpoint

A new endpoint that scans forward from "now" (or a given date) to find the first bookable slot.

**New internal endpoint**: `POST /internal/tools/google-calendar-get-next-available`

**Request:**
```json
{
  "locationId": "clxyz...",
  "startingFrom": "2026-03-01",  // Optional, defaults to today
  "timeZone": "America/Los_Angeles",
  "calendarId": "primary"
}
```

**Backend logic:**

```
1. Load location with settings and googlePlaceDetails via getLocationWithGoogleCalendarConnection
2. Read appointmentDuration from location settings:
   - location.settings.appointmentSettings.defaultMinutes (set by PATCH /me/locations/:locationId)
   - Default: 60 minutes if not set
   This is the SAME value used by getDefaultAppointmentDuration() in the create-event endpoint.
3. Read bufferMinutes from location settings (settings.appointmentSettings.bufferMinutes, default 0)
4. Compute effectiveSlotMinutes = appointmentDuration + bufferMinutes
   (e.g., 90-min appointment + 15-min buffer = 105-min minimum free window needed)
5. Parse business hours from location.googlePlaceDetails for each day of week
6. Determine startingFrom date (request param or today in location timezone)
7. Build freeBusy query spanning startingFrom through startingFrom + 14 days
   - timeMin = first business-hours open time from startingFrom
   - timeMax = last business-hours close time on day 14
8. Make ONE Google freeBusy API call for the entire 14-day window
9. Get back all busy periods across the 14 days
10. Walk through each day in order:
    a. Look up business hours for this day-of-week
    b. If closed → skip
    c. If today → adjust window start to max(now, opening time)
    d. Subtract busy periods from this day's business hours → free windows
    e. For each free window, check: does it fit effectiveSlotMinutes?
       - The appointment must START early enough that startTime + appointmentDuration ≤ closing
       - The full slot (appointment + buffer) must fit within the free window
    f. If yes → the earliest start time in this window is the answer
    g. If no windows fit on this day → continue to next day
11. If no slot found in 14 days → return "No availability in the next 2 weeks"
```

**Key detail**: The slot size is driven entirely by the **location's configured appointmentDuration** — the caller does NOT specify a duration. This ensures consistency: if a business configures 90-minute appointments, every "next available" search finds a 90-minute slot. The LLM never needs to guess or infer the duration.

**Optimization**: The single freeBusy call for 14 days is critical. Google's freeBusy API accepts arbitrary `timeMin`/`timeMax` ranges — there is no per-day limit. This means **1 API call** covers the entire scan window, returning all busy periods at once. The day-by-day walk is pure local computation (no additional API calls).

**Response:**
```json
{
  "found": true,
  "date": "2026-03-03",
  "dayOfWeek": "Monday",
  "startTime": "9:00 AM",
  "endTime": "10:30 AM",
  "appointmentDuration": 90,
  "bufferMinutes": 15,
  "message": "The next available appointment is Monday, March 3rd at 9:00 AM (90-minute appointment). Would you like me to book that time?"
}
```

### New Python Tool

```python
@function_tool()
async def google_calendar_get_next_available(
    ctx: RunContext,
    starting_from: Optional[str] = None,  # YYYY-MM-DD, defaults to today
    time_zone: Optional[str] = None,
    calendar_id: Optional[str] = None,
) -> str:
    """
    Find the next available appointment slot. Use this when the caller asks for
    "next available", "first available", "earliest opening", "soonest I can come in",
    or similar. Scans up to 14 days forward to find the first bookable slot based on
    business hours, existing appointments, appointment duration, and buffer time.
    
    IMPORTANT: After finding the next available slot, you MUST speak the date and time
    clearly to the caller and WAIT for their explicit confirmation before creating 
    the appointment. Do NOT auto-book.
    """
```

### Prompt Updates

Replace the existing "next available" paragraph in `utils.ts` with:

```
**NEXT/FIRST AVAILABLE APPOINTMENT**: 
- When the caller asks for "next available", "first available", "earliest opening", 
  or similar, use the **get_next_available** tool. It efficiently scans up to 14 days 
  forward to find the first bookable slot.
- Do NOT manually check day-by-day — use get_next_available for a single efficient lookup.
- Once you have the result, speak the date and time clearly: "The next available 
  appointment is [day], [date] at [time]."
- WAIT for the caller to explicitly confirm before creating the event. Do NOT auto-book.
```

### The Two Scheduling Query Tools

After this work, the GCal integration has exactly **two** availability tools with **zero overlap**:

| Caller says | Tool | What it does |
|-------------|------|-------------|
| Any question about a specific day ("Is 2pm free?", "What's open Monday?", "Do you have mornings?") | `check_availability(date)` | Returns all bookable slots for that day |
| "Next available" / "earliest" / "soonest" / "when can I come in?" | `get_next_available(starting_from?)` | Scans 14 days forward, returns first bookable slot |

No ambiguity, no tool-selection confusion. One date-based tool, one scan-forward tool.

---

## 11b. Prerequisite: Expand `getLocationWithGoogleCalendarConnection` Query

### Root Cause

`getLocationWithGoogleCalendarConnection` (`server.ts:11594-11650`) only selects `{ id, timezone }` from the location. It does **not** select `settings` or `googlePlaceDetails`.

This means any GCal endpoint using this cached query cannot access appointment duration, buffer time, or business hours. The old check-availability endpoint had dead buffer code because of this.

### Fix

Add `settings: true` and `googlePlaceDetails: true` to the query:

```typescript
const location = await prisma.location.findUnique({
  where: { id: locationId },
  select: {
    id: true,
    timezone: true,
    settings: true,           // <-- ADD THIS
    googlePlaceDetails: true, // <-- ADD THIS (needed for business hours)
    organization: { ... }
  }
});
```

Update the `LocationWithConnection` type and return value to include these fields.

**This is prerequisite for both #11 and #12** — both new tools need `settings` (for duration/buffer) and `googlePlaceDetails` (for business hours) to compute slots.

---

## Summary: Priority & Effort Matrix

| # | Issue | Severity | Effort | Fix Type |
|---|-------|----------|--------|----------|
| 11 | Replace check_availability with slot-based get_availability | **P0** | High | Replace endpoint + tool + prompt |
| 12 | Next available appointment | **P0** | High | New endpoint + tool + prompt |
| 11b | Expand location query (prerequisite) | **P0** | Low | Query fix (1 line) |
| 6 | Can't update summary/description | **P0** | Medium | Bug fix (3 files) |
| 3 | Reschedule without availability check | **P0** | Medium | Prompt + backend guard |
| 1 | Email not enforced | **P1** | Low-Med | Prompt + backend guard |
| 10 | Can modify past events | **P1** | Low | Backend guard |
| 5 | No duration cap | **P1** | Low | Backend guard + prompt |
| 4 | Reschedule ignores business hours | **P1** | Medium | Prompt + backend guard |
| 9 | Appointment bleeds past closing | **P1** | Medium | Prompt + backend guard |
| 2 | Agent says "2026" | **P2** | Low | Prompt only |
| 8 | No booking limits | **P2** | Medium | Backend guard |
| 7 | Store intake on GCal events | **P3** | Low | Backend enhancement |

### Suggested Implementation Order
1. **#11b** — Expand location query (prerequisite for everything)
2. **#11 + #12** — Replace availability tool + add next-available (core scheduling UX — do together since they share infrastructure: business hours parsing, slot computation, freeBusy batching)
3. **#6** — Summary/description update (clear bug, already advertised in prompt)
4. **#10** — Past event guard (trivial, prevents confusion)
5. **#3** — Reschedule availability check (data integrity)
6. **#1** — Email enforcement (backend guard)
7. **#5** — Duration cap
8. **#4 + #9** — Business hours enforcement for reschedule + bleed prevention (related, do together)
9. **#2** — Year pronunciation
10. **#8** — Booking limits
11. **#7** — Intake data on events
