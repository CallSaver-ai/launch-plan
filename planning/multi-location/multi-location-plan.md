# Multi-Location Support Plan

## Current Architecture Summary

### How initial provisioning works today

1. Stripe `checkout.session.completed` webhook → `handleStripePaymentCompletion()` → `executeProvisioning()`
2. `executeProvisioning()` creates: Organization → User → OrganizationMember (role: `'owner'`) → Location(s)
3. Per-location, `createLocationWithFullEnrichment()` does:
   - Fetch Google Place Details (timezone, address, phone)
   - Create `Location` record (with default intake questions)
   - Create default `Agent` record (voice: Ray/Cartesia, background audio on)
   - Enrich with categories → service presets (LLM classification)
   - Enrich with service areas (county/city from Google Place)
   - Setup system prompt (from S3 business profile)
   - Provision phone: Twilio number purchase → `TwilioPhoneNumber` record → LiveKit SIP setup (`LivekitPhoneNumber` + `LivekitAgent` records)
4. Frontend onboarding (`OnboardingPage.tsx`) then lets user customize:
   - Step 1: Review business info (read-only)
   - Step 2: Service areas (city/county selection)
   - Step 3: Services (preset + custom)
   - Step 4: Voice selection
   - Step 5: Connect integrations (Google Calendar, etc.)
   - Step 6: Choose path (keep_your_number vs full_auto_pilot)
   - Step 7: Call forwarding / transfer setup

### Key data model observations

- `Organization` has many `Location`s (1:N)
- `CallRecord` belongs to a `Location` (via `locationId`)
- `Appointment` belongs to a `Location` (via `locationId`)
- `Caller` belongs to an `Organization` (via `organizationId`) with optional `locationId`
- `NangoConnection` (integrations) belongs to `Organization` + `User` — **not location-scoped**
- `OrganizationIntegration` is scoped to `Organization` + `platform` (unique constraint)
- `Agent` belongs to `Location` (1:N, each location has a default agent)
- `TwilioPhoneNumber` belongs to `Location`
- `LivekitPhoneNumber` belongs to `Location`
- `Plan.maxLocations` already exists (nullable) — pricing tier can cap locations
- `OrganizationMember.role` is a free-text `String @default("member")` — values `'owner'` and `'member'` exist in practice

### Role-Based Auth — Current State

**Important:** The codebase does NOT currently enforce role-based authorization on any endpoint. All `/me/*` endpoints only check that the user is a member of *some* organization — they never check `role`.

The `role` field is used in only two read-only scenarios:
- **Weekly report emails** (`queues.ts:1607`): Filters `{ role: 'owner' }` to find email recipients
- **First call notification** (`server.ts:9437`): Filters `{ role: 'owner' }` to find the person to email

**User invites / adding members to an org is NOT implemented yet.** Today, every org has exactly one user (the owner set during Stripe provisioning, `provision-execution.ts:251`). There is a `provisionUserForExistingOrg()` function (`provision.ts:309`) that sets role to `'member'`, but it's only used in an internal provisioning endpoint, not exposed to end users.

**Decision:** Defer role-based auth enforcement (owner/admin gating) until we implement user invites and multi-user organizations. For the add-location endpoint, any authenticated member of the organization can add locations. We note where role checks should be added later in this plan.

---

## Audit: Endpoints with First-Location Hardcoding (`locations[0]`)

This is a comprehensive audit of every endpoint and pattern in the API that assumes a single location or uses `locations[0]`. These will need refactoring to support multi-location properly.

### Category A: Endpoints that hardcode `locations[0]` — MUST FIX

