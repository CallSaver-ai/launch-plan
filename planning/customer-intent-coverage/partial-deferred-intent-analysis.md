# Tier 2/3 Partially Handled & Deferred Intents — Deep Analysis

**Last Updated:** Feb 24, 2026  
**Purpose:** Analyze which partially handled / deferred intents can be upgraded using note attachments, and plan arrival window support across all integrations.

---

## Part 1: Tier 2 & Tier 3 Intents (Partially Handled or Deferred Only)

### Tier 2 — Common Secondary Intents

| # | Intent | Current Status | Current Mechanism |
|---|--------|---------------|-------------------|
| 17 | Mid-conversation service change | PARTIALLY HANDLED | LLM pivots naturally before `create-service-request`; after creation, can't modify |
| 18 | Multiple services ("while you're at it") | PARTIALLY HANDLED | Single `create-service-request` with combined description |
| 19 | Warranty / failed repair | DEFERRED | Creates new service request + callback/transfer |
| 20 | Estimate / quote follow-up | PARTIALLY HANDLED | `fs_get_requests` lookup; defers if no details |
| 21 | Approved estimate → schedule work | PARTIALLY HANDLED | `fs_get_jobs` (HCP only); defers if no job |
| 22 | Emergency / urgent request | DEFERRED | Captures urgency in request; offers transfer or urgent callback |
| 23 | Recurring service setup | DEFERRED | Notes recurring context in request description |
| 25 | Third-party booking ("calling for my mother") | PARTIALLY HANDLED | Can create customer with different name, but no explicit third-party flag |

### Tier 3 — Less Common but Important

| # | Intent | Current Status | Current Mechanism |
|---|--------|---------------|-------------------|
| 27 | Billing / invoice question | DEFERRED | Callback/transfer |
| 28 | Payment ("pay my bill") | DEFERRED | Callback/transfer |
| 29 | Pricing negotiation | DEFERRED | Callback/transfer |
| 30 | Specific technician request | DEFERRED | Note in callback/transfer message |
| 31 | Trip charge / service fee | PARTIALLY HANDLED | Only if in system prompt FAQ |
| 32 | Discount inquiry | DEFERRED | Callback/transfer |
| 33 | Symptom triage ("weird noise") | PARTIALLY HANDLED | Categorizes to nearest service, creates request |
| 35 | ETA / "Where's my technician?" | DEFERRED | Callback/transfer |
| 36 | Access instructions / gate codes | PARTIALLY HANDLED | Goes in service request description |
| 37 | Documentation request ("resend invoice") | DEFERRED | Callback/transfer |
| 38 | Commercial vs. residential | PARTIALLY HANDLED | Not explicitly asked; inferred from context |
| 39 | Safety hazard ("I smell gas") | DEFERRED | Tell caller to evacuate + 911 first |
| 40 | Positive feedback / review | PARTIALLY HANDLED | Thank + suggest review link if in prompt |
| 41 | After-hours awareness | PARTIALLY HANDLED | Implicit — agent always takes info |
| 42 | "Just leave a message" | DEFERRED | Capture message → callback |
| 43 | Referral request | DEFERRED | Callback |
| 44 | Accessibility / special needs | PARTIALLY HANDLED | Goes in service request description |

---

## Part 2: Note Attachment Capabilities by Platform

### Full API Note Support (from official docs)

#### Housecall Pro

| Entity | API Field | How it Works | Adapter Status |
|--------|-----------|-------------|---------------|
| **Customer** | `notes` (string) on `POST /customers` and `PUT /customers/{id}` | Single notes string, set at creation or update | **NOT PASSED** — `createCustomer` doesn't include notes. `updateCustomer` doesn't either. |
| **Lead (ServiceRequest)** | `note` (string) on `POST /leads` | Single note string, set at creation | **ALREADY USED** ✅ — builds note from description + summary + desiredTime + intakeAnswers (line 239) |
| **Estimate (Assessment)** | `note` (string) on `POST /estimates` + `schedule.arrival_window_in_minutes` | Note set at creation; arrival window on schedule | **PARTIALLY USED** — instructions added via `POST /jobs/{id}/notes` after creation, but `note` field on estimate create not used. `arrival_window_in_minutes` NOT USED. |
| **Estimate Option** | `notes` (array of `{ id, content }`) on options | Notes attached to estimate options | Not used |
| **Job** | `POST /jobs/{id}/notes` with `{ note: string }` | Append-only notes | **IMPLEMENTED** ✅ — `addNoteToJob` works |
| **Address/Property** | No notes on addresses | N/A | N/A |

