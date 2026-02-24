# Jobber Assessment & Scheduling Plan

**Date**: Feb 19, 2026  
**Updated**: Feb 20, 2026  
**Goal**: Enable the voice agent to auto-schedule assessments, reschedule/cancel any scheduled item, report status, and give callers a full view of their schedule.

---

## Implementation Status (Feb 20, 2026)

All planned changes have been implemented. Summary:

| Change | Status | Notes |
|--------|--------|-------|
| **1. `rescheduleAssessment`** | ✅ Done | Adapter + interface + base + HCP stub + endpoint + Python tool |
| **2. `getClientSchedule`** | ✅ Done | Adapter + endpoint + Python tool. Uses `client.scheduledItems` query |
| **3. `autoScheduleAssessment` branching** | ✅ Done | Conditional prompt in server.ts; utils.ts updated with enhanced returning caller workflow |
| **4. Timezone handling** | ✅ Done | `CallerContext` now has `timezone`, `defaultAppointmentMinutes`, `bufferMinutes`. `buildContext` reads from Location model via `getLocationSettings()`. All 6 adapter methods fixed. |
| **5. `occursWithin` format** | ⏳ Needs testing | Still uses `{ startAt, endAt }` — needs verification against Jobber GraphQL explorer |
| **6. Business hours from config** | ⏳ Deferred | Still hardcoded 8-17. TODO comments added. |
| **7. `assessmentId` in response** | ✅ Done | `create-service-request` endpoint now returns `assessmentId` + `request_id` in message |

### Files Modified
- `src/types/field-service.ts` — Added `timezone`, `defaultAppointmentMinutes`, `bufferMinutes` to `CallerContext`
- `src/adapters/field-service/FieldServiceAdapter.ts` — Added `rescheduleAssessment`, `getClientSchedule` to interface + ADAPTER_METHOD_NAMES (34 → 36)
- `src/adapters/field-service/BaseFieldServiceAdapter.ts` — Added abstract methods
- `src/adapters/field-service/platforms/jobber/JobberAdapter.ts` — Implemented `rescheduleAssessment` (assessmentEdit), `getClientSchedule` (client.scheduledItems). Fixed timezone in 6 methods.
- `src/adapters/field-service/platforms/housecallpro/HousecallProAdapter.ts` — Added stubs
- `src/routes/field-service-tools.ts` — Added `getLocationSettings()`, updated `buildContext()`, added `reschedule-assessment` + `get-client-schedule` endpoints, updated `create-service-request` response
- `livekit-python/tools/fs_assessment.py` — Added `fs_reschedule_assessment` tool
- `livekit-python/tools/fs_scheduling.py` — Added `fs_get_client_schedule` tool
- `livekit-python/tools/__init__.py` — Registered 2 new tools
- `src/server.ts` — Added tools to Jobber tool list, re-enabled `autoScheduleAssessment` prompt branching, enhanced returning caller workflow
- `src/utils.ts` — Enhanced returning caller workflow + scheduling sections

### Remaining Items
1. **Test `occursWithin` filter** — Verify against Jobber GraphQL explorer whether it expects `{ startAt, endAt }` or `{ startDate, endDate }`
2. **Test `client.scheduledItems`** — Verify the query works with the current Jobber API version
3. **Business hours config** — Move 8-17 hardcoded hours to Location.settings (Phase 2)
4. **Restart API + Python agent** — Deploy and test end-to-end

---

## Current State Audit

### What Already Exists

