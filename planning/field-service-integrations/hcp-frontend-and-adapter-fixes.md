# Housecall Pro: Frontend & Adapter Fixes Plan

**Created:** 2026-02-24  
**Updated:** 2026-02-24 (v2 — with user feedback + deeper research)  
**Status:** Ready for Implementation

---

## Table of Contents

1. [Lead Address Bug](#1-lead-address-bug)
2. [Unscheduled vs Scheduled Mode (Lead-only vs Estimate Conversion)](#2-unscheduled-vs-scheduled-mode)
3. [Frontend Sidebar & Page Structure](#3-frontend-sidebar--page-structure)
4. [Invalid Date Bug on Service Requests Page](#4-invalid-date-bug)
5. [External URI Links for HCP Leads/Estimates/Customers](#5-external-uri-links)
6. [Tool Call Name Mapping (HCP Nomenclature)](#6-tool-call-name-mapping)
7. [Tool Call Logos by Integration](#7-tool-call-logos)
8. [Transcript Height Limiting](#8-transcript-height-limiting)
9. [Multiple Addresses (HCP ↔ CallerAddresses)](#9-multiple-addresses)
10. [React-Joyride Tour Architecture](#10-react-joyride-tour-architecture)

---

## 1. Lead Address Bug

### Problem
Leads created in HCP do not have addresses on them, even though the linked customer has addresses on file. The **estimate** gets the address fine — it's the **lead** that is missing it.

### Root Cause (Confirmed via Code Review + API Docs)

**API Docs confirm:** POST `/leads` accepts **both** `address_id` (link existing customer address) AND inline `address` object (create new address). So the API does support inline addresses.

In `HousecallProAdapter.submitLead()` (lines 327-342):

```typescript
let property: Property | null = null;
if (data.address?.street) {
  const existing = await this.listProperties(context, customer.id);
  const match = existing.find(p => ...);
  property = match || await this.createProperty(context, { customerId: customer.id, address: data.address });
}

const serviceRequest = await this.createServiceRequest(context, {
  customerId: customer.id, ..., address: data.address,
  // ❌ BUG: property.id is NEVER passed as propertyId!
});
```

The property (HCP customer address) is created/found in step 2, but **its ID is never forwarded** to `createServiceRequest()`. So in `createServiceRequest()`:
- `data.propertyId` is `undefined` → the `address_id` branch is skipped.
- Falls through to inline `address` branch: `body.address = { street, city, state, zip }`.

**Two likely failure modes:**
1. The inline `address` creates a **standalone address** not linked to the customer record, while `address_id` properly links to the customer's existing address. HCP may display addresses differently depending on which method was used.
2. The inline address mapping uses `zip: data.address.zipCode || ''`. If the incoming `data.address` has a `zip` field instead of `zipCode`, the zip is sent as empty string, potentially causing HCP to discard the address silently.

**Why the estimate gets the address:** The auto-convert to estimate may inherit the customer's addresses, or the scheduling step explicitly links it via `address_id`.

### Proposed Fix

In `submitLead()`, pass `propertyId: property?.id` to `createServiceRequest()`:

```typescript
const serviceRequest = await this.createServiceRequest(context, {
  customerId: customer.id,
  description: data.serviceDescription,
  serviceType: data.serviceDescription,
  priority: data.priority || 'normal',
  address: data.address,
  propertyId: property?.id,     // ← FIX: use address_id (links to customer's existing address)
  // ... other fields
} as any);
```

This ensures `createServiceRequest` uses `body.address_id = data.propertyId` (line 240), which links the lead to the customer's existing address rather than creating a disconnected inline address. This is the more reliable approach per HCP API best practices.

### Files to Change
- `callsaver-api/src/adapters/field-service/platforms/housecallpro/HousecallProAdapter.ts` — `submitLead()` method (1-line fix)

---

## 2. Unscheduled vs Scheduled Mode

### Problem
Currently, when `autoScheduleAssessment: false`, the agent still creates a lead AND auto-converts it to an estimate. This is inconsistent with HCP's natural workflow where leads represent unqualified/unscheduled work and estimates represent qualified work that may be scheduled.

### Agreed Architecture

**When `autoScheduleAssessment: false` (Unscheduled Mode):**
- Agent creates a **lead only** — no auto-conversion to estimate.
- Agent collects caller's preferred time and includes it in the lead note (e.g., "Preferred time: Tuesday morning").
- Agent tells the caller: "I've created a lead for you. A member of the team will follow up to arrange scheduling."
- The lead stays as a lead in HCP. The business owner manually converts and schedules it.

**When `autoScheduleAssessment: true` (Scheduled Mode):**
- Agent creates a lead, auto-converts to estimate, and schedules it (current behavior).
- Agent confirms the scheduled time with the caller.

### Implementation

#### Backend Changes (`HousecallProAdapter.ts`)
- In `createServiceRequest()`, check if `autoScheduleAssessment` is enabled before auto-converting:
  - Option A: Pass `autoScheduleAssessment` flag through `CreateServiceRequestInput` (add to type).
  - Option B: Pass it through `context` (CallerContext could carry agent config).
  - **Recommendation:** Option B — add `agentConfig` to CallerContext. The route handler already has access to location settings.

```typescript
// In createServiceRequest:
const shouldConvert = (context as any).agentConfig?.autoScheduleAssessment !== false;
if (shouldConvert) {
  // Auto-convert lead → estimate (existing code)
}
// If not converting, just return the lead as-is
```

#### Backend Changes (`field-service-tools.ts`)
- In the `create-service-request` route handler, pass `autoScheduleAssessment` from the agent's config into the context.
- Update the response message:
  - Scheduled mode: "Service request created. Estimate ID: {id}. Proceed to schedule."
  - Unscheduled mode: "Lead created successfully. The team will follow up to arrange scheduling."

#### System Prompt Changes (`server.ts`)
- When `autoScheduleAssessment: false` for HCP:
  - Remove instructions about scheduling estimates.
  - Add: "After creating a service request, inform the caller that a team member will follow up to arrange scheduling. Do NOT attempt to check availability or schedule."
  - Still collect preferred time and include in the lead note.

### Files to Change
- `callsaver-api/src/adapters/field-service/platforms/housecallpro/HousecallProAdapter.ts`
- `callsaver-api/src/routes/field-service-tools.ts`
- `callsaver-api/src/server.ts` (fsInstructions for HCP)
- `callsaver-api/src/types/field-service.ts` (CallerContext or CreateServiceRequestInput)

---

## 3. Frontend Sidebar & Page Structure

### Problem
With the lead-only unscheduled mode (Issue #2), we'll have a mix of leads (unscheduled) and estimates (scheduled). How should the frontend represent this?

### Agreed Approach: Single Page with Tabs

**Sidebar item:** "Work Pipeline" (or "Leads & Estimates")
- Icon: Wrench (existing)
- URL: `/service-requests` (existing route)

**Tabs on the page:**

| Tab | Content | When Shown |
|-----|---------|------------|
| All | All leads + estimates combined, newest first | Always |
| Leads | Unconverted leads only (unscheduled) | Always |
| Estimates | Converted estimates (scheduled/unscheduled) | Always |

**Why single page is better than two pages:**
- Simpler navigation — one click, not two.
- HCP's own UI uses a single pipeline view.
- Avoids confusing users about where to find things.
- Future-proof: if we add more entity types (jobs, invoices), they become tabs, not new pages.

### Sidebar Labels

| Integration | Sidebar Label | Rationale |
|---|---|---|
| Jobber | Service Requests | Matches Jobber terminology |
| HCP (any mode) | **Work Pipeline** | Platform-agnostic, covers leads + estimates |
| No integration | Hidden | No data to show |

### Implementation

#### `app-sidebar.tsx`
```typescript
if (item.title === 'Appointments' && integrationType === 'housecall-pro') {
  return { ...rest, title: 'Work Pipeline', url: '/service-requests', icon: Wrench };
}
```

#### `ServiceRequestsPage.tsx`
- For HCP: Show "All" / "Leads" / "Estimates" tabs (instead of "Scheduled" / "Unscheduled").
- Each item gets an `entityType: 'lead' | 'estimate'` field from the backend to enable filtering.

#### Backend `GET /me/service-requests` changes
- For HCP: Fetch **both leads AND estimates** (currently only fetches leads).
- Add `entityType: 'lead' | 'estimate'` field to each returned item.
- Estimates fetched via `GET /estimates` endpoint filtered by `lead_source=CallSaver` (or however attribution works for estimates).

### Files to Change
- `callsaver-frontend/src/components/layout/app-sidebar.tsx`
- `callsaver-frontend/src/pages/ServiceRequestsPage.tsx`
- `callsaver-frontend/src/hooks/use-service-requests.ts` (add entityType)
- `callsaver-api/src/server.ts` (`GET /me/service-requests` HCP branch)

---

## 4. Invalid Date Bug

### Problem
The ServiceRequestsPage shows "Invalid date" in the card for each HCP lead.

### Root Cause (Confirmed via API Spec)

The HCP **Leads API** (`GET /leads`) response does **NOT include `created_at` or `updated_at` fields**. The lead response schema contains only: `id`, `number`, `customer`, `address`, `lead_source`, `tags`, `assigned_employee`, `status`, `pipeline_status`, `company_name`, `company_id`.

In `server.ts` line 3696:
```typescript
createdAt: lead.created_at,  // ← Always undefined! Leads have no created_at
```

`new Date(undefined)` → `"Invalid Date"`.

Meanwhile, the HCP **Estimates API** (`GET /estimates`) DOES include rich date fields:
- `created_at` / `updated_at`
- `schedule.scheduled_start` / `schedule.scheduled_end`
- `work_timestamps.on_my_way_at` / `started_at` / `completed_at`

### Proposed Fix

#### Backend (`server.ts` — HCP `GET /me/service-requests`)
Since leads have no date from the API, we must handle this gracefully:

```typescript
// For leads: no created_at from API, use current time as fallback
createdAt: lead.created_at || null,
updatedAt: lead.updated_at || null,
```

#### Frontend (`ServiceRequestsPage.tsx`)
Guard against null/undefined dates in `formatDate`:
```typescript
const formatDate = (dateString: string): string => {
  if (!dateString) return '';
  try {
    const date = new Date(dateString);
    if (isNaN(date.getTime())) return '';
    // ... existing formatting
  } catch { return ''; }
};
```

Also, the card should gracefully hide the date row when no valid date exists, or show "Date unavailable" instead of "Invalid date".

#### Future improvement
When the backend fetches both leads and estimates (Issue #3), estimates will have proper dates. Only leads will lack dates. Consider storing `createdAt` locally in a `call_records` association when the lead is created via the agent — we already sync `externalRequestId` to CallRecord, so we could use `callRecord.createdAt` as the lead's creation date.

### Files to Change
- `callsaver-api/src/server.ts` (HCP branch of `GET /me/service-requests`)
- `callsaver-frontend/src/pages/ServiceRequestsPage.tsx` (formatDate guard + card rendering)

---

## 5. External URI Links for HCP Leads/Estimates/Customers

### Problem
Multiple issues:
1. `externalWebUri` is hardcoded to `null` in `GET /me/service-requests` HCP branch (lines 3695, 3703).
2. `buildExternalRequestUrl()` uses wrong URL pattern: `https://pro.housecallpro.com/pro/jobs/{id}`.
3. `mapCustomer()` in HousecallProAdapter doesn't set `hcpWebUri` in metadata, so `externalCustomerUrl` is never saved for HCP customers.
4. CallerDetailPage hardcodes "View in Jobber" (line 467) instead of being integration-aware.

### Correct HCP Dashboard URL Patterns (User-provided)

| Entity | URL Pattern | Example |
|---|---|---|
| Customer | `https://pro.housecallpro.com/app/customers/{id}` | `/app/customers/cus_d2924ed89dd64c9d9cff8f63eb22fe01` |
| Lead | `https://pro.housecallpro.com/app/leads/{id}` | `/app/leads/lea_47ead319e06f4acf86d16f50fb9497be` |
| Estimate | `https://pro.housecallpro.com/app/estimates/{id}` | `/app/estimates/best_6f4b90ba22b14bf2bf362df50a2ae675` |

**Note:** The correct base path is `/app/` not `/pro/`. The IDs have type prefixes: `cus_`, `lea_`, `best_`.

### Proposed Fixes

#### A. Fix `buildExternalRequestUrl()` in `field-service-tools.ts`
Currently uses wrong URL. Need entity-type awareness:

```typescript
function buildExternalRequestUrl(platform: string, requestId: string, entityType?: string): string | undefined {
  if (platform === 'jobber') {
    try {
      const decoded = Buffer.from(requestId, 'base64').toString('utf-8');
      const numericId = decoded.split('/').pop();
      if (numericId) return `https://secure.getjobber.com/requests/${numericId}`;
    } catch {}
    return undefined;
  }
  if (platform === 'housecallpro') {
    if (entityType === 'estimate') {
      return `https://pro.housecallpro.com/app/estimates/${requestId}`;
    }
    return `https://pro.housecallpro.com/app/leads/${requestId}`;
  }
  return undefined;
}
```

#### B. Add `hcpWebUri` to `mapCustomer()` in HousecallProAdapter
```typescript
metadata: {
  source: 'housecallpro',
  hcpWebUri: `https://pro.housecallpro.com/app/customers/${h.id}`,
  // ... existing fields
},
```

This enables the `externalCustomerUrl` sync in `field-service-tools.ts` (line 232) which already checks `customer.metadata?.hcpWebUri`.

#### C. Fix `GET /me/service-requests` in `server.ts`
```typescript
// Lead:
externalWebUri: `https://pro.housecallpro.com/app/leads/${lead.id}`,
customer: {
  externalWebUri: customer.id ? `https://pro.housecallpro.com/app/customers/${customer.id}` : null,
},

// Estimate (when added per Issue #3):
externalWebUri: `https://pro.housecallpro.com/app/estimates/${estimate.id}`,
```

#### D. Fix CallerDetailPage "View in Jobber" → dynamic
```tsx
// line 467, currently:
View in Jobber
// change to:
View in {caller.externalPlatform === 'housecallpro' ? 'Housecall Pro' : 'Jobber'}
```

Or better: use the `connectedIntegration` hook to determine the label.

### Files to Change
- `callsaver-api/src/routes/field-service-tools.ts` (`buildExternalRequestUrl`)
- `callsaver-api/src/adapters/field-service/platforms/housecallpro/HousecallProAdapter.ts` (`mapCustomer`)
- `callsaver-api/src/server.ts` (`GET /me/service-requests`)
- `callsaver-frontend/src/pages/CallerDetailPage.tsx` (dynamic "View in" label)

---

## 6. Tool Call Name Mapping (HCP Nomenclature)

### Problem
Tool call function names like `fs_create_service_request`, `fs_create_assessment`, `fs_get_jobs` are adapter-internal names. When displayed in the frontend under "Show Tool Calls", they should use HCP-familiar terminology.

### Key Insight: Mode-Aware Display Names
Given the unscheduled/scheduled mode split (Issue #2), the display names should reflect what actually happened:
- **Unscheduled mode** (`autoScheduleAssessment: false`): `fs_create_service_request` → "Create Lead" (no estimate was created)
- **Scheduled mode** (`autoScheduleAssessment: true`): `fs_create_service_request` → "Create Lead & Estimate" (both created)
- `fs_create_assessment` → "Create Estimate" (manual conversion, or "Schedule Estimate" if scheduling happened)

The mode can be inferred from the tool call output content (e.g., if the output mentions "estimate" or contains an estimate ID, it was scheduled mode).

### Proposed Mapping

| Internal Tool Name | Jobber Display Name | HCP Display Name |
|---|---|---|
| `fs_find_customer` | Find Customer | Find Customer |
| `fs_create_customer` | Create Customer | Create Customer |
| `fs_create_property` | Create Property | Add Address |
| `fs_create_service_request` | Create Service Request | Create Lead *(or "Create Lead & Estimate" if output contains estimateId)* |
| `fs_create_assessment` | Create Assessment | Create Estimate |
| `fs_reschedule_assessment` | Schedule Assessment | Schedule Estimate |
| `fs_check_availability` | Check Availability | Check Availability |
| `fs_get_jobs` | Get Jobs | Get Jobs |
| `fs_get_appointments` | Get Appointments | Get Appointments |
| `fs_get_requests` | Get Requests | Get Leads |
| `fs_get_client_schedule` | Get Client Schedule | Get Client Schedule |
| `fs_submit_lead` | Submit Lead | Submit Lead *(or "Submit Lead & Estimate" if output contains estimateId)* |
| `fs_check_service_area` | Check Service Area | Check Service Zone |
| `fs_get_company_info` | Get Company Info | Get Company Info |
| `fs_get_services` | Get Services | Get Price Book |

### Implementation

Add `getToolDisplayName(functionName, integration, toolCallOutput?)` to `tool-call-formatters.tsx`:

```typescript
const HCP_TOOL_NAMES: Record<string, string> = {
  'fs_create_service_request': 'Create Lead',
  'fs_create_assessment': 'Create Estimate',
  'fs_reschedule_assessment': 'Schedule Estimate',
  'fs_create_property': 'Add Address',
  'fs_get_requests': 'Get Leads',
  'fs_check_service_area': 'Check Service Zone',
  'fs_get_services': 'Get Price Book',
  'fs_submit_lead': 'Submit Lead',
};

const JOBBER_TOOL_NAMES: Record<string, string> = {
  'fs_create_service_request': 'Create Service Request',
  'fs_create_assessment': 'Create Assessment',
  'fs_reschedule_assessment': 'Schedule Assessment',
};

export function getToolDisplayName(
  functionName: string,
  integration?: string,
  output?: string,
): string {
  const map = integration === 'housecall-pro' ? HCP_TOOL_NAMES
            : integration === 'jobber' ? JOBBER_TOOL_NAMES
            : {};
  let name = map[functionName];

  // For HCP: detect if lead was also converted to estimate (scheduled mode)
  if (integration === 'housecall-pro' && output) {
    const hasEstimate = output.includes('estimate') || output.includes('Estimate');
    if (functionName === 'fs_create_service_request' && hasEstimate) {
      name = 'Create Lead & Estimate';
    }
    if (functionName === 'fs_submit_lead' && hasEstimate) {
      name = 'Submit Lead & Estimate';
    }
  }

  return name || functionName
    .replace(/^fs_/, '')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase());
}
```

The rendering components in DashboardPage, CallerDetailPage, and CallRecordDetailPage would call `getToolDisplayName(toolCall.functionName, connectedIntegration?.type, toolCall.content)`.

### Files to Change
- `callsaver-frontend/src/lib/tool-call-formatters.tsx` (add mapping)
- `callsaver-frontend/src/pages/DashboardPage.tsx` (use display name)
- `callsaver-frontend/src/pages/CallerDetailPage.tsx` (use display name)
- `callsaver-frontend/src/pages/CallRecordDetailPage.tsx` (use display name)

---

## 7. Tool Call Logos

### Problem
Tool calls should show platform logos for visual identification. Currently only Google Calendar tools show a Google Calendar icon.

### Available Assets
Already in `/public/images/` and `/public/`:
- `housecall-pro.png` — HCP logo
- `jobber.png` — Jobber logo
- `google-calendar.png` — Google Calendar icon (already used)
- `google-map-icon.png` — Google Maps icon (for validate_address)
- `android-chrome-512x512.png` — CallSaver icon (for internal tools)

### Logo Assignment Rules

```typescript
export function getToolLogo(functionName: string, integration?: string): string | null {
  // Google Calendar tools
  if (isGoogleCalendarTool(functionName)) return '/images/google-calendar.png';

  // Address validation → Google Maps
  if (isValidateAddressTool(functionName)) return '/images/google-map-icon.png';

  // Field service tools (fs_ prefix) → integration logo
  if (functionName.startsWith('fs_') || functionName.startsWith('fs-')) {
    if (integration === 'housecall-pro') return '/images/housecall-pro.png';
    if (integration === 'jobber') return '/images/jobber.png';
  }

  // Internal CallSaver tools (submit_intake_answer, transfer, etc.)
  return '/android-chrome-512x512.png';
}
```

### Rendering
In the tool call card/badge, show a small (16x16 or 20x20) logo image next to the tool name:

```tsx
const logo = getToolLogo(toolCall.functionName, integration);
return (
  <div className="flex items-center gap-1.5">
    {logo && <img src={logo} alt="" className="h-4 w-4 rounded-sm" />}
    <span>{getToolDisplayName(toolCall.functionName, integration, toolCall.content)}</span>
  </div>
);
```

### Files to Change
- `callsaver-frontend/src/lib/tool-call-formatters.tsx` (add `getToolLogo`)
- `callsaver-frontend/src/pages/DashboardPage.tsx` (render logo)
- `callsaver-frontend/src/pages/CallerDetailPage.tsx` (render logo)
- `callsaver-frontend/src/pages/CallRecordDetailPage.tsx` (render logo)

---

## 8. Transcript Height Limiting

### Problem
When "Show Transcript" is expanded, the transcript can be extremely long and extends the card to limitless height.

### Current Implementation
In `DashboardPage.tsx` (lines 1069-1096), the transcript is rendered inside a `<CollapsibleContent>` with a `<Conversation>` component. There's no height constraint.

### Proposed Fix
Add `max-height` and `overflow-y: auto` to the transcript container:

```tsx
<CollapsibleContent className="mt-2">
  <div className="bg-gray-50 rounded-lg border max-h-[400px] overflow-y-auto">
    <Conversation>
      {/* ... messages ... */}
    </Conversation>
  </div>
</CollapsibleContent>
```

The `max-h-[400px]` (approximately 25 lines of chat) is a good default. Could also use `max-h-[50vh]` for viewport-relative sizing.

This fix should be applied everywhere transcripts are rendered:
- `DashboardPage.tsx` — mobile collapsible transcript (line 1069)
- `DashboardPage.tsx` — desktop tab transcript (line 1003)
- `CallerDetailPage.tsx` — if transcripts are shown there
- `CallRecordDetailPage.tsx` — if transcripts are shown there

### Files to Change
- `callsaver-frontend/src/pages/DashboardPage.tsx`
- `callsaver-frontend/src/pages/CallerDetailPage.tsx` (if applicable)
- `callsaver-frontend/src/pages/CallRecordDetailPage.tsx` (if applicable)

---

## 9. Multiple Addresses (HCP ↔ CallerAddresses)

### Current State

**CallerAddress model** (Prisma):
- `id`, `callerId`, `label`, `address` (full string), `city`, `state`, `zipCode`, `isPrimary`
- Unique constraint: `[callerId, address]`
- One caller can have many addresses

**HCP Customer Addresses** (API):
- `GET /customers/{id}/addresses` — returns paginated list
- `POST /customers/{id}/addresses` — create new address
- Each address has: `id`, `type` (billing/service), `street`, `street_line_2`, `city`, `state`, `zip`, `country`

**Current sync:** In `field-service-tools.ts` line 327-367, when `create-property` is called, the address is synced to `CallerAddress` via upsert. This already works for both Jobber properties and HCP addresses.

**HCP Adapter:** `listProperties()` calls `GET /customers/{id}/addresses` and maps them. `createProperty()` calls `POST /customers/{id}/addresses`. Both work correctly.

### Gap Analysis
The current implementation **already supports multiple addresses** for HCP. The sync path is:
1. Voice agent calls `create-property` → HCP address created + CallerAddress upserted.
2. Voice agent calls `list-properties` → returns all HCP addresses for the customer.

**Missing pieces:**
- **Reverse sync:** If addresses are added directly in HCP dashboard (not via CallSaver), they won't appear in CallerAddresses. This is acceptable for now — CallerAddresses are a local cache, not a source of truth.
- **Submit-lead flow:** `submitLead()` already calls `listProperties()` and `createProperty()` when an address is provided, so this works.
- **Frontend CallerDetailPage:** Should show CallerAddresses and allow viewing them. Need to verify this works for HCP customers.

### Agreed Approach
Implement as-is and review. Minor improvement: when `create-customer` is called with an address, sync that initial address to CallerAddress too (currently only `create-property` syncs).

### Files to Change (minor)
- `callsaver-api/src/routes/field-service-tools.ts` — `create-customer` route: add CallerAddress sync (same pattern as create-property).

---

## 10. React-Joyride Tour Architecture

### Current State
- Tour lives in `callsaver-frontend/src/components/app-tour/`
- `TourProvider.tsx` — wraps the app, manages Joyride state, handles multi-route navigation
- `tour-steps.ts` — desktop steps (hardcoded array)
- `tour-steps-mobile.ts` — mobile steps (hardcoded array)
- Steps reference `data-tour` attributes on DOM elements
- Tour starts via URL param `?tour=true` or localStorage flag
- Tracks completion via `useUserState().completeWalkthrough()`

### Problems to Solve
1. **Integration-specific steps:** Tour content changes based on integration (GCal → "appointments", Jobber → "service requests", HCP → "leads & estimates").
2. **Vertical-specific steps:** Future verticals (law, wellness) will have different features.
3. **Empty data handling:** During tour, there may be no callers/calls. Need mock data or "empty state" aware steps.
4. **Existing data handling:** Developer testing with real data in the DB — tour should work regardless.

### Agreed Architecture: Tour Step Registry

Replace the hardcoded step arrays with a **step registry** that assembles tour steps dynamically based on integration + vertical.

**Vertical identifier:** `'fs'` (consistent with `fs_` tool prefix used throughout the backend). Future verticals: `'law'`, `'wellness'`, etc. For now, only `'fs'` is implemented.

#### Step Registry Design

```
src/components/app-tour/
├── TourProvider.tsx          (existing — mostly unchanged)
├── tour-registry.ts          (NEW — assembles steps from modules)
├── steps/
│   ├── common.ts             (welcome, dashboard, callers, support — always shown)
│   ├── locations.ts          (voice config, services, areas — always shown)
│   ├── gcal.ts               (Google Calendar specific steps)
│   ├── jobber.ts             (Jobber specific steps)
│   ├── housecallpro.ts       (HCP specific steps)
│   └── [future: law.ts, wellness.ts]
└── tour-data-provider.tsx    (NEW — provides mock data context during tour)
```

#### `tour-registry.ts`

```typescript
import { commonSteps } from './steps/common';
import { locationSteps } from './steps/locations';
import { gcalSteps } from './steps/gcal';
import { jobberSteps } from './steps/jobber';
import { hcpSteps } from './steps/housecallpro';

export type IntegrationType = 'google-calendar' | 'jobber' | 'housecall-pro' | null;
export type Vertical = 'fs' | 'law' | 'wellness' | null;

export function assembleTourSteps(
  integration: IntegrationType,
  vertical: Vertical,
  isMobile: boolean,
): TourStep[] {
  const steps: TourStep[] = [];

  // Phase 1: Welcome + Dashboard (always)
  steps.push(...commonSteps.dashboard);

  // Phase 2: Locations / Voice config (always)
  steps.push(...locationSteps);

  // Phase 3: Callers (always)
  steps.push(...commonSteps.callers);

  // Phase 4: Integration-specific (within the 'fs' vertical for now)
  if (integration === 'jobber') {
    steps.push(...jobberSteps);
  } else if (integration === 'housecall-pro') {
    steps.push(...hcpSteps);
  } else {
    steps.push(...gcalSteps); // Default: GCal or no integration
  }

  // Future: vertical-specific steps would be added here
  // if (vertical === 'law') steps.push(...lawSteps);
  // if (vertical === 'wellness') steps.push(...wellnessSteps);

  // Phase 5: Settings + Support (always)
  steps.push(...commonSteps.settings);
  steps.push(...commonSteps.wrapup);

  return steps;
}
```

#### Mock Data During Tour: `TourDataProvider`

Rather than injecting mock data into the real API, use a **tour context** that components can check:

```typescript
// tour-data-provider.tsx
const TourContext = createContext({ isTourActive: false });

export function useTourContext() {
  return useContext(TourContext);
}
```

Components that render data (e.g., recent calls list, caller list) check `isTourActive`:
- If tour is active AND real data exists → show real data (works for dev testing).
- If tour is active AND no real data → show a "sample" empty state message that's tour-friendly: "After your first call, you'll see call summaries here."
- The tour steps themselves should use language like "This is where you'll see..." instead of "Here are your..." to work regardless of data presence.

**This approach avoids:** fake data injection, DB clearing, API mocking. Tour steps simply describe what _will_ appear, and the step text is written to be correct regardless of data state.

#### TourProvider Changes

```typescript
// In TourProvider.tsx
const { connectedIntegration } = useIntegrations();
const integration = connectedIntegration?.type || null;
const vertical: Vertical = 'fs'; // Only fs for now; detect from org config in future

const steps = useMemo(
  () => assembleTourSteps(integration, vertical, isMobile),
  [integration, vertical, isMobile]
);
```

### Files to Change
- `callsaver-frontend/src/components/app-tour/tour-registry.ts` (NEW)
- `callsaver-frontend/src/components/app-tour/steps/common.ts` (NEW)
- `callsaver-frontend/src/components/app-tour/steps/locations.ts` (NEW)
- `callsaver-frontend/src/components/app-tour/steps/gcal.ts` (NEW)
- `callsaver-frontend/src/components/app-tour/steps/jobber.ts` (NEW)
- `callsaver-frontend/src/components/app-tour/steps/housecallpro.ts` (NEW)
- `callsaver-frontend/src/components/app-tour/TourProvider.tsx` (use registry + useIntegrations)
- `callsaver-frontend/src/components/app-tour/tour-data-provider.tsx` (NEW)
- Remove: `tour-steps.ts`, `tour-steps-mobile.ts` (replaced by registry)

---

## 11. Estimate Scheduling Endpoint (rescheduleAssessment)

### Problem
The HCP adapter currently uses the **generic jobs schedule endpoint** (`PUT /jobs/{id}/schedule`) to schedule estimates. But HCP has a dedicated **estimate option schedule endpoint** (`PUT /estimates/{estimate_id}/options/{option_id}/schedule`) which is more appropriate and feature-rich.

Additionally, `rescheduleAssessment()` appears to be **missing** from the HCP adapter entirely (the Assessment section comment says `(2)` methods — only `createAssessment` and `cancelAssessment`). The base class declares it abstract.

### Current vs Correct Endpoint

| Feature | `PUT /jobs/{id}/schedule` (current) | `PUT /estimates/{id}/options/{id}/schedule` (correct) |
|---|---|---|
| Estimate-specific | No (generic jobs) | Yes |
| Option-level scheduling | No | Yes (estimates have options) |
| `notify` (customer notifications) | No | **Yes** |
| `notify_pro` (employee notifications) | No | **Yes** |
| `arrival_window_in_minutes` | No | **Yes** |
| `dispatched_employees` | No | **Yes** |

### HCP Data Model
Estimates have **options** (e.g., different service tiers/packages). Scheduling happens at the option level. The adapter already uses this pattern in `acceptEstimate()` and `declineEstimate()` — they fetch the estimate to get option IDs.

### Proposed Fix

1. **Add `rescheduleAssessment()`** — fetch estimate → get `options[0].id` → call `PUT /estimates/{id}/options/{optionId}/schedule`
2. **Update `createAssessment()`** scheduling section (line 384) — same change: use estimate option schedule endpoint instead of `/jobs/{id}/schedule`
3. Both methods should pass `notify: true, notify_pro: true` for customer/employee notifications

```typescript
// Shared scheduling logic:
const est = await this.client.get(`/estimates/${assessmentId}`);
const optionId = est?.options?.[0]?.id;
if (!optionId) throw ...;

await this.client.put(`/estimates/${assessmentId}/options/${optionId}/schedule`, {
  start_time: startTime.toISOString(),
  end_time: endTime.toISOString(),
  notify: true,
  notify_pro: true,
});
```

### Files to Change
- `callsaver-api/src/adapters/field-service/platforms/housecallpro/HousecallProAdapter.ts`:
  - Add `rescheduleAssessment()` method
  - Update `createAssessment()` scheduling section to use estimate option endpoint
  - Add `getClientSchedule()` if also missing

---

## Implementation Priority

| # | Issue | Effort | Priority | Dependency |
|---|---|---|---|---|
| 1 | Lead address bug | 15 min | P0 | None (1-line fix) |
| 4 | Invalid date bug | 30 min | P0 | None |
| 5 | External URI links | 45 min | P0 | None |
| 8 | Transcript height limiting | 15 min | P0 | None |
| 11 | Estimate scheduling endpoint fix | 1-2 hr | P0 | None (broken/missing method) |
| 9 | Multiple addresses sync | 30 min | P1 | None |
| 2 | Unscheduled vs scheduled mode | 3-4 hr | P1 | None |
| 3 | Frontend sidebar & page structure | 3-4 hr | P1 | #2 |
| 6 | Tool call name mapping | 1-2 hr | P2 | #2 (mode-aware names) |
| 7 | Tool call logos | 1 hr | P2 | #6 |
| 10 | Tour architecture | 4-6 hr | P3 | #2, #3 |

**Suggested order:** 1 → 4 → 5 → 8 → 11 → 9 → 2 → 3 → 6 → 7 → 10

Total estimated effort: ~17-22 hours