| Endpoint | File:Line | Pattern | Fix Needed |
|----------|-----------|---------|------------|
| `GET /me/organization` | `server.ts:1290-1344` | `take: 1` on locations query, uses `locations?.[0]` for `primaryLocationId`, `state`, `city` | Return `primaryLocationId` for backward compat but also expose all location IDs. State/city should come from a specific location or be removed. |
| `GET /me/agent/phone-number` | `server.ts:5335-5365` | `take: 1` on locations, `locations[0]` for phone numbers | Accept optional `?locationId=` query param. If not provided, return phone numbers for ALL locations (or default to first). |
| `POST /me/calls/manual` | `server.ts:2000-2058` | Falls back to `locations[0].id` when no `locationId` provided | Already accepts `locationId` in body ✅. Fallback to first location is acceptable as a default. |
| Internal provisioning responses | `server.ts:679,703,852` | `existingOrg.locations[0]` in provisioning idempotency responses | Low priority — internal endpoints, not user-facing. |

### Category B: Endpoints that already work with multi-location — NO FIX NEEDED

| Endpoint | File:Line | Why It's OK |
|----------|-----------|-------------|
| `GET /me/locations` | `server.ts:2729-2854` | Already returns ALL locations with details ✅ |
| `GET /me/callers` | `server.ts:2292-2413` | Queries by `organizationId`, includes `locationId` + `locationName` per caller ✅ |
| `GET /me/calls` | `server.ts:4405-4605` | Filters by `location.organizationId`, returns `locationId` + `locationName` per call ✅ |
| `GET /me/calls/:callId` | `server.ts:4608-4702` | Verifies call belongs to org, includes location data ✅ |
| `GET /me/stats` | `server.ts:4706-4780` | Uses `locationIds = locations.map(loc => loc.id)` — aggregates across ALL locations ✅ |
| `GET /me/locations/:locationId/agent` | `server.ts:3088-3150` | Uses `verifyLocationAccess(userId, locationId)` — already location-specific ✅ |
| `PATCH /me/locations/:locationId` | `server.ts:3888-4215` | Uses `verifyLocationAccess()` — already location-specific ✅ |
| `PATCH /me/locations/:locationId/services` | `server.ts:4218-4287` | Verifies user membership + location access ✅ |
| `PATCH /me/locations/:locationId/agent/voice` | `server.ts:3215-3322` | Uses `verifyLocationAccess()` ✅ |
| `POST /me/locations/:locationId/agent/areas-served` | `server.ts:3338-3431` | Uses `verifyLocationAccess()` ✅ |
| `PATCH /me/locations/:locationId/appointment-duration` | `server.ts:4290-4401` | Uses `verifyLocationAccess()` ✅ |
| `POST /me/flag-spam` | `server.ts:1838-1942` | Scoped by `organizationId` on Caller, no location dependency ✅ |
| `GET /me/integrations` | `server.ts:2857-2998` | Scoped by `organizationId`, integrations are org-level ✅ |
| `POST /me/integrations/:type/activate` | `server.ts:3001-3085` | Scoped by `organizationId` ✅ |
| `GET /me/billing` | `server.ts:1444-1498` | Scoped by `organizationId` ✅ |
| `GET /me/calendar/events` | `server.ts:5412+` | Scoped by `organizationId` ✅ |
| `GET /me/email-preferences` | `server.ts:1665-1697` | User-level, no location dependency ✅ |
| `POST /me/complete-onboarding` | `server.ts:1798-1834` | User-level flag ✅ |

### Category C: Frontend patterns with first-location hardcoding

| Component | File:Line | Pattern | Fix Needed |
|-----------|-----------|---------|------------|
| `DashboardPage` agent fetch | `DashboardPage.tsx:356` | `firstLocation = locationsData?.[0]` | Use selected location from location switcher, default to first |
| `DashboardPage` locations card | `DashboardPage.tsx:1806-1894` | Shows single location card | Show all location cards in a scrollable list |
| `OnboardingPage` complete | `OnboardingPage.tsx:1234` | `firstLocation = locationsData.locations?.[0]` | OK for initial onboarding (always one location at that point) ✅ |
| `PromptManagementPage` | `PromptManagementPage.tsx:55-57` | `data.locations[0].id` as default selected | Already has location selector dropdown, just defaults to first ✅ |
| `LocationsPage` | `LocationsPage.tsx:582+` | Already iterates over all locations | Fully multi-location aware ✅ |