| Layer | Component | Status | Notes |
|-------|-----------|--------|-------|
| **Adapter** | `checkAvailability()` | ✅ Built | Queries `scheduledItems`, finds gaps in 8-17 business hours |
| **Adapter** | `createAssessment()` | ✅ Built | Scheduled or unscheduled, uses `assessmentCreate` mutation |
| **Adapter** | `cancelAssessment()` | ✅ Built | Uses `assessmentDelete` mutation |
| **Adapter** | `createAppointment()` | ✅ Built | Creates visits via `visitCreate` (auto-creates job if needed) |
| **Adapter** | `getAppointments()` | ✅ Built | Gets visits via `client.jobs.visits` — **only returns visits, not assessments** |
| **Adapter** | `rescheduleAppointment()` | ✅ Built | Uses `visitEditSchedule` with delete+recreate fallback |
| **Adapter** | `cancelAppointment()` | ✅ Built | Uses `visitDelete` |
| **Endpoint** | `POST /get-availability` | ✅ Built | Formats top 3 slots for voice |
| **Endpoint** | `POST /create-assessment` | ✅ Built | Scheduled or unscheduled |
| **Endpoint** | `POST /cancel-assessment` | ✅ Built | |
| **Endpoint** | `POST /create-appointment` | ✅ Built | |
| **Endpoint** | `POST /get-appointments` | ✅ Built | Returns visits only |
| **Endpoint** | `POST /reschedule-appointment` | ✅ Built | |
| **Endpoint** | `POST /cancel-appointment` | ✅ Built | |
| **Python** | `fs_check_availability` | ✅ Built | |
| **Python** | `fs_create_assessment` | ✅ Built | Supports scheduled + unscheduled modes |
| **Python** | `fs_cancel_assessment` | ✅ Built | |
| **Python** | `fs_create_appointment` | ✅ Built | |
| **Python** | `fs_get_appointments` | ✅ Built | |
| **Python** | `fs_reschedule_appointment` | ✅ Built | |
| **Python** | `fs_cancel_appointment` | ✅ Built | |
| **Prompt** | New caller workflow | ✅ Built | Currently FORBIDS scheduling — assessment always inlined as unscheduled |
| **Prompt** | Returning caller workflow | ⚠️ Partial | Lists tools but no detailed guidance on assessment lifecycle |
| **Config** | `autoScheduleAssessment` toggle | ✅ Built | Read from `agent.config` but not wired into prompt branching anymore |

### What's Missing

| # | Capability | Gap |
|---|-----------|-----|
| 1 | **Reschedule an assessment** | No `rescheduleAssessment` adapter method, endpoint, or Python tool |
| 2 | **Schedule a previously-unscheduled assessment** | Same gap — `assessmentEdit` mutation handles both |
| 3 | **Get ALL scheduled items for a client** | `getAppointments` only returns visits. Need assessments, visits, events, tasks in one view |
| 4 | **Auto-schedule assessment for new callers** | `autoScheduleAssessment` toggle exists but prompt branching was removed; need to re-add |
| 5 | **Timezone awareness** | Adapter uses `Intl.DateTimeFormat().resolvedOptions().timeZone` (server tz), not business tz |
| 6 | **`occursWithin` filter format** | Code passes `{ startAt, endAt }` — Jobber `DateRange` might expect `{ startDate, endDate }`. Needs verification. |
| 7 | **Business hours config** | Hardcoded 8 AM - 5 PM. Should come from business config or Location model. |
| 8 | **Assessment status in returning caller flow** | `getRequest` already includes assessment data, but prompt doesn't tell agent how to interpret/report it |

---

## Plan

### Change 1: `rescheduleAssessment` (adapter + endpoint + Python tool)

Jobber's `assessmentEdit` mutation handles both scheduling an unscheduled assessment and rescheduling an already-scheduled one. Same mutation, same input.

#### 1a. Adapter: `rescheduleAssessment()`

File: `src/adapters/field-service/platforms/jobber/JobberAdapter.ts`

```typescript
async rescheduleAssessment(
  context: CallerContext,
  assessmentId: string,
  newTime: { startTime: Date; endTime?: Date; instructions?: string }
): Promise<any> {
  // assessmentEdit mutation with updated schedule
}
```

**GraphQL mutation:**
```graphql
mutation EditAssessment($assessmentId: EncodedId!, $input: AssessmentEditInput!) {
  assessmentEdit(assessmentId: $assessmentId, input: $input) {
    assessment {
      id title instructions startAt endAt allDay duration isComplete clientConfirmed
      assignedUsers(first: 10) { nodes { id name { full } } }
      client { id }
      property { id }
      request { id title }
    }
    userErrors { message path }
  }
}
```

**Input shape:**
```typescript
const input: any = {};
if (newTime.instructions) input.instructions = newTime.instructions;
if (newTime.startTime) {
  const tz = this.getBusinessTimezone(context); // NEW helper
  input.schedule = {
    startAt: { date: formatDate(startTime), time: formatTime(startTime), timezone: tz },
    endAt:   { date: formatDate(endTime),   time: formatTime(endTime),   timezone: tz },
  };
}
```

This method covers both use cases:
- **Schedule an unscheduled assessment**: pass `assessmentId` + `newTime` with a start time
- **Reschedule a scheduled assessment**: same — just pass the new time

#### 1b. Interface update

File: `src/adapters/field-service/FieldServiceAdapter.ts`