#### Jobber

| Entity | API Field | How it Works | Adapter Status |
|--------|-----------|-------------|---------------|
| **Client** | `notes` connection → `ClientNote` entities with `message`, `createdAt`, `createdBy`, `pinned` flag. Also `noteAttachments` for files. | Structured note objects (not a single string). Separate mutations to create/edit notes (`clientNoteCreate`?). `clientEdit` does NOT support notes inline. | **READ ONLY** — reads in `findCustomerByEmail`. No create/write mutation implemented. |
| **Property** | No notes on properties | Properties have addresses only. Notes live at Client or Request level. | N/A |
| **Request** | `notes` connection → `RequestNoteUnion` entities + `noteAttachments` for files | Structured note objects, same pattern as Client notes | **NOT USED** — only uses `description` field via `requestCreate` mutation |
| **Assessment** | Inherits notes from parent Request | No separate note field | N/A |
| **Job** | Notes exist (likely `jobNoteCreate` mutation) | Similar to ClientNote pattern | **NOT IMPLEMENTED** — `addNoteToJob` throws `Error('Not implemented')` ⚠️ |
| **Quote/Estimate** | Notes likely exist on Quote entity | Similar pattern | Not explored |

### Current Note Support in Codebase (Summary)

| Entity | Jobber Adapter | HCP Adapter | Tool Exposed to Agent? |
|--------|---------------|-------------|----------------------|
| **Customer** | Read only | Not passed at creation | **NO** |
| **Lead/Request** | Uses `description` only | `note` field ✅ already used | **NO** (note set at creation, can't add after) |
| **Estimate/Assessment** | N/A | Instructions via `POST /jobs/{id}/notes` | **NO** (internal only) |
| **Job** | **NOT IMPLEMENTED** ⚠️ | **IMPLEMENTED** ✅ | **YES** — `fs_add_note_to_job` (broken for Jobber) |

### Key Gaps Identified

1. **Jobber `addNoteToJob` is NOT IMPLEMENTED** — throws `Error('Not implemented')` at runtime. This is a **launch blocker bug** — the tool is exposed to the voice agent and will crash for Jobber users. Need to either implement the GraphQL mutation or remove from Jobber's tool list.

2. **HCP `createCustomer` doesn't pass `notes`** — Easy fix: pass a `notes` field from `CreateCustomerInput` (or build from context like we do for leads). Would enable capturing notes like "Prefers text-only communication" or "Referred by neighbor" at customer creation time.

3. **HCP estimate creation doesn't use `note` field** — The `POST /estimates` API accepts a `note` field, but we don't pass it. Instead we use `POST /jobs/{id}/notes` after conversion. Could simplify by passing the note at creation.

4. **HCP estimate schedule doesn't pass `arrival_window_in_minutes`** — The schedule object on `POST /estimates` accepts `arrival_window_in_minutes`, but we don't pass it. This is relevant for Phase 1 arrival windows.

5. **No `addNoteToRequest` tool** — This is the biggest gap. For both new and returning callers, the service request is the primary entity. Being able to add notes AFTER creation would help with:
   - Access instructions / gate codes (#36)
   - Specific technician preference (#30)
   - Third-party booking context (#25)
   - Recurring service notes (#23)
   - Warranty context (#19)
   - Accessibility needs (#44)
   - For Jobber: would need `requestNoteCreate` mutation (notes connection exists on Request)
   - For HCP: leads don't support post-creation notes, but after conversion to estimate → `POST /jobs/{id}/notes`

6. **No `addNoteToCustomer` tool** — Would help with:
   - Communication preferences
   - Landlord/tenant relationships
   - General caller notes
   - For Jobber: need `clientNoteCreate` mutation
   - For HCP: `PUT /customers/{id}` with `notes` field (appending to existing string)

### Which Intents Could Be Upgraded with Notes?

| # | Intent | What Note Would Capture | Target Entity | Platform Support |
|---|--------|------------------------|---------------|-----------------|
| 19 | Warranty / failed repair | "Follow-up/warranty — previous work may not have resolved the issue. Ref: [service type from prior request]" | New Request (description already does this) or Note on Request | Jobber: Request notes ✅, HCP: Job notes ✅ |
| 22 | Emergency / urgent | "URGENT: [description]. Caller requested immediate attention." | Request description + priority field | Already uses priority field ✅ |
| 23 | Recurring service | "Recurring service requested: monthly lawn maintenance, preferred schedule: first Monday of each month" | Request description (already does this) | ✅ Already works |
| 25 | Third-party booking | "Booked by [caller name] on behalf of [service address occupant]. Contact at property: [name/phone]" | Request description or Customer note | Jobber: Client notes. HCP: Customer notes field |
| 30 | Specific technician | "Preferred technician: Steve" | Request note or Job note | Jobber: Request note. HCP: Job note ✅ |
| 36 | Access instructions | "Gate code: 1234. Key under doormat. Park on street — driveway blocked." | Request note or Job note | Jobber: Request note. HCP: Job note ✅ |
| 42 | "Just leave a message" | Verbatim message from caller | Callback request body | Already goes in callback ✅ |
| 44 | Accessibility / special needs | "Caller uses wheelchair — tech will need to know about stairs to attic" | Request note or Property note | Jobber: Request note. HCP: Job note |

### Recommendation for V1 Launch

**Don't build new note tools for launch.** The `create-service-request` `description` field already captures most context. The prompt instructs the agent to include relevant details in the service request description.

**Post-launch (V1.1) priorities:**
1. **Fix Jobber `addNoteToJob`** — implement the GraphQL mutation (likely `jobNoteCreate` or similar)
2. **Add `addNoteToRequest` tool** — Jobber has `requestNote` mutations; HCP can use job notes on the converted estimate
3. **Expose `addNoteToCustomer`** — Jobber has `ClientNote` mutations; HCP has `notes` field on customer PATCH

---

## Part 3: Arrival Windows

### Current State

**We do NOT communicate arrival windows to callers.** When the agent books an appointment, it says "Your consultation is scheduled for Tuesday at 9:00 AM" — an exact time. In reality, field service businesses almost always use arrival windows ("We'll be there between 9 and 10 AM").

### Platform Capabilities

#### Jobber

From the API docs provided:
```
ArrivalWindow {
  centeredOnStartTime: Boolean!   // Whether centered on the scheduled start
  duration: Minutes!              // Window duration in minutes
  startAt: ISO8601DateTime!       // Window start
  endAt: ISO8601DateTime!         // Window end
  id: EncodedId!
}
```

- Arrival window is a **field on the Request** entity (`request.arrivalWindow`)
- Set when creating/scheduling the assessment
- `centeredOnStartTime` controls whether the window is centered on the booked time or starts at the booked time
- The Jobber help article says businesses configure arrival windows in their settings

**Current adapter behavior:** We call `rescheduleAssessment` with a `startTime` and `endTime`. The Jobber API may automatically apply the company's default arrival window based on these. We don't explicitly read or communicate the arrival window to callers.

**What we need to do:**
1. Read the arrival window from the `requestCreate` / `assessmentEdit` response
2. Communicate it to the caller: "We'll be there between 9:00 and 10:00 AM on Tuesday"
3. The arrival window duration is likely configured in Jobber's company settings (not something we control)

#### Housecall Pro

From the API docs provided:
```
Company {
  default_arrival_window: string   // e.g., "60" (minutes)
}

Estimate.schedule {
  arrival_window: integer          // minutes
}

Appointment {
  arrival_window_minutes: integer  // minutes
}
```

- `default_arrival_window` is a **company-level setting** returned from `GET /company`
- Individual estimates and appointments can have their own `arrival_window` / `arrival_window_minutes`
- The HCP help article says arrival windows are set in company settings and shown on customer notifications

**Current adapter behavior:** We fetch availability from HCP's booking windows but don't read or communicate the `arrival_window_minutes` from scheduled items.

**What we need to do:**
1. Fetch `default_arrival_window` from `GET /company` (could cache this alongside company info)
2. When presenting booked times, offset by arrival window: "We'll be there between 9:00 and 10:00 AM"
3. The booking window logic already accounts for arrival windows internally (HCP manages it)

#### Google Calendar

GCal has **NO native arrival window concept.** Events have an exact start and end time. This is our problem to solve.

**Current behavior:**
- `defaultAppointmentDurationMinutes` — how long the service takes (e.g., 60 min)
- `bufferTimeBetweenAppointmentsMinutes` — gap between events (e.g., 15 min)
- Availability check looks for gaps ≥ (duration + buffer) between existing events

**Proposed approach for GCal arrival windows:**

Add a new setting: `arrivalWindowMinutes` (default: 0, meaning no arrival window / exact times)

**How it would work:**

```
Settings:
  arrivalWindowMinutes: 30
  defaultAppointmentDurationMinutes: 60
  bufferTimeBetweenAppointmentsMinutes: 15

Scenario: Available slot starts at 9:00 AM

Without arrival window (current):
  - Tell caller: "9:00 AM"
  - Calendar block: 9:00 AM - 10:00 AM (60 min service)
  - Next slot available: 10:15 AM (after 15 min buffer)

With 30-minute arrival window:
  - Tell caller: "between 9:00 and 9:30 AM"
  - Calendar block: 9:00 AM - 10:30 AM (30 min window + 60 min service)
  - Next slot available: 10:45 AM (after 15 min buffer)
  - Event title: "HVAC Tune-up - John Smith"
  - Event description includes: "Arrival window: 9:00 - 9:30 AM"
```

**Impact on availability calculation:**
- Total block per appointment = `arrivalWindowMinutes + defaultAppointmentDurationMinutes`
- The existing `checkAvailability` in the Jobber adapter uses `defaultAppointmentMinutes` from CallerContext for slot sizing
- For GCal, the server.ts `google-calendar-check-availability` handler would need to use `arrivalWindowMinutes + defaultAppointmentDurationMinutes` as the effective duration

**Impact on agent speech:**
- Currently: "We have availability on Tuesday at 9:00 AM"
- With arrival window: "We have availability on Tuesday. Our technician can arrive between 9:00 and 9:30 AM"
- This is a system prompt change — add conditional text when `arrivalWindowMinutes > 0`

### Implementation Plan

#### Phase 1: Read & Communicate (Low effort — launch blocker candidate)

For Jobber and HCP, the platform already manages arrival windows. We just need to:

1. **HCP: Fetch `default_arrival_window` from GET /company**
   - Add to `getCompanyInfo()` response or cache separately
   - Pass to agent via system prompt or tool response context

2. **Jobber: Read `arrivalWindow` from Request/Assessment responses**
   - Update GraphQL queries for request/assessment to include `arrivalWindow { startAt endAt duration }`
   - When agent communicates schedule, include the window

3. **System prompt update**: When arrival window is available, instruct agent:
   - Instead of: "Your consultation is at 9:00 AM"
   - Say: "Our technician will arrive between 9:00 and 10:00 AM"

4. **Tool response formatting**: Update `reschedule-assessment` and `create-assessment` responses to include arrival window in the `message` field

#### Phase 2: GCal Arrival Windows (Medium effort — post-launch)

1. **Add setting**: `arrivalWindowMinutes` to `Location.settings.appointmentDuration` (alongside `defaultMinutes` and `bufferMinutes`)

2. **Update `getLocationSettings()`** in field-service-tools.ts to read `arrivalWindowMinutes`

3. **Update GCal availability check** in server.ts:
   - Effective slot duration = `arrivalWindowMinutes + defaultAppointmentDurationMinutes`
   - Present windows to caller instead of exact times

4. **Update GCal event creation** in server.ts:
   - Event duration = `arrivalWindowMinutes + defaultAppointmentDurationMinutes`
   - Event description includes: "Arrival window: [start] - [start + arrivalWindowMinutes]"

5. **Update system prompt** for GCal locations with `arrivalWindowMinutes > 0`

6. **Frontend**: Add `arrivalWindowMinutes` field to Location settings UI (alongside appointment duration and buffer)

#### Where to Store the Setting

| Integration | Where Arrival Window Lives | How We Access It |
|-------------|---------------------------|-----------------|
| **Jobber** | Jobber company settings → applied automatically to assessments | Read from Request/Assessment `arrivalWindow` field in API response |
| **HCP** | `GET /company → default_arrival_window` | Fetch once, cache in agent config or system prompt |
| **GCal** | `Location.settings.appointmentDuration.arrivalWindowMinutes` | Read from Location settings (new field) |
| **No Integration** | N/A | No scheduling = no arrival windows |

### Decision for Launch

**Recommendation: Phase 1 only (Jobber + HCP read & communicate)**

- For Jobber: The platform already manages arrival windows. We just need to read them from API responses and tell the caller.
- For HCP: Fetch `default_arrival_window` from company settings and include in scheduling communication.
- For GCal: **Defer to post-launch.** Adding `arrivalWindowMinutes` to Location settings + modifying availability calculation + event creation is unnecessary complexity for launch. GCal businesses are typically smaller operations that can handle exact appointment times for now.

The prompt change is minimal — add one conditional line about communicating arrival windows when they exist in the response data.

---

## Part 4: Summary of Recommended Actions

### ✅ Completed (This Session — Feb 24, 2026)

1. **Safety hazard handling** — Added `🚨 SAFETY HAZARDS — IMMEDIATE ACTION REQUIRED` section to BOTH returning caller and new caller fsInstructions in `server.ts`. Covers: gas leak, electrical fire, flooding, carbon monoxide, structural damage. Agent stops workflow, directs to 911/utility, then resumes after safety confirmed.

2. **Symptom triage** — Added `SYMPTOM TRIAGE — GATHERING DETAILS` section to stored prompt in `utils.ts`. Agent asks 1-2 follow-up questions (What's happening? How long? What have you tried? Affected area?) and includes details in service request description/summary.

3. **Commercial vs residential** — Added `COMMERCIAL VS RESIDENTIAL` section to stored prompt in `utils.ts`. Agent asks if unclear, includes answer in service request description.

4. **"Leave a message" handling** — Added to INTENTS YOU CANNOT HANDLE in both branches. Agent takes full message → creates callback request → reassures caller.

5. **Technician status / "Where is the technician?"** — Added to returning caller INTENTS section. Agent looks up via `fs_get_client_schedule` / `fs_get_appointments`, shares scheduled time, assigned tech, visit status, arrival window if available. Falls back to callback request for real-time ETA.

6. **Discounts/promotions** — Tweaked promotions prompt in `utils.ts` to explicitly handle direct questions ("Do you have any deals?"). Agent now shares relevant promotions when asked directly, not just proactively after booking.

7. **Jobber client notification settings** — Added `receivesFollowUps`, `receivesInvoiceFollowUps`, `receivesQuoteFollowUps`, `receivesReminders`, `receivesReviewRequests` (all `true`) to `createCustomer` input in `JobberAdapter.ts`. New clients get all Jobber automation benefits.

8. **After-hours awareness** — Removed from list. Not needed — scheduling logic handles business hours validation, and agent always takes info regardless of time.

### Pre-Launch (Still TODO)
- [ ] **Fix Jobber `addNoteToJob`** — currently throws `Error('Not implemented')`. Either implement the GraphQL mutation or remove from Jobber's tool list to prevent runtime crash.
- [ ] **Phase 1 arrival windows (tool response formatting)**: Surface arrival window data that's already in Jobber appointment metadata into the tool response `message` field for `get-appointments` and `get-client-schedule`. Fetch HCP `default_arrival_window` from `GET /company`.
- [ ] **HCP `createCustomer` notes** — Easy fix: pass `notes` field when creating customers (e.g., for communication preferences or referral context).
- [ ] **HCP estimate `arrival_window_in_minutes`** — Pass in `scheduleEstimate()` call to set per-appointment arrival windows.

### Post-Launch (V1.1)
- [ ] Add `addNoteToRequest` tool (Jobber: `requestNoteCreate` mutation, HCP: job notes after lead→estimate conversion)
- [ ] Add `addNoteToCustomer` tool (Jobber: `clientNoteCreate` mutation, HCP: `PUT /customers/{id}` with `notes`)
- [ ] GCal arrival windows (Phase 2 — new `arrivalWindowMinutes` Location setting + availability calc update)
- [ ] Implement remaining partially-handled intents via note attachments

### Won't Do (Not Worth the Complexity)
- Property-level notes (too granular; request description covers it)
- Multi-line-item estimates via voice (single description + notes is sufficient)
- Real-time tech ETA tracking (requires GPS/dispatch integration)
- Payment processing via voice (PCI compliance nightmare)