### `verifyLocationAccess()` helper — Already multi-location safe ✅

```typescript
// server.ts:134-149
async function verifyLocationAccess(userId: string, locationId: string) {
  const member = await prisma.organizationMember.findFirst({
    where: { userId },
    include: { organization: { include: { locations: { where: { id: locationId } } } } }
  });
  return member?.organization.locations[0] || null;
}
```

This function correctly verifies that a specific `locationId` belongs to the user's org. The `locations[0]` here is fine because it's filtering by a specific `id`.

---

## Phase 1: Backend — "Add Location" API Endpoint

### 1.1 New API Endpoint: `POST /me/locations/add`

Create a new endpoint that authenticated users can call to add a location to their existing organization.

**Request body:**
```typescript
{
  googlePlaceId: string;         // REQUIRED — from Google Place Autocomplete
  services?: string[];           // Optional — default: copy from first location
  serviceAreas?: string[];       // Optional — default: copy from first location (NOT from Google Place)
  voiceId?: string;              // Optional — default: copy from first location's agent
  voiceProvider?: string;        // Optional — default: copy from first location's agent
  onboardingPath?: string;       // 'keep_your_number' | 'full_auto_pilot' — default: copy from first location
  transferPhoneNumber?: string;  // Required if onboardingPath === 'full_auto_pilot'
  googleCalendarId?: string;     // Optional — which calendar for this location
}
```

**Server-side logic:**

1. **Auth check** — Verify the user is an authenticated member of an organization.
   -  **Deferred:** Role check (owner/admin only). Today all orgs have a single user who is always the owner. When we implement user invites and multi-user orgs, add: `if (member.role !== 'owner' && member.role !== 'admin') return 403`.

2. **Plan limit check** — Query org with plan:
   ```typescript
   const org = await prisma.organization.findUnique({
     where: { id: member.organizationId },
     include: { plan: true, _count: { select: { locations: true } } }
   });
   if (org.plan?.maxLocations && org._count.locations >= org.plan.maxLocations) {
     return 403 "Your plan allows a maximum of N locations."
   }
   ```

3. **Fetch defaults from first location** — Pre-populate services, serviceAreas, voice, and path:
   ```typescript
   const firstLocation = await prisma.location.findFirst({
     where: { organizationId: org.id },
     orderBy: { createdAt: 'asc' },
     include: { agents: { where: { isDefault: true }, take: 1 } }
   });
   const defaults = {
     services: firstLocation.services,
     serviceAreas: firstLocation.serviceAreas,       //  copy from first location
     voiceId: firstLocation.agents[0]?.voiceId,
     voiceProvider: firstLocation.agents[0]?.voiceProvider,
     onboardingPath: firstLocation.onboardingPath,
   };
   ```

4. **Slim location creation flow** — **Do NOT call `createLocationWithFullEnrichment()`** (it runs LLM category enrichment which would overwrite org categories). Instead, cherry-pick the reusable functions:

   a. **Fetch Google Place Details** — Call `fetchGooglePlaceDetails(googlePlaceId)` to get timezone, address, name, phone
   
   b. **Create Location record** — With default intake questions, timezone from Google Place, `serviceAreas: []` (will be set in step 6)
   
   c. **Create default Agent record** — `voiceProvider: 'cartesia'`, `voiceId: 'Ray'`, `isDefault: true`, `backgroundAudioEnabled: true`, `serviceAreas: []` (will be synced in step 6)
   
   d. **Setup system prompt** — Call `setupLocationPrompt({ locationId, organizationId, organizationName, voiceAgentFriendlyName, attioCompanyId, timezone })` — reuses the same S3 business profile as first location
   
   e. **Provision phone number** — Call `provisionPhoneNumber({ locationId, organizationId, organizationName, targetPhoneNumber, city })` — purchases Twilio number + sets up LiveKit SIP