Add to the Assessment section:
```typescript
/** Reschedule or schedule an assessment (uses assessmentEdit mutation) */
rescheduleAssessment(
  context: CallerContext,
  assessmentId: string,
  newTime: { startTime: Date; endTime?: Date; instructions?: string }
): Promise<Assessment>;
```

Also add `'rescheduleAssessment'` to `ADAPTER_METHOD_NAMES`.

Update `BaseFieldServiceAdapter.ts` and `FieldServiceAdapterV1.ts` to match.

#### 1c. Endpoint: `POST /reschedule-assessment`

File: `src/routes/field-service-tools.ts`

```typescript
router.post('/reschedule-assessment', verifyInternalApiKey, async (req, res) => {
  const { locationId, callerPhoneNumber, assessmentId, startTime, endTime, instructions } = req.body;
  // validate assessmentId, startTime required
  // call adapter.rescheduleAssessment(context, assessmentId, { startTime, endTime, instructions })
  // format response: "Assessment rescheduled to Monday, February 24 at 10:00 AM."
});
```

#### 1d. Python tool: `fs_reschedule_assessment`

File: `livekit-python/tools/fs_assessment.py`

```python
@function_tool()
async def fs_reschedule_assessment(
    ctx: RunContext,
    assessment_id: str,
    start_time: str,
    end_time: Optional[str] = None,
    instructions: Optional[str] = None,
) -> str:
    """
    Schedule or reschedule an assessment.
    Use this to:
    - Schedule a previously unscheduled assessment (from a service request)
    - Reschedule an already-scheduled assessment to a new time
    Always check availability first.
    """
```

Register as `"fs-reschedule-assessment"` in `__init__.py`.

---

### Change 2: `getClientSchedule` — unified scheduled items view

Currently `getAppointments` only queries visits (via `client.jobs.visits`). We need a method that returns **all** scheduled items for a client: assessments, visits, events, tasks.

Jobber provides two paths:
- **Option A**: `scheduledItems` query with `occursWithin` filter (global, not client-scoped)
- **Option B**: `client { scheduledItems }` — client-scoped, supports `ClientScheduledItemsFilter`

**Decision: Option B** — `client.scheduledItems` is client-scoped and directly gives us what we need.

#### 2a. Adapter: `getClientSchedule()`

File: `src/adapters/field-service/platforms/jobber/JobberAdapter.ts`

```typescript
async getClientSchedule(
  context: CallerContext,
  customerId: string,
  filters?: { type?: 'ASSESSMENT' | 'VISIT' | 'EVENT' | 'BASIC_TASK'; includeCompleted?: boolean },
  limit?: number
): Promise<any[]>
```

**GraphQL query:**
```graphql
query GetClientSchedule($clientId: EncodedId!, $filter: ClientScheduledItemsFilter) {
  client(id: $clientId) {
    scheduledItems(first: $limit, filter: $filter) {
      nodes {
        ... on ScheduledItemInterface {
          id
          title
          startAt
          endAt
          duration
          allDay
          __typename
        }
        ... on Assessment {
          instructions
          isComplete
          clientConfirmed
          request { id title }
          property { id address { street1 city } }
          assignedUsers(first: 5) { nodes { id name { full } } }
        }
        ... on Visit {
          visitStatus
          instructions
          isComplete
          clientConfirmed
          job { id jobNumber title }
          property { id address { street1 city } }
          assignedUsers(first: 5) { nodes { id name { full } } }
        }
        ... on Event {
          recurrenceSchedule { friendly }
        }
        ... on Task {
          isComplete
        }
      }
    }
  }
}
```

**Return type**: Unified list of scheduled items, each tagged with `type` field (`assessment`, `visit`, `event`, `task`).

```typescript
return items.map(item => ({
  id: item.id,
  type: item.__typename.toLowerCase(), // 'assessment', 'visit', 'event', 'task'
  title: item.title,
  startAt: item.startAt,
  endAt: item.endAt,
  duration: item.duration,
  status: this.inferScheduledItemStatus(item),
  // ... type-specific fields
}));
```

#### 2b. Endpoint: `POST /get-client-schedule`

File: `src/routes/field-service-tools.ts`

Formats a human-readable schedule:
```
You have 3 upcoming items:
1. [Assessment] Plumbing Repair consultation — Wednesday, Feb 26 at 10:00 AM (unscheduled)
2. [Visit] HVAC Tune-Up — Friday, Feb 28 at 2:00 PM (assigned to Mike)
3. [Assessment] Roof Inspection — pending scheduling
```

