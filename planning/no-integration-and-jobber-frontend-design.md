# Frontend Integration Modes & CallSaver Source Attribution Plan

**Created**: Feb 20, 2026  
**Status**: Design / Planning  
**Scope**: No-integration mode, Jobber frontend redesign, Google Calendar source filtering, CallSaver attribution

---

## Part 0: CallSaver Source Attribution — Show Only Our Data

### Problem

When displaying appointments, service requests, and calendar events in the CallSaver frontend, we must **only show data created by CallSaver** — not manually-created Jobber requests, not events the business owner added to Google Calendar themselves, etc. This ensures the frontend is a clean view of "what our voice agent booked."

### Jobber Source Attribution

**Current state**: Jobber's `requestCreate` mutation auto-assigns a `source` field based on the API integration. When we create requests via the Jobber API through Nango, Jobber sets the source to the integration name (likely `"CallSaver"` or the Nango integration display name).

The `source` field is already:
- Returned in GraphQL queries (`request.source`) — see `getRequests()` and `getRequest()` in `JobberAdapter.ts`
- Stored in our unified `ServiceRequest.metadata.source` by `mapJobberRequestToServiceRequest()`

**Action needed**:
1. **Verify the exact source string** Jobber assigns to API-created requests (test by creating a request and checking `source` in the response)
2. **Filter by source** in the new `GET /me/service-requests` endpoint — only return requests where `metadata.source` matches our integration name
3. **Similarly for customers**: Jobber clients created via API may not have a `source` field. We should filter by the `phone:` tag we add, or by checking if the client was created within a CallSaver call session. Alternative: maintain a mapping table in our DB.

**Jobber source values** (to verify):
- API-created requests: likely `"CallSaver"` or `"API"` or the Nango integration name
- Manually created in Jobber UI: `"Web"` or `"Manual"`
- From Jobber's own lead forms: `"Online"`

### Google Calendar Source Attribution

**Current state**: When creating Google Calendar events via `google-calendar-create-event`, we store metadata in `extendedProperties.shared`:

```typescript
// server.ts:11395-11418
eventData.extendedProperties = {
  shared: {
    callerPhoneNumber: normalizedPhone,  // E.164 format
    callerId: callerId,                   // Internal Caller record ID
  }
};
```

There is **no explicit `source: "CallSaver"` property** currently set.

**Action needed**:
1. **Add `source: "callsaver"` to `extendedProperties.shared`** when creating events:
   ```typescript
   sharedProperties.source = 'callsaver';
   ```
2. **Filter calendar events by source** when listing for the frontend. Google Calendar API supports filtering by `sharedExtendedProperty`:
   ```
   GET /calendars/{calendarId}/events?sharedExtendedProperty=source%3Dcallsaver
   ```
   This is a native Google Calendar API filter — no client-side filtering needed.
3. **Update the `google-calendar-list-events` endpoint** (or create a new user-facing endpoint) to include the `sharedExtendedProperty=source%3Dcallsaver` filter parameter.

**Files to modify**:
- `server.ts` → `google-calendar-create-event` handler: add `source: 'callsaver'` to `sharedProperties`
- `server.ts` → `google-calendar-list-events` handler (or new `GET /me/appointments` endpoint): add `sharedExtendedProperty` filter
- Frontend Appointments page: only shows CallSaver-sourced events

### Our Internal `Appointment` Table

We already create an `Appointment` record in our DB when a Google Calendar event is created (`server.ts:11470-11487`). This table has `platform: 'google-calendar'` and `externalId: eventId`. For the frontend, we could:
- **Option A**: Query our `Appointment` table directly (already filtered to CallSaver-created events)
- **Option B**: Query Google Calendar API with source filter (real-time, but requires API call)

**Recommendation**: Option A for the list view (fast, already filtered), Option B only if we need real-time status (e.g., checking if event was manually deleted in Google Calendar).

---

## Part 1: No-Integration Mode (User skips integration during onboarding)

### Current State

When no integration is connected:

**Backend (`server.ts` → `getLiveKitToolsForLocation`)**:
- Tools returned: `validate-address`, `request-callback` (Path A) or `transfer-call` (Path B), `submit-intake-answers`
- No scheduling tools, no fs-* tools

**Backend (`utils.ts` → `generateSystemPromptForLocation` → `default` case)**:
- Prompt enters "INTAKE MODE"
- Agent answers questions about business, services, hours, service areas
- Collects intake info via `submit_intake_answers`
- Tells caller "the team will follow up"
- Explicitly says "I'd be happy to take down your information and have someone from the team reach out to schedule that for you"

**This is already correct behavior.** The agent gracefully degrades to an intake + callback agent.

### Frontend Changes Needed

#### 1. Hide "Appointments" sidebar item when no integration is connected

**File**: `src/components/layout/app-sidebar.tsx`

The sidebar already conditionally hides "Callback Requests" based on `hasKeepNumberLocation`. We need similar logic for "Appointments".

**Implementation**:
- In the `useEffect` that fetches locations, also fetch integrations via `apiClient.user.getIntegrations()`
- Track `hasActiveIntegration` state (true if any integration is connected)
- In the `filteredNavGroups` filter, hide "Appointments" when `!hasActiveIntegration`

```typescript
// Add state
const [hasActiveIntegration, setHasActiveIntegration] = useState(false);

// In useEffect, after fetching locations:
try {
  const integrationsData = await apiClient.user.getIntegrations();
  const connected = integrationsData.integrations?.some((i: any) => i.connected);
  setHasActiveIntegration(!!connected);
} catch (error) {
  log.error('Error fetching integrations:', error);
}

// In filteredNavGroups filter:
if (item.title === 'Appointments' && !hasActiveIntegration) {
  return false;
}
```

#### 2. Keep "Callers" and "Callback Requests" visible

Already the case. No changes needed. These are useful in no-integration mode because:
- **Callers**: Shows who has called, their info, call history
- **Callback Requests**: Shows pending callbacks the team needs to action

#### 3. Dashboard adjustments (optional, lower priority)

The dashboard may show appointment-related widgets. Consider:
- Hiding appointment count/list widgets when no integration
- Showing a "Connect an integration" CTA card instead

### System Prompt — Already Correct

The `default` case in `generateSystemPromptForLocation` (utils.ts:1767-1791) already handles this well:
- Lists services (from location config)
- Shows business hours
- Instructs agent to collect intake info
- Instructs agent to tell caller the team will follow up
- Explicitly says no scheduling tools available

**No backend changes needed for the system prompt.**

### Edge Case: User connects integration later

When a user connects an integration after onboarding:
- The sidebar should reactively show "Appointments" (re-fetch on integration connect)
- The agent-config endpoint already dynamically selects tools based on active integration
- System prompt already switches based on active integration

**No special handling needed** — the system is already dynamic.

---

## Part 2: Jobber ↔ Caller Integration & Frontend Redesign

*Consolidated from `jobber-caller-integration-design.md` and `feb20-frontend-work.md`*

### Status of Jobber-Caller Backend Integration (from jobber-caller-integration-design.md)