5. **Apply defaults and overrides** — Update the new location + agent with:
   - `services` → request body value OR `firstLocation.services` (skip LLM category enrichment — org already has `callsaverCategories`)
   - `serviceAreas` → request body value OR `firstLocation.serviceAreas` (skip Google Place enrichment — use curated areas from first location)
   - `voiceId` / `voiceProvider` → request body value OR first location's agent values
   - `onboardingPath` → request body value OR `firstLocation.onboardingPath`
   - `transferPhoneNumber` → request body value OR `firstLocation.transferPhoneNumber`
   - `googleCalendarId` → request body value if provided
   - (No need to sync `agent.serviceAreas` — that column is being dropped in this sprint)

6. **Regenerate system prompt** — Call `regenerateAgentPrompt(locationId)` since services/serviceAreas affect the prompt.

7. **Return 201** — `{ success: true, location: { id, name, phoneNumber, services, serviceAreas, voiceId, voiceProvider, onboardingPath } }`

**Why not reuse `createLocationWithFullEnrichment()`?**
- It calls `enrichLocationWithCategories()` which runs LLM classification and writes `callsaverCategories` to the Organization — would overwrite existing curated categories
- It calls `enrichLocationWithServiceAreas()` which derives areas from Google Place county/city — we want to copy from first location instead (better default for multi-location businesses)
- We only need: Google Place fetch, Location/Agent creation, prompt setup, phone provisioning — all available as standalone functions

**File:** `src/server.ts` (new route at `/me/locations/add`)

### 1.2 Existing `GET /me/locations` — Already Multi-Location Ready 

The existing endpoint (`server.ts:2729-2854`) already returns ALL locations with full details including:
- `location.id`, `name`, `serviceAreas`, `services`, `googlePlaceDetails`
- Nested agent (voice, etc.)
- Appointment settings, business profile fields, onboarding path

**No changes needed.** Optionally add per-location call/appointment counts later.

### 1.3 Prisma Migration: New Fields on Location + Remove Dead `agent.serviceAreas`

**Add two columns to Location:**
```prisma
model Location {
  // ... existing fields ...
  googleCalendarId    String?  @map("google_calendar_id")   // Calendar ID for this location's appointments
  externalPlatformId  String?  @map("external_platform_id") // ServiceTitan/Jobber location ID
}
```

**Remove `serviceAreas` from Agent:**
```prisma
model Agent {
  // ... existing fields ...
  // REMOVE: serviceAreas  String[] @default([]) @map("service_areas")
}
```

**Why remove `agent.serviceAreas`?** It's dead weight — never read at runtime:
- System prompt generation (`prompt-setup.ts`) reads `location.serviceAreas`, not `agent.serviceAreas`
- `buildDynamicAssistantConfig()` passes location to prompt generation, never reads `agent.serviceAreas`
- `/internal/agent-config` response does not include `serviceAreas` as a field — it's baked into the system prompt from the Location model
- Python voice agent (`CallSaverAgentConfig`) has no `serviceAreas` property
- Every write to `agent.serviceAreas` is a sync from `location.serviceAreas` — it never holds independent data

**Code changes required (remove ~10 lines of writes):**
- `src/services/provision-execution.ts:496-503` — remove the agent serviceAreas sync after enrichment
- `src/server.ts` `/me/locations/:locationId/agent/areas-served` endpoint — remove the `agent.serviceAreas` update (keep the `location.serviceAreas` update)
- `src/utils.ts:3684` `buildDynamicAssistantConfig()` fallback agent creation — remove `serviceAreas` from the create data