Includes assessment IDs and visit IDs so the agent can operate on them.

#### 2c. Python tool: `fs_get_client_schedule`

```python
@function_tool()
async def fs_get_client_schedule(
    ctx: RunContext,
    customer_id: str,
    item_type: Optional[str] = None,
) -> str:
    """
    Get all scheduled items for a customer — assessments, visits, events, tasks.
    Use this when a caller asks "What do I have coming up?" or "When is my assessment?"
    
    Args:
        customer_id: The customer's ID.
        item_type: Filter by type: "ASSESSMENT", "VISIT", "EVENT", "BASIC_TASK". Optional.
    """
```

Register as `"fs-get-client-schedule"` in `__init__.py`.

---

### Change 3: Re-enable `autoScheduleAssessment` prompt branching

The `autoScheduleAssessment` toggle exists in the agent config but the prompt was recently unified to always create unscheduled assessments inline. We need to re-add conditional branching.

File: `src/server.ts`

**When `autoScheduleAssessment === false` (current behavior):**
Steps 8-10 remain as-is. Assessment is inlined as unscheduled. No scheduling tools used for new callers.

**When `autoScheduleAssessment === true` (new behavior):**
After step 9 (creating the request with inline unscheduled assessment), add steps:

```
10. The service request created an unscheduled assessment. Now schedule it:
    a. Call **fs_get_request** with the request_id returned from step 9 to get the assessment_id.
    b. Call **fs_check_availability** for the next 7 days.
    c. Present 2-3 options to the caller: "We have availability on [day] at [time], [day] at [time], or [day] at [time]. Which works best for you?"
    d. Once they pick a time, call **fs_reschedule_assessment** with the assessment_id and the chosen start_time.
    e. Confirm: "Your consultation is scheduled for [day] at [time]."
```

**For returning callers**, add to the workflow section:
```
- Assessment scheduling → fs_get_client_schedule to see current items, then:
  - Schedule unscheduled assessment → fs_check_availability + fs_reschedule_assessment
  - Reschedule assessment → fs_check_availability + fs_reschedule_assessment
  - Cancel assessment → fs_cancel_assessment (always confirm first)
  - Check assessment status → fs_get_request (shows assessment scheduled/unscheduled/completed)
```

File: `src/utils.ts` — mirror the same changes.

---

### Change 4: Timezone handling

**Problem**: The adapter uses `Intl.DateTimeFormat().resolvedOptions().timeZone` which returns the **server's** timezone (likely UTC in production). All scheduling operations produce incorrect times.

**Solution**: Read the business timezone from the Location model or Jobber company settings.

#### 4a. Pass timezone through CallerContext

Currently `CallerContext` only has `callerPhoneNumber` and `businessPhoneNumber`. Add:

```typescript
export interface CallerContext {
  callerPhoneNumber: string;
  businessPhoneNumber?: string;
  timezone?: string; // e.g. "America/Los_Angeles"
}
```

#### 4b. Populate timezone in `buildContext()`

File: `src/routes/field-service-tools.ts`

The `buildContext` function currently only sets `callerPhoneNumber`. Update to also inject timezone from the Location model:

```typescript
function buildContext(callerPhoneNumber: string, timezone?: string): CallerContext {
  return { callerPhoneNumber, timezone: timezone || 'America/Los_Angeles' };
}
```

Eventually read from `location.timezone` when available. For MVP, accept timezone from request body or default to the business's configured timezone.

#### 4c. Use `context.timezone` in adapter

Replace all instances of:
```typescript
const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
```
with:
```typescript
const timezone = context.timezone || 'America/Los_Angeles';
```

**Affected methods**: `checkAvailability`, `createAssessment`, `createAppointment`, `rescheduleAppointment`, `updateAppointmentTime`, `updateAppointmentTimeFallback`, and the new `rescheduleAssessment`.

---

### Change 5: Verify and fix `occursWithin` filter format

**Problem**: The `checkAvailability` method passes:
```typescript
occursWithin: {
  startAt: new Date(dateRange.start).toISOString(),
  endAt: new Date(dateRange.end).toISOString(),
}
```

But the Jobber `DateRange` type likely uses `startDate` / `endDate` (ISO8601Date format `YYYY-MM-DD`), not `startAt` / `endAt`.

