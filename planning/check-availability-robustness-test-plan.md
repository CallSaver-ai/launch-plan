# checkAvailability Redesign + Robustness Test Plan

> Updated: Feb 20, 2026

## Problem Statement

The `checkAvailability` tool worked correctly on one run (returned proper time slots respecting service duration from Jobber services and the fallback default appointment duration), but on a second run it returned **no availability for Monday when there was plenty of open time**.

## New Design Requirements

The tool should:
1. **Operate on a single day** — "Can you come Tuesday?" → check just Tuesday
2. **Always return the next available slot** — even if it's not on the requested day
3. **Report all bookable windows** for the requested day — e.g., "10 AM - 1:15 PM, 3 PM - 5 PM"
4. **Respect service duration** — use Jobber service `durationMinutes` if available, fallback to Location `defaultAppointmentMinutes`
5. **Respect buffer time** — travel time between appointments from Location settings

## Root Cause Hypotheses (for intermittent failure)

| # | Hypothesis | Likelihood |
|---|-----------|------------|
| **H1** | Jobber eventual consistency — stale data from previous mutations | High |
| **H2** | Accumulated assessments from previous test runs filling the calendar | **Very High** |
| **H3** | Date boundary bug — `new Date("...T00:00:00")` without Z suffix parsed as UTC on server | Medium |
| H4 | String comparison in day loop | Low |
| H5 | Service duration filtering out valid slots | Low |

---

## Code Changes Required

### 1. API Layer: `src/routes/field-service-tools.ts` — `get-availability` endpoint

**Current**: Takes `startDate` + `endDate` (date range), returns up to 10 `TimeSlot[]`.

**New**: Accept `date` (single day, e.g., `"2026-02-24"` or `"Monday"`). The endpoint will:
- Query the **requested day** for all windows
- Also scan forward from today to find the **next available** slot (soonest bookable time)
- Return both in a structured response

```typescript
// New request body:
{
  locationId, callerPhoneNumber,
  date: "2026-02-24",          // single day (required)
  serviceType?: string,         // for duration lookup
  duration?: number,            // explicit override in minutes
}

// New response:
{
  requestedDay: {
    date: "Monday, February 24",
    windows: [
      { startTime: "...", endTime: "..." },  // 10:00 AM - 1:15 PM
      { startTime: "...", endTime: "..." },  // 3:00 PM - 5:00 PM
    ],
    windowCount: 2,
  },
  nextAvailable: {
    date: "Friday, February 21",
    startTime: "...",
    endTime: "...",
  },
  duration: 60,  // the duration used for filtering
  message: "For Monday February 24, we have availability from 10:00 AM to 1:15 PM and from 3:00 PM to 5:00 PM. Our next available appointment is this Friday at 8:00 AM. What time works best for you?"
}
```

### 2. Adapter Layer: `JobberAdapter.ts` — `checkAvailability`

The existing gap-finding logic is fine. We just need to call it twice:
- Once for the requested day
- Once scanning forward from today (day by day, up to 14 days) to find the first day with an available slot

Alternatively, keep the adapter method as-is (it already handles single-day ranges) and have the route handler make two calls.

### 3. Python Tool: `livekit-python/tools/fs_scheduling.py`

**Current**: `fs_check_availability(start_date, end_date, service_type?, duration?)`

**New**: `fs_check_availability(date, service_type?, duration?)`

```python
@function_tool()
async def fs_check_availability(
    ctx: RunContext,
    date: str,
    service_type: Optional[str] = None,
    duration: Optional[int] = None,
) -> str:
    """
    Check available appointment windows for a specific day.
    Also returns the next available appointment if the requested day is not today.
    
    Args:
        date: The date to check in ISO format (e.g., "2026-02-24") or relative ("Monday", "tomorrow").
        service_type: Type of service for duration estimation (optional).
        duration: Desired appointment duration in minutes (optional, uses service default).
    """
```

### 4. System Prompt: `server.ts` — fsInstructions Step 10b

**Current**: "Call fs_check_availability for the next 7 days"

**New**: "Call fs_check_availability with the date the caller requested (e.g., 'Tuesday' → next Tuesday's ISO date). The tool will return all available windows for that day AND the next available appointment. Present both to the caller."

---

## Integration Test Architecture: `testing/seed-and-test-jobber.sh`

This is the PRIMARY test file. It will be rewritten with a clean structure:

### Phase 0: Preflight
- Verify API is reachable
- Verify jq is installed

### Phase 1: Seed (clean start — assumes Jobber data wiped)

**Step 1**: Get service catalog → extract service IDs + durations
**Step 2**: Create 4 test clients with distinct phone numbers
**Step 3**: Create properties for each client
**Step 4**: Create service requests (auto-creates assessments)
**Step 5**: Schedule assessments on known days:

```
Calendar layout:
  BD1 (next Mon):  9-10 AM (Maria/Leak Repair), 2-3 PM (James/Drain Cleaning)
  BD2 (next Tue):  8-10 AM (Robert/Toilet Install — 2hr block)
  BD3 (next Wed):  10-11 AM (Sarah/Water Heater)
  BD4 (next Thu):  OPEN (no scheduled items)
  BD5 (next Fri):  OPEN
```

### Phase 2: Test get-services

| # | Test | Assert |
|---|------|--------|
| S1 | Get services | Returns ≥1 service |
| S2 | Services have IDs | Each service has `.id` field |
| S3 | Services have duration | At least some services have `.duration` field |
| S4 | Services have price | At least some services have `.price` field |

### Phase 3: Test get-availability — Single Day, Empty Calendar

| # | Test | Input | Assert |
|---|------|-------|--------|
| A1 | Open day (BD4/Thu) | `date: "2026-02-27"` | ≥1 window, window spans ~8-9 hours |
| A2 | Open day, 60-min duration | Same + `duration: 60` | Same as A1 |
| A3 | Open day, 30-min duration | Same + `duration: 30` | Same window count (open day = 1 big window regardless) |
| A4 | Open day, 120-min duration | Same + `duration: 120` | Still 1 window (9hr > 2hr) |

### Phase 4: Test get-availability — Single Day, With Appointments

| # | Test | Input | Assert |
|---|------|-------|--------|
| B1 | BD1 (Mon: Maria 9-10, James 2-3) | `date: BD1` | 3 windows: morning, midday, afternoon |
| B2 | No window overlaps Maria 9-10 | Check all windows | No window contains 9:30 AM |
| B3 | No window overlaps James 2-3 | Check all windows | No window contains 2:30 PM |
| B4 | Morning window exists | Check windows | A window ends ≤ 9:00 AM |
| B5 | Midday window exists | Check windows | A window starts ≥ 10:00 AM and ends ≤ 2:00 PM |
| B6 | Afternoon window exists | Check windows | A window starts ≥ 3:00 PM |
| B7 | BD2 (Tue: Robert 8-10 2hr) | `date: BD2` | 1 window starting after 10 AM |
| B8 | BD3 (Wed: Sarah 10-11) | `date: BD3` | 2 windows: 8-10, 11-17 |

### Phase 5: Test get-availability — Duration Filtering

| # | Test | Input | Assert |
|---|------|-------|--------|
| D1 | BD1, duration=60 | 60 min | Morning window (8-9 = 60 min) included |
| D2 | BD1, duration=90 | 90 min | Morning window (8-9 = 60 min) EXCLUDED (too small) |
| D3 | BD1, duration=30 | 30 min | Morning window included |
| D4 | BD1, duration=240 (4hr) | 240 min | Only midday window (10-14 = 4hr) qualifies |
| D5 | Service type with known duration | `serviceType: "Leak Repair"` | Uses Leak Repair's duration from Jobber |

### Phase 6: Test get-availability — Next Available

| # | Test | Input | Assert |
|---|------|-------|--------|
| N1 | Request BD4 (open day) | `date: BD4` | nextAvailable ≤ BD4 (could be today or BD4 itself) |
| N2 | Request far future open day | `date: +30 days` | nextAvailable is much sooner |
| N3 | nextAvailable has valid times | Any request | nextAvailable.startTime and endTime are valid ISO |
| N4 | nextAvailable respects duration | `duration: 120` | nextAvailable slot is ≥ 120 min |

### Phase 7: Test get-availability — Edge Cases

| # | Test | Input | Assert |
|---|------|-------|--------|
| E1 | Sunday (closed) | Next Sunday | 0 windows, message mentions closed |
| E2 | Past date | Yesterday | Graceful response (empty or error) |
| E3 | Missing date param | No date | HTTP 400 |
| E4 | Invalid date (relative string) | `date: "Monday"` | HTTP 400 (LLM should always send YYYY-MM-DD, reject anything else) |
| E5 | Today | `date: today's YYYY-MM-DD` | Returns windows for remaining hours today |

**Note on date formats**: We only test `YYYY-MM-DD` (the format we instruct the LLM to use via the tool docstring) plus one invalid input test. The LLM is the only caller, so we control the format. No need to test ISO-with-timezone, date-only-midnight-UTC, etc.

### Phase 8: Test get-availability — Reproducibility

| # | Test | Description | Assert |
|---|------|-------------|--------|
| R1 | Same query 5x | Call BD1 availability 5 times, 1s apart | All 5 return identical window count |
| R2 | Same query 5x (BD4 open) | Call BD4 availability 5 times | All 5 return identical results |

### Phase 9: Test Scheduling Flow (E2E)

| # | Test | Description | Assert |
|---|------|-------------|--------|
| F1 | Check availability → book | Get BD4 windows → reschedule-assessment to first window | Assessment scheduled |
| F2 | Re-check after booking | Query BD4 again | Booked slot no longer in windows |
| F3 | Reschedule assessment | Move to different time on BD4 | Old slot reopens, new slot blocked |
| F4 | Cancel assessment | Cancel the assessment | Slot reopens |