**Migration file:** `prisma/migrations/0XX_multi_location_schema_changes/migration.sql`
```sql
-- Add new Location fields
ALTER TABLE "locations" ADD COLUMN "google_calendar_id" TEXT;
ALTER TABLE "locations" ADD COLUMN "external_platform_id" TEXT;

-- Remove dead agent.serviceAreas column (never read at runtime)
ALTER TABLE "agents" DROP COLUMN "service_areas";
```

### 1.4 Refactor `GET /me/organization` — Remove `take: 1` Constraint

Currently (`server.ts:1290-1344`):
- Queries `locations: { take: 1, orderBy: { createdAt: 'asc' } }` and uses `locations?.[0]` for `state`, `city`, `primaryLocationId`
- `state` defaults to `'CA'` if not found

**Phase 1 change (tonight):** Remove `take: 1` so the query fetches all locations. Keep using `locations[0]` for `state`/`city`/`primaryLocationId` for backward compatibility. This is a 1-line change with zero frontend breakage — response shape stays identical.

**Phase 2 frontend work (later):** Refactor `OnboardingPage` and `LocationsPage` to read state from the location's `googlePlaceDetails.addressComponents` (`administrative_area_level_1` → `shortText`) instead of from the org response. This enables per-location service area autocomplete (e.g., TX cities for TX locations). Once the frontend is refactored, we can optionally remove `state`/`city` from the org response entirely (breaking change, requires coordinated deploy).

### 1.5 Deprecate `GET /me/agent/phone-number` — Unused Endpoint

Currently (`server.ts:5320-5409`):
- Hardcodes `take: 1` on locations and uses `locations[0]`
- Path is semantically wrong: `/agent/` is singular but there's one agent per location
- Phone numbers belong to locations (`TwilioPhoneNumber.locationId`, `LivekitPhoneNumber.locationId`), not agents

**Finding:** This endpoint is **not called by the frontend**. Phone numbers are accessed through:
- `GET /me/locations` — returns all locations with nested phone data
- `GET /me/locations/:locationId/agent` — returns agent config including `phoneNumber` + `phoneNumbers[]`

**Action:** Add a deprecation comment to the endpoint. No refactoring needed. Consider removing in a future cleanup sprint.

### 1.6 Add `locationId` Filter to `GET /me/calls`

The endpoint already returns `locationId` and `locationName` per call. To support frontend filtering:
- Add optional `?locationId=` query parameter
- If provided: add `locationId` to the where clause
- This enables the frontend location switcher to filter calls by location

Similarly for `GET /me/stats` — add optional `?locationId=` to return stats for a specific location vs. all.

---

## Phase 2: Frontend — "Add Location" Flow

### 2.1 "Add Location" Button Placement

Add an "Add Location" button in two places:
- **Dashboard "Locations" section** (right side panel, `DashboardPage.tsx:1806`) — below the existing location card(s)
- **LocationsPage** (`LocationsPage.tsx`) — at the top of the locations list

The button should be gated by:
- `Plan.maxLocations` — disabled with tooltip if at limit ("Upgrade your plan to add more locations")
- ⚠️ **Deferred:** Role check (owner/admin only) — not needed until multi-user orgs are implemented

### 2.2 Google Place Autocomplete Search Modal

When "Add Location" is clicked, show a modal dialog:

**Step 1: Find Your Location**
- Google Places Autocomplete input field
- User types business name / address
- Dropdown shows matching places
- On select → store `googlePlaceId` + display preview (name, address, phone, rating)
- "Next" button

**Implementation:**
- Use `@react-google-maps/api` or Google Maps JavaScript API `Autocomplete` widget
- Restrict to US businesses (`componentRestrictions: { country: 'us' }`)
- Types filter: `['establishment']`
- Need `GOOGLE_MAPS_API_KEY` exposed to frontend (public key, no server secret)

### 2.3 Location Setup Wizard (Reuse Onboarding Steps)

After selecting a Google Place, show a mini-wizard. All steps are pre-populated from the first location's settings:

**Step 2: Services** — Pre-populated from first location's services (editable)
- Reuse `ServicesStep` component from `OnboardingPage.tsx`

**Step 3: Service Areas** — Pre-populated from first location's serviceAreas (editable)
- Reuse `SelectPills` with city/county data
- User can add/remove areas for the new location's geography
- **Per-location state for autocomplete:** Extract state from the new location's `googlePlaceDetails.addressComponents` (`administrative_area_level_1` → `shortText` gives abbreviation e.g. `"CA"`). Call `loadCitiesForState()` with that state code so the autocomplete shows cities for the correct state (e.g. TX cities for a TX location, not the org's first location state). Timezone is derived from zip code via `getTimezoneFromZipCode()` (avoids Place Details Pro SKU `timeZone` field). Both state and timezone are already extracted per-location during provisioning — frontend just needs to read from the location's `googlePlaceDetails` instead of the org response.

**Step 4: Choose Voice** — Pre-populated from first location's voice (editable)
- Reuse voice selection UI from onboarding step 4

**Step 5: Choose Setup Path** — Pre-populated from first location's onboardingPath
- Reuse path selection UI from onboarding step 6
- keep_your_number vs full_auto_pilot

**Step 6: Call Forwarding / Transfer** — If applicable (full_auto_pilot selected)
- Reuse step 7 UI

**Step 7: Confirm & Provision**
- Show summary: location name, address, selected voice, services, service areas
- "Add Location" button → calls `POST /me/locations/add`
- Loading state while provisioning (Twilio + LiveKit can take a few seconds)
- Success → redirect to dashboard with new location visible

**Component:** `src/components/add-location-wizard.tsx` (new file, imports from onboarding)

### 2.4 Extract Shared Onboarding Components

Refactor `OnboardingPage.tsx` to extract reusable step components:
- `ServicesStep` — already extracted as a memoized component ✅
- `ServiceAreasStep` — extract the city/county selection UI
- `VoiceSelectionStep` — extract the voice carousel/picker
- `PathSelectionStep` — extract keep_your_number vs full_auto_pilot
- `CallForwardingStep` — extract carrier instructions

These become shared between `OnboardingPage` and `AddLocationWizard`.

---

## Phase 3: Location Context in UI

### 3.1 Location Switcher / Filter

**If org has multiple locations, add a location filter:**
- **Dashboard:** Location dropdown/tabs above "Recent Calls" — filter calls by location
- **Callers page:** Location filter in the header

**Implementation:**
- Global state (React context or zustand): `selectedLocationId: string | 'all'` (default: `'all'`)
- `LocationSelector` component: dropdown showing all locations by name + short address
- Pass `locationId` query param to API calls (`GET /me/calls?locationId=xxx`)
- Backend changes: add optional `locationId` filter to `/me/calls` and `/me/stats` (Phase 1.6)

### 3.2 Location Badge on Cards

When the org has 2+ locations, show a location badge on:

- **Call cards** (Recent Calls on dashboard + Callers history) — small badge/tag showing location name
  - Data already available: `/me/calls` already returns `locationId` + `locationName` per call ✅
  
- **Caller list** — badge showing which location the caller is associated with
  - Data already available: `/me/callers` already returns `locationId` + `locationName` per caller ✅

**Conditional rendering:** Only show badges when `locations.length > 1` to avoid clutter for single-location orgs.

### 3.3 Dashboard "Locations" Section Enhancement

Currently (`DashboardPage.tsx:1806-1894`):
- Shows a single location card using `agent` state (which is always `locationsData?.[0]`)

For multi-location:
- Fetch all locations from `/me/locations` (already returns all)
- Show a card for each location (scrollable list)
- Each card shows: name, address, phone, open/closed status, rating
- "Add Location" button at the bottom
- Click on a location → could set it as the active filter for the dashboard

---

## Phase 4: Integration Handling for Multi-Location