**Action**: Test the current query against Jobber's GraphQL explorer. If it fails or returns empty results, change to:
```typescript
occursWithin: {
  startDate: formatDate(new Date(dateRange.start)), // "2026-02-19"
  endDate: formatDate(new Date(dateRange.end)),     // "2026-02-26"
}
```

---

### Change 6: Business hours from config

**Problem**: Business hours are hardcoded to 8 AM – 5 PM in `checkAvailability`.

**Solution (phased)**:

**Phase 1 (now)**: Add `businessHoursStart` and `businessHoursEnd` to the `checkAvailability` endpoint body, with defaults of 8 and 17. The Python tool can pass them from agent config if available.

**Phase 2 (later)**: Read from Location model / Jobber company settings.

---

### Change 7: Enhanced `fs_create_service_request` response

Currently the tool returns just `request_id`. For the auto-schedule flow, the agent also needs the `assessment_id` to schedule it.

**Option A**: Return assessment_id in the `createServiceRequest` response.
**Option B**: Agent calls `fs_get_request` after creating to get assessment_id.

**Decision: Option A** — The adapter already has the assessment data from the `requestCreate` mutation response. Return it in the endpoint response.

File: `src/routes/field-service-tools.ts` (`create-service-request` endpoint)

Add to response:
```typescript
return res.json({
  serviceRequest,
  assessmentId: serviceRequest.metadata?.assessment?.id || null,
  message: `Service request created...${assessmentId ? ` Assessment ID: ${assessmentId}` : ''}`
});
```

File: `livekit-python/tools/fs_service_request.py`

Update return message:
```python
assessment_id = sr.get("metadata", {}).get("assessment", {}).get("id")
# OR if we add assessmentId to the top-level response:
assessment_id = result.get("assessmentId", None)
msg = f"Service request created. request_id={request_id}."
if assessment_id:
    msg += f" assessment_id={assessment_id}."
```

---

## Summary of Changes

### New Files
- None (all changes in existing files)

### Modified Files

| File | Changes |
|------|---------|
| `src/adapters/field-service/FieldServiceAdapter.ts` | Add `rescheduleAssessment`, `getClientSchedule` to interface + ADAPTER_METHOD_NAMES |
| `src/adapters/field-service/BaseFieldServiceAdapter.ts` | Add stub implementations |
| `src/adapters/field-service/FieldServiceAdapterV1.ts` | Update method names list |
| `src/adapters/field-service/platforms/jobber/JobberAdapter.ts` | Add `rescheduleAssessment()`, `getClientSchedule()`, fix timezone in 6+ methods |
| `src/types/field-service.ts` | Add `timezone?` to CallerContext if needed |
| `src/routes/field-service-tools.ts` | Add `reschedule-assessment`, `get-client-schedule` endpoints; update `create-service-request` response; fix `buildContext` for timezone |
| `livekit-python/tools/fs_assessment.py` | Add `fs_reschedule_assessment` tool |
| `livekit-python/tools/fs_schedule.py` | Add `fs_get_client_schedule` tool (new file or in existing) |
| `livekit-python/tools/__init__.py` | Register 2 new tools |
| `src/server.ts` | Re-add `autoScheduleAssessment` prompt branching; update returning caller workflow |
| `src/utils.ts` | Mirror prompt changes |

### New Tool Registration

| Tool Name | Python Function | Endpoint |
|-----------|----------------|----------|
| `fs-reschedule-assessment` | `fs_reschedule_assessment` | `POST /reschedule-assessment` |
| `fs-get-client-schedule` | `fs_get_client_schedule` | `POST /get-client-schedule` |

---

## Implementation Order

1. **Change 5**: Verify `occursWithin` filter format against Jobber GraphQL explorer (manual test)
2. **Change 1**: `rescheduleAssessment` — adapter → interface → endpoint → Python tool
3. **Change 2**: `getClientSchedule` — adapter → endpoint → Python tool
4. **Change 7**: Enhanced `create-service-request` response (return assessment_id)
5. **Change 4**: Timezone handling (CallerContext → buildContext → adapter methods)
6. **Change 3**: Re-enable `autoScheduleAssessment` prompt branching in server.ts + utils.ts
7. **Change 6**: Business hours from config (stretch goal)

---

## Voice Agent Conversation Flows

### Flow A: New Caller + Auto-Schedule