| Phase | Description | Status | Evidence |
|-------|-------------|--------|----------|
| **Phase 1**: Sync name to Caller on `fs_create_customer` | Upsert Caller with firstName, lastName, name, email | ✅ **DONE** | `field-service-tools.ts:177-219` |
| **Phase 2**: Sync address to CallerAddress on `fs_create_property` | Upsert CallerAddress with full address | ✅ **DONE** | `field-service-tools.ts:294-335` |
| **Phase 3**: Store `externalCustomerId` + `externalPlatform` on Caller | Links Caller to Jobber Client ID | ✅ **DONE** | Set in Phase 1 code: `externalCustomerId: customer.id, externalPlatform: 'jobber'` |
| **Phase 4a**: Sidebar menu adaptation | Dynamic labels based on integration | ❌ **NOT DONE** | Sidebar still shows static "Callers" / "Appointments" |
| **Phase 4b**: "View in Jobber" link on Caller detail | External link using `externalCustomerId` | ❌ **NOT DONE** | No external links on Caller cards yet |
| ~~Phase 4c~~: ~~Requests + Schedule pages~~ | ~~Dropped~~ | N/A | Jobber's own UI is better for full request/schedule management |
| **Phase 5**: Disconnect button (frontend + backend) | `DELETE /me/integrations/:integrationType` + UI button | ✅ **DONE** | `integration-card.tsx:98-117` (red Disconnect button), `cleanupAfterDisconnect` called at `server.ts:6868` |
| **Phase 6**: Integration switching cleanup | Clear `externalCustomerId`, `externalPlatform`, agent config on disconnect/switch | ✅ **DONE** | `cleanupAfterDisconnect` called in Nango webhook handler when deleting old connections |

### Status of Feb 20 Frontend Work (from feb20-frontend-work.md)

| Item | Status |
|------|--------|
| Onboarding flow reorder (integrations before services) | ✅ **DONE** |
| Auto-Schedule Assessment toggle in Location Settings | ✅ **DONE** |
| Include Pricing toggle in Location Settings | ✅ **DONE** |
| Disconnect Integration button + dialog | ✅ **DONE** |
| Backend `agentConfig` on `PATCH /me/locations/:locationId` | ✅ **DONE** |
| `fs-*` tools + field-service system prompt instructions | ✅ **DONE** |

### Product Decision: CallSaver-Sourced Data Only

*Carried forward from jobber-caller-integration-design.md Phase 4*

The dashboard shows **only data that originated from CallSaver calls**, not all Jobber data. Rationale:
- **CallSaver's value prop** is "here's what your AI agent did for you" — the dashboard answers: *How many leads did my agent capture? What did callers ask for? Were they scheduled?*
- **Jobber is already the system of record** for all clients/jobs/invoices. We don't replicate it.
- **No extra API calls** on page load — local Caller/CallRecord data is fast.
- **No scope creep** — we'd otherwise be rebuilding Jobber's UI.

### Integration Switching & Data Preservation

*Carried forward from jobber-caller-integration-design.md Phase 6 — already implemented*

| Data | On Disconnect | On Switch | Rationale |
|------|--------------|-----------|----------|
| `Caller` records | **KEEP** | **KEEP** | Phone numbers, names, call history are platform-agnostic |
| `CallerAddress` records | **KEEP** | **KEEP** | Addresses are useful regardless of integration |
| `CallRecord` records | **KEEP** | **KEEP** | Transcripts, summaries, evaluations are always valuable |
| `Caller.externalCustomerId` | **CLEAR** | **CLEAR** | Jobber IDs are meaningless after disconnect |
| `Caller.externalPlatform` | **CLEAR** | **CLEAR** | Same — stale platform reference |
| `Agent.config.autoScheduleAssessment` | **CLEAR** | **CLEAR** | Jobber-specific setting |
| `Agent.config.includePricing` | **CLEAR** | **CLEAR** | Jobber-specific setting |

### What Still Needs to Be Built

#### A. Redesign "Appointments" Page → "Service Requests" Page (Jobber mode)

**Current state**: The Appointments page pulls from Google Calendar events via `useCalendarEvents` hook.

**Needed**: When Jobber is connected, show **Service Requests** (CallSaver-sourced only) pulled from Jobber.

**Design**:

```
┌─────────────────────────────────────────────────────────────┐
│ Service Requests                                    [Filter]│
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 🔧 AC Unit Not Cooling                    Feb 19, 2026 │ │
│ │ John Smith · 123 Oak St, Reno NV                       │ │
│ │ Status: Assessment Scheduled (Feb 21 @ 10:00 AM)       │ │
│ │ Service: HVAC Repair ($150)                             │ │
│ │                                    [View in Jobber →]   │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 🔧 Furnace Making Noise                   Feb 18, 2026 │ │
│ │ Sarah Johnson · 456 Pine Ave, Sparks NV                │ │
│ │ Status: Assessment Unscheduled                         │ │
│ │ Service: Heating Repair                                │ │
│ │                                    [View in Jobber →]   │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Backend endpoint needed**: `GET /me/service-requests`
- Calls Jobber API via the FieldServiceAdapter to fetch requests
- **Filtered by source** — only return requests created by CallSaver (see Part 0)
- Returns: request ID, customer name, property address, service type, status, assessment status/date, Jobber URL
- Jobber `jobberWebUri` is already returned on customer objects (stored in `metadata.jobberWebUri`)

**Frontend**:
- New hook: `useServiceRequests` — fetches from the new endpoint
- The Appointments page component detects active integration type
- If Jobber → render Service Requests view (CallSaver-sourced only)
- If Google Calendar → render existing Calendar view (CallSaver-sourced only, via `Appointment` table or `sharedExtendedProperty` filter)
- If no integration → show empty state with "Connect an integration" CTA

**Sidebar label**: Change "Appointments" to be dynamic:
- Jobber connected → "Service Requests"
- Google Calendar connected → "Appointments"
- No integration → hidden

#### B. Caller Cards → "View in Jobber" Link

**Current state**: Caller cards show name, phone, address, call history. No external links.

**What's already done** (backend):
- `externalCustomerId` and `externalPlatform` fields exist on `Caller` model ✅
- `fs-create-customer` endpoint already syncs these to the Caller record ✅
- Jobber returns `jobberWebUri` on customer objects (stored in `metadata.jobberWebUri`) ✅

**What's still needed** (frontend only):
- In the Caller card component, if `externalCustomerId` is present and integration is Jobber, show a "View in Jobber" button/link
- The `jobberWebUri` from the Jobber API gives us the direct URL (no need to decode EncodedIds)
- We need to either: (a) store `jobberWebUri` on the Caller record during `fs-create-customer`, or (b) construct the URL from `externalCustomerId`
- Style: small external link icon + "Jobber" text, opens in new tab

#### C. Recent Call Cards → Link to Jobber Request URL

**Current state**: Call record cards show call summary, duration, caller info. No external links.

**Needed**: When a call resulted in a Jobber service request being created, link to it.

**Implementation**:
- The `fs-create-service-request` tool returns a `request_id` (Jobber EncodedId)
- We need to store this on the `CallRecord` (new field: `externalRequestId`, `externalRequestUrl`)
- Jobber request URL: needs verification (see Open Questions)

**Backend changes**:
- Add `externalRequestId` and `externalRequestUrl` to `CallRecord` model (migration)
- When `fs-create-service-request` succeeds during a call, update the CallRecord
- Include in `GET /me/calls` response

**Frontend changes**:
- In the call record card, if `externalRequestUrl` is present, show "View Request in Jobber" link

---

## Part 3: Implementation Priority

### Already Done (from previous sessions)

| # | Item | Status |
|---|------|--------|
| ✅ | Sync name/email to Caller on `fs_create_customer` | Done — `field-service-tools.ts:177-219` |
| ✅ | Sync address to CallerAddress on `fs_create_property` | Done — `field-service-tools.ts:294-335` |
| ✅ | Store `externalCustomerId` + `externalPlatform` on Caller | Done — set in create-customer sync |
| ✅ | Disconnect button (frontend) | Done — `integration-card.tsx:98-117` |
| ✅ | Disconnect endpoint (backend) + `cleanupAfterDisconnect` | Done — `server.ts:6868` |
| ✅ | Integration switching cleanup | Done — called in Nango webhook handler |
| ✅ | Onboarding flow reorder | Done |
| ✅ | Auto-Schedule Assessment + Include Pricing toggles | Done |
| ✅ | `fs-*` tools + field-service system prompt | Done |

### Today's Work

#### Day 1 (Source attribution + quick wins)
1. **Add `source: 'callsaver'` to Google Calendar `extendedProperties.shared`** — 1 line in `server.ts` create-event handler — ~5 min
2. **Hide "Appointments" in sidebar when no integration** — ~30 min
3. **Dynamic sidebar label** (Appointments vs Service Requests) — ~15 min
4. **Verify Jobber source string** — create a test request via the API and check `source` in response
5. **Store `jobberWebUri` on Caller record** during `fs-create-customer` — the Jobber API returns this on customer objects but we don't persist it yet — ~15 min

#### Day 2 (Backend for frontend pages + source filtering)
6. **`GET /me/service-requests` endpoint** — fetches from Jobber via adapter, **filtered by source** — ~2-3 hours
7. **`GET /me/appointments` endpoint** (or extend existing) — queries our `Appointment` table (already CallSaver-only) — ~1-2 hours
8. **Add `externalRequestId`/`externalRequestUrl` to CallRecord model** — migration + endpoint update — ~1 hour
9. **Wire up `fs-create-service-request`** to save external request ID on CallRecord — ~30 min

#### Day 3 (Frontend)
10. **Service Requests page** (Jobber mode for Appointments page) — ~3-4 hours
11. **Appointments page** (Google Calendar mode) — update to use source-filtered endpoint — ~1 hour
12. **Caller card "View in Jobber" link** — uses `externalCustomerId` + `jobberWebUri` already on Caller — ~30 min
13. **Call record card "View Request in Jobber" link** — ~30 min
14. **Empty states** for no-integration mode — ~30 min

---

## Open Questions

1. **Jobber URL format for requests**: The `jobberWebUri` field is already returned on **customer** objects by the Jobber GraphQL API and stored in `metadata.jobberWebUri` by `mapJobberClientToCustomer()`. Need to verify if **requests** also have a `jobberWebUri` field, or if we need to construct the URL manually (e.g., `https://app.getjobber.com/requests/{id}`).