### 4.1 Integrations Are Org-Level (Reused Across Locations)

**Google Calendar:** ✅ Reuse same OAuth connection
- One `NangoConnection` per org/user for `google-calendar`
- Different `calendarId` per location (new `Location.googleCalendarId` field)
- Voice agent reads `location.googleCalendarId` when creating events
- Settings page: per-location calendar picker (list calendars from the connected Google account)

**Jobber:** ✅ Reuse same connection
- Single-company tool — no location concept needed

**Square Bookings:** ✅ Reuse same connection
- Multi-location support built into Square

**Summary:** No need to create new integration connections per location. The org-level connection works for all. Just need location-specific config (like `calendarId`) stored on the `Location` model.

---

## Phase 5: Voice Agent Awareness

### 5.1 Agent Gets Location Context — Already Working ✅

The Python voice agent already receives the `locationId` when a call comes in (via LiveKit dispatch rules that map phone numbers → locations). Each location has its own:
- `Agent` record (voice, system prompt, service areas)
- `TwilioPhoneNumber` (unique inbound number)
- `LivekitPhoneNumber` + `LivekitAgent` (SIP routing)

**No changes needed in the voice agent for multi-location** — it already operates per-location. Each location's phone number routes to the correct agent config.

### 5.2 Calendar Event Creation — Include Location

When the voice agent creates a Google Calendar event, include the location name in:
- Event title: `"{Service} - {Location Name}"` (only if multi-location org)
- Event location field: Use the location's Google Place address
- Event description: Include location context

**File to modify:** `livekit-python/tools/google_calendar_create_event.py`

### 5.3 Per-Location Calendar ID

When the voice agent creates a calendar event, it should use `location.googleCalendarId` instead of always using `'primary'`. If `googleCalendarId` is null, fall back to `'primary'`.

---

## Phase 6: Billing & Plan Enforcement

### 6.1 `Plan.maxLocations` Enforcement

The `Plan` model already has `maxLocations Int?`:
- `null` = unlimited locations
- `1` = single location (basic plan)
- `3`, `5`, etc. = tiered plans

**Enforce in:**
- `POST /me/locations/add` — reject if at limit (Phase 1.1, step 2)
- Frontend "Add Location" button — disable if at limit, show upgrade CTA

### 6.2 Per-Location Billing (Future)

Currently billing is per-org (subscription + usage). For multi-location:
- **Option A (simple):** Flat fee per additional location (Stripe subscription item)
- **Option B (metered):** Usage metering per location (already have `CallRecord.locationId` + `CallRecord.billableMinutes`)

**Defer detailed billing changes** — for now, just enforce `maxLocations` on the plan.

---

## Phase 7: User Invites & Role-Based Auth (Deferred)

> **This phase is NOT part of the multi-location MVP.** It is noted here for completeness because role-based auth was originally planned for the add-location endpoint.

### Current State
- `OrganizationMember.role` is `String @default("member")` — values `'owner'` and `'member'` exist
- Provisioning creates the first user as `'owner'` (`provision-execution.ts:251`)
- `provisionUserForExistingOrg()` creates subsequent users as `'member'` (`provision.ts:313`)
- **No endpoints check roles today** — all `/me/*` routes just verify org membership

### When Implemented
- Add `POST /me/organization/invite` — owner sends email invite to a new user
- Add `PATCH /me/organization/members/:userId/role` — owner can change roles
- Add role-check middleware: `requireRole('owner', 'admin')` 
- Gate add-location, billing, and integration management endpoints with role checks
- Gate dangerous operations: delete location, cancel subscription, etc.

---

## Implementation Order