```
Agent: "Hello, this is [business]. How can I help you today?"
Caller: "Hi, my kitchen faucet is leaking."
Agent: [calls fs_get_customer_by_phone → not found]
Agent: [calls fs_get_services → matches "Plumbing Repair"]
Agent: "I can help with that! That sounds like our Plumbing Repair service. Can I get your name?"
Caller: "John Smith"
Agent: [calls fs_create_customer]
Agent: "What's the address where the service is needed?"
Caller: "123 Main St, Sacramento, CA 95811"
Agent: [calls validate_address → calls fs_create_property]
Agent: "Do you have a preferred day or time for someone to come take a look?"
Caller: "Tuesday morning would be great"
Agent: [calls fs_create_service_request → gets request_id + assessment_id]
Agent: [calls fs_check_availability for next 7 days]
Agent: "I have some openings on Tuesday. We have 9 AM, 10:30 AM, or 1 PM. Which works best?"
Caller: "9 AM is perfect"
Agent: [calls fs_reschedule_assessment with assessment_id + Tuesday 9 AM]
Agent: "You're all set! Your consultation is scheduled for Tuesday at 9 AM at 123 Main St. Is there anything else I can help with?"
```

### Flow B: New Caller + Unscheduled (no auto-schedule)

```
[Same as above but after creating the request:]
Agent: "I've submitted your request for Plumbing Repair at 123 Main St. Our team will review it and reach out to schedule a convenient time for the initial consultation."
```

### Flow C: Returning Caller — Check Assessment Status

```
Agent: [calls fs_get_customer_by_phone → found: "John Smith"]
Agent: "Hi John! How can I help you today?"
Caller: "I wanted to check on my plumbing request"
Agent: [calls fs_get_requests → finds request]
Agent: [calls fs_get_request with request_id → assessment is unscheduled]
Agent: "Your plumbing repair request is pending review. You have a consultation that hasn't been scheduled yet. Would you like me to find some available times?"
Caller: "Yes, please"
Agent: [calls fs_check_availability]
Agent: "We have Wednesday at 10 AM, Thursday at 2 PM, or Friday at 9 AM. Which works for you?"
Caller: "Thursday at 2 PM"
Agent: [calls fs_reschedule_assessment with assessment_id + Thursday 2 PM]
Agent: "Done! Your consultation is now scheduled for Thursday at 2 PM."
```

### Flow D: Returning Caller — Reschedule Assessment

```
Caller: "I need to reschedule my consultation"
Agent: [calls fs_get_client_schedule with customer_id]
Agent: "I see you have a plumbing consultation on Thursday at 2 PM. When would you like to move it to?"
Caller: "Can I do Friday morning instead?"
Agent: [calls fs_check_availability for Friday]
Agent: "We have 9 AM or 10:30 AM on Friday. Which do you prefer?"
Caller: "10:30"
Agent: [calls fs_reschedule_assessment]
Agent: "Your consultation has been moved to Friday at 10:30 AM."
```

### Flow E: Returning Caller — Cancel Assessment

```
Caller: "I need to cancel my consultation"
Agent: [calls fs_get_client_schedule]
Agent: "I see you have a plumbing consultation on Friday at 10:30 AM. Are you sure you'd like to cancel it?"
Caller: "Yes"
Agent: [calls fs_cancel_assessment]
Agent: "Your consultation has been cancelled. Would you like me to do anything else?"
```

### Flow F: Returning Caller — View All Scheduled Items

```
Caller: "What do I have coming up?"
Agent: [calls fs_get_client_schedule]
Agent: "You have 2 upcoming items:
  1. Plumbing consultation on Tuesday at 9 AM
  2. HVAC tune-up visit on March 5 at 2 PM with Mike
Is there anything you'd like to change?"
```

---

## Open Questions

1. **`occursWithin` format**: Is it `{ startAt, endAt }` or `{ startDate, endDate }`? Need to test against Jobber GraphQL explorer.
2. **`client.scheduledItems` availability**: Does the Jobber API version we use support `client { scheduledItems }`? Need to verify with a test query.
3. **Assessment ID in `requestCreate` response**: Does the inline `assessment` input in `requestCreate` return the assessment ID in the mutation response? Need to verify. If not, we call `getRequest` after creation.
4. **Business timezone source**: Should we store timezone on the Location model in our DB, or read it from Jobber? For now, default to a sensible timezone and plan to configure per-location.
5. **Duration for assessments**: What's the default assessment duration? 30 min? 60 min? Should this come from the service catalog's `durationMinutes` field?