2. ~~**Jobber source string verification**~~ — **RESOLVED**: Confirmed via live test. Jobber auto-assigns `source: "CallSaver"` (capital C, capital S) to requests created via our API integration. Filter by `metadata.source === "CallSaver"` in the `GET /me/service-requests` endpoint.

3. **Polling vs webhook for service request updates**: Should the Service Requests page poll the Jobber API on each page load, or should we set up Jobber webhooks to sync request status changes to our DB?
   - **Recommendation**: Start with polling (simpler), add webhooks later for real-time updates.

4. ~~**Caller ↔ Jobber Customer linking**~~ — **RESOLVED**: Already implemented. The `fs-create-customer` endpoint in `field-service-tools.ts:177-219` updates the Caller record with `externalCustomerId` and `externalPlatform` on every customer creation.

5. **HousecallPro parity**: The same design should work for HCP since both use the unified `fs-*` adapter pattern. The URLs would be different (`app.housecallpro.com/...`).

6. **Google Calendar backward compatibility**: Events created before we add `source: 'callsaver'` won't have the property. Options:
   - A: Also filter by `callerPhoneNumber` presence in `extendedProperties.shared` (all CallSaver events have this)
   - B: Use our internal `Appointment` table as the primary source (already only contains CallSaver-created events)
   - **Recommendation**: Option B — the `Appointment` table is the cleanest approach and doesn't require Google API calls.

7. **Persisting `jobberWebUri` on Caller**: The Jobber API returns `jobberWebUri` on customer objects, and `mapJobberClientToCustomer` stores it in `metadata.jobberWebUri`. But the `fs-create-customer` endpoint currently only saves `externalCustomerId` and `externalPlatform` to the Caller record — not the web URI. We should add a `externalCustomerUrl` field to Caller and persist `jobberWebUri` there during the sync.

---

## Superseded Documents

This plan consolidates and supersedes:
- `planning/jobber-caller-integration-design.md` — Phases 1-3, 5-6 are **done**; Phase 4 items are tracked here
- `planning/feb20-frontend-work.md` — All backend items **done**; frontend items tracked here