| Priority | Task | Effort | Dependencies |
|----------|------|--------|--------------|
| **P0** | Prisma migration: add `googleCalendarId` + `externalPlatformId` on Location, drop `serviceAreas` from Agent | S | None |
| **P0** | Remove `agent.serviceAreas` writes from provisioning, areas-served endpoint, and fallback agent creation | S | Migration |
| **P0** | `POST /me/locations/add` endpoint (slim flow: cherry-picks `fetchGooglePlaceDetails`, `setupLocationPrompt`, `provisionPhoneNumber` — skips LLM enrichment) | M | Migration |
| **P0** | Plan limit enforcement in add-location endpoint | S | Endpoint |
| **P0** | Refactor `GET /me/organization` to remove first-location dependency | S | None |
| **P0** | Add optional `locationId` filter to `GET /me/calls` and `GET /me/stats` | S | None |
| **P0** | Deprecate `GET /me/agent/phone-number` (unused by frontend, semantically wrong path) | S | None |
| **P1** | Google Place Autocomplete integration (frontend) | M | Google Maps API key |
| **P1** | Extract shared onboarding step components | M | None |
| **P1** | Add Location Wizard modal (frontend) | L | Autocomplete + extracted components |
| **P2** | Location switcher/filter component (frontend) | M | `locationId` filter on API |
| **P2** | Location badges on call/appointment cards | S | API includes location name (already does) |
| **P2** | Dashboard multi-location card list | S | Location switcher |
| **P2** | Per-location Google Calendar ID picker in settings | M | `googleCalendarId` field |
| **P3** | Voice agent: location name in calendar events | S | `googleCalendarId` |
| **P3** | Voice agent: per-location calendar ID | S | `googleCalendarId` |
| **P3** | Per-location billing (Stripe subscription items) | L | Product/pricing decision |
| **Deferred** | User invites & role-based auth (Phase 7) | L | Multi-user org design |

**Estimated total (P0-P2):** ~2-3 weeks of focused work

---

## Key Design Decisions

1. **Integrations stay org-level** — no duplicate OAuth flows per location. Just store location-specific config (calendar ID, platform location ID) on the `Location` model.

2. **Slim flow, NOT `createLocationWithFullEnrichment()`** — the full provisioning function runs LLM category enrichment (would overwrite org's curated categories) and Google Place service area derivation (we want to copy from first location instead). The add-location endpoint cherry-picks the reusable functions: `fetchGooglePlaceDetails()`, `setupLocationPrompt()`, `provisionPhoneNumber()`.

3. **Caller model stays org-scoped** — a caller who calls both locations should be the same `Caller` record (they already have `@@unique([phoneNumber, organizationId])`). The `CallRecord` tracks which location was called.

4. **Location badges are conditional** — only show when `locations.length > 1` to keep UI clean for majority single-location customers.

5. **Google Place Autocomplete for discovery** — rather than manually entering address/phone, leverage Google Places to get structured data, same as the initial provisioning flow uses.

6. **Service areas pre-populated from first location** — rather than only using Google Place enrichment for the new location's county/city, we default to the first location's curated service areas. The user can edit these in the wizard. This is a better default because multi-location businesses typically serve overlapping areas.

7. **Role-based auth deferred** — since user invites aren't implemented and every org currently has exactly one user (the owner), adding role enforcement to the add-location endpoint is premature. We note where it should be added in Phase 7.

8. **Most endpoints are already multi-location safe** — the audit shows that location-specific endpoints (settings, voice, services, areas-served) already use `verifyLocationAccess()` with a `locationId` param. The calls/callers endpoints already return `locationId` per record. Only a handful of endpoints need fixing (organization). The `/me/agent/phone-number` endpoint is unused by the frontend and will be deprecated.

9. **Remove `agent.serviceAreas` duplication** — both `Agent` and `Location` had `serviceAreas String[]` fields, but the Agent copy is never read at runtime. System prompt generation, `buildDynamicAssistantConfig()`, `/internal/agent-config`, and the Python voice agent all read from `location.serviceAreas`. The Agent field was written to during provisioning and the areas-served endpoint purely as a sync — it never held independent data. Dropping it eliminates a false obligation to keep two fields in sync.