### Phase 10: Test Customer/Property/Request CRUD

| # | Test | Description |
|---|------|-------------|
| C1 | get-customer-by-phone (existing) | Returns customer |
| C2 | get-customer-by-phone (not found) | Returns null |
| C3 | list-properties | Returns properties |
| C4 | get-requests | Returns requests |
| C5 | get-request (single) | Returns request with assessment metadata |
| C6 | get-client-schedule | Returns scheduled items |
| C7 | update-customer | Updates email |
| C8 | submit-lead | Creates customer + property + request in one call |

---

## Implementation Order

| Step | What | Effort | File(s) |
|------|------|--------|--------|
| **1** | Wipe Jobber sandbox data (user does manually) | - | Jobber UI |
| **2** | Update `get-availability` endpoint to accept `date` param, add `nextAvailable` logic | ~1.5 hr | `field-service-tools.ts` |
| **3** | Update Python tool to use `date` instead of `start_date/end_date` | ~15 min | `fs_scheduling.py` |
| **4** | Update system prompt Step 10b | ~10 min | `server.ts` |
| **5** | Rewrite `seed-and-test-jobber.sh` with all test phases above | ~3 hr | `testing/seed-and-test-jobber.sh` |
| **6** | Run tests, fix any failures | ~1 hr | Various |
| **7** | Voice agent testing (only after API tests pass) | ~1 hr | Manual |

**Total estimated effort**: ~7 hours

---

## Key Design Decisions

### Single-day `date` param vs `startDate/endDate` range

Keep backward compatibility: the endpoint accepts EITHER `date` (new, preferred) OR `startDate/endDate` (legacy). If `date` is provided, it takes precedence and the endpoint constructs the range internally as `date 00:00:00` to `date 23:59:59` in the business timezone.

### Next Available scanning

The endpoint scans forward from **today** (or tomorrow if today is almost over) up to **14 days** to find the first day with a gap ≥ duration. Returns the earliest window start time. This is a separate adapter call per day — but we can optimize by querying a 14-day range from Jobber once and then iterating locally.

### Date parsing fix (H3)

When the endpoint receives `date: "2026-02-24"`, it should NOT do `new Date("2026-02-24")` (which is midnight UTC). Instead, it should construct the range in the business timezone:

```typescript
// Correct: construct date range in business timezone
const tz = locSettings.timezone || 'America/Los_Angeles';
const dayStart = `${date}T00:00:00`;  // local time string
const dayEnd = `${date}T23:59:59`;    // local time string
// Pass as strings to adapter, let adapter handle TZ conversion
```

Or better: pass the date string directly and let the adapter's `getLocalDateStr` / `localTimeToUTC` handle it, since those are already timezone-aware.

### Cleanup strategy for tests

Since the user will wipe Jobber data before running, we don't need a cleanup phase in the script. The script assumes a clean Jobber sandbox. If re-running, user wipes again first.

### Timezone testing strategy

The test location's timezone (`America/Los_Angeles`) comes from `googlePlaceDetails` synced during provisioning — there's no API endpoint to change it. So timezone testing belongs in **TypeScript unit tests**, not the bash integration test.

The unit tests mock `this.client.query` (Jobber GraphQL) and vary `context.timezone` directly:

| # | Timezone | Business Hours 8-5 local | Expected window (UTC) |
|---|----------|--------------------------|----------------------|
| TZ1 | `America/Los_Angeles` (PST, UTC-8) | 8 AM - 5 PM | 16:00Z - 01:00Z+1 |
| TZ2 | `America/New_York` (EST, UTC-5) | 8 AM - 5 PM | 13:00Z - 22:00Z |
| TZ3 | `America/Chicago` (CST, UTC-6) | 8 AM - 5 PM | 14:00Z - 23:00Z |
| TZ4 | `America/Denver` (MST, UTC-7) | 8 AM - 5 PM | 15:00Z - 00:00Z+1 |
| TZ5 | `America/Anchorage` (AKST, UTC-9) | 8 AM - 5 PM | 17:00Z - 02:00Z+1 |
| TZ6 | `Pacific/Honolulu` (HST, UTC-10) | 8 AM - 5 PM | 18:00Z - 03:00Z+1 |
| TZ7 | DST transition (PDT, UTC-7) | March 9 2026 | 15:00Z - 00:00Z+1 |
| TZ8 | Scheduled item at 10 AM Eastern | `America/New_York` | Item at 15:00Z blocks 15:00-16:00Z |

These tests verify that `localTimeToUTC`, `getLocalDateStr`, and `getLocalDayOfWeek` produce correct results across all US timezones. The integration test (bash) only tests the real location timezone (Pacific) end-to-end.

**File**: `src/adapters/field-service/platforms/jobber/__tests__/checkAvailability.test.ts`

This is a future implementation item — the bash seed-and-test script is the immediate priority.
