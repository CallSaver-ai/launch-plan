# Jobber Adapter Recovery & Integration Plan

> Created: Feb 17, 2026
> Prerequisite for: `jobber-integration-testing-plan.md`

---

## What Was Recovered

On Feb 17, 2026, the field-service adapter directory was restored from git:

```bash
git checkout 1d966a6c6 -- src/adapters/field-service/
```

This restored the following files to `~/callsaver-api/src/adapters/field-service/`:

| File | Size | Description |
|------|------|-------------|
| `platforms/jobber/JobberAdapter.ts` | 157 KB (4,956 lines) | Full Jobber GraphQL adapter — all 19+ methods |
| `platforms/jobber/JobberClient.ts` | 5.6 KB (200 lines) | GraphQL client with Nango OAuth token management |
| `FieldServiceAdapter.ts` | 31 KB | Full interface definition (includes `CallerContext`) |
| `FieldServiceAdapterV1.ts` | 4.4 KB | MVP interface (14 methods) |
| `FieldServiceAdapterRegistry.ts` | 5.5 KB | Factory + cache for adapter instances |
| `FieldServiceAdapterFactory.ts` | 2.6 KB | Platform → adapter constructor mapping |
| `BaseFieldServiceAdapter.ts` | 9.6 KB | Abstract base class with phone verification |
| `phoneVerification.ts` | 3.2 KB | E164 normalization for Jobber phone numbers |
| `errors.ts` | 6.7 KB | Field service error types and helpers |
| `platforms/jobber/README.md` | 49 KB | Comprehensive adapter documentation |
| `platforms/jobber/TESTING.md` | 2.9 KB | Test plan for adapter |
| `platforms/jobber/NANGO_SETUP_GUIDE.md` | 8.4 KB | Nango configuration for Jobber |
| `platforms/jobber/JOBBER_TYPE_MAPPING.md` | 8.8 KB | Jobber GraphQL ↔ our types mapping |
| `platforms/jobber/TOOL_REDUCTION_PLAN.md` | 18 KB | How 40+ tools were reduced to 19 V1 |
| `FIELD_SERVICE_ADAPTER_DESIGN.md` | 38 KB | Architecture design document |
| + 5 more doc files | various | Security, phone scenarios, VAPI guide, etc. |

Additionally, 1,550 lines of old VAPI webhook endpoints were extracted to `/tmp/jobber-vapi-endpoints-all.ts` for reference (19 endpoint handlers that called the adapter).

---

## Current Compile Errors (4 Total)

After recovery, `npx tsc --noEmit` shows exactly **4 field-service errors** (other adapter verticals have pre-existing errors unrelated to this work):

### Error 1: Import path wrong in JobberAdapter.ts

```
src/adapters/field-service/platforms/jobber/JobberAdapter.ts(45,8):
  error TS2307: Cannot find module '../../../types/field-service'
```

**Root cause:** `JobberAdapter.ts` is at depth `adapters/field-service/platforms/jobber/`, so `../../../types/field-service` resolves to `adapters/types/field-service` (wrong). It should be `../../../../types/field-service`.

**Fix:**
```typescript
// JobberAdapter.ts line 45 — change:
} from '../../../types/field-service';
// to:
} from '../../../../types/field-service';
```

### Error 2: CallerContext not exported from types/field-service.ts

```
src/adapters/field-service/FieldServiceAdapterV1.ts(26,3):
  error TS2305: Module '"../../types/field-service"' has no exported member 'CallerContext'.
```

**Root cause:** `CallerContext` is defined in `FieldServiceAdapter.ts` (line 60), not in `types/field-service.ts`. The `FieldServiceAdapterV1.ts` imports it from the wrong location.

**Fix:** Add `CallerContext` export to `src/types/field-service.ts`:
```typescript
/**
 * Security context for voice agent operations
 * All operations must verify the caller's phone number matches the customer
 */
export interface CallerContext {
  callerPhoneNumber: string;
  businessPhoneNumber?: string;
}
```

Then either:
- (a) Keep importing from `types/field-service.ts` in `FieldServiceAdapterV1.ts` (preferred — single source of truth), OR
- (b) Change `FieldServiceAdapterV1.ts` to import from `./FieldServiceAdapter`

**Recommendation:** Option (a) — add to `types/field-service.ts` and also re-export from `FieldServiceAdapter.ts` so both import paths work.

### Error 3: BaseFieldServiceAdapter interface mismatch

```
src/adapters/field-service/BaseFieldServiceAdapter.ts(22,23):
  error TS2420: Class 'BaseFieldServiceAdapter' incorrectly implements interface 'FieldServiceAdapter'.
```

**Root cause:** Cascading from Error 2. Once `CallerContext` is resolved, the types will align. The `FieldServiceAdapter` interface uses `CallerContext` in all method signatures, and `BaseFieldServiceAdapter` implements them — they just can't resolve the type right now.

**Fix:** Resolves automatically when Error 2 is fixed.

### Error 4: Null vs undefined type mismatch in Registry

```
src/adapters/field-service/FieldServiceAdapterRegistry.ts(51,7):
  error TS2322: Type 'FieldServicePlatform | null' is not assignable to type 'FieldServicePlatform | undefined'.
```

**Root cause:** `getPlatformForLocation()` returns `null` but the parameter expects `undefined`.

**Fix:**
```typescript
// FieldServiceAdapterRegistry.ts line 51 — change:
platform = await this.getPlatformForLocation(locationId);
// to:
platform = await this.getPlatformForLocation(locationId) ?? undefined;
```

Or change the return type of `getPlatformForLocation` to `FieldServicePlatform | undefined`.

---

## Deleted Helper Functions to Restore

The VAPI cleanup commit (`d916c8f10`) deleted two helper functions from `server.ts` that are needed:

### `getFieldServiceAdapter()` (lines 9457-9493 of old server.ts)

Creates a `FieldServiceAdapterRegistry` and returns an adapter for a location. Needs to be restored (or rewritten for the new `/internal/tools/` pattern).

```typescript
async function getFieldServiceAdapter(location: any): Promise<FieldServiceAdapter | null> {
  const activeConnection = await prisma.nangoConnection.findFirst({
    where: {
      organizationId: location.organization.id,
      isActive: true,
      status: 'active'
    }
  });

  if (!activeConnection) return null;
  if (activeConnection.integrationType !== 'jobber') return null;

  const registry = new FieldServiceAdapterRegistry({
    prisma,
    nangoSecretKey: process.env.NANGO_SECRET_KEY!
  });
  
  try {
    return await registry.getAdapter(location.id);
  } catch (error: any) {
    console.error('Error getting adapter:', error.message);
    return null;
  }
}
```

### `extractCallerContext()` (lines 9496-9520 of old server.ts)

Extracted caller phone from VAPI message format. For the new LiveKit pattern, this becomes simpler since `callerPhoneNumber` comes directly in the request body:

```typescript
// New version for /internal/tools/ endpoints:
function buildCallerContext(callerPhoneNumber: string, businessPhoneNumber?: string): CallerContext | null {
  const normalizedPhone = normalizeToE164(callerPhoneNumber);
  if (!normalizedPhone) return null;
  return {
    callerPhoneNumber: normalizedPhone,
    businessPhoneNumber: businessPhoneNumber || undefined
  };
}
```

---

## Jobber GraphQL API Version Check

The recovered `JobberClient.ts` uses:
```typescript
'X-JOBBER-GRAPHQL-VERSION': '2025-01-20'
```

This was the latest version as of the original implementation (Nov 2025). Jobber may have released newer API versions since then.

**Action needed:** Check https://developer.getjobber.com/docs/changelog for any breaking changes between `2025-01-20` and the current latest version. If there are breaking changes to queries we use, update the adapter.

**Likely safe:** Jobber uses versioned APIs specifically to avoid breaking changes — the `2025-01-20` version should still work. We can upgrade later if needed.

---

## Step-by-Step Integration Plan

### Step 1: Fix Compile Errors (30 min)

1. **Add `CallerContext` to `src/types/field-service.ts`**
   ```typescript
   export interface CallerContext {
     callerPhoneNumber: string;
     businessPhoneNumber?: string;
   }
   ```

2. **Fix import path in `JobberAdapter.ts` line 45**
   ```
   '../../../types/field-service' → '../../../../types/field-service'
   ```

3. **Fix null/undefined in `FieldServiceAdapterRegistry.ts` line 51**
   ```typescript
   platform = await this.getPlatformForLocation(locationId) ?? undefined;
   ```

4. **Verify:** `npx tsc --noEmit 2>&1 | grep "field-service"` should return 0 errors.

### Step 2: Restore `getFieldServiceAdapter()` Helper (15 min)

Add to `server.ts` near the other helper functions (around line 210-250 area, near `findLocationByBusinessPhoneNumber`):

```typescript
import { FieldServiceAdapterRegistry } from './adapters/field-service/FieldServiceAdapterRegistry';
import { FieldServiceAdapter, CallerContext } from './adapters/field-service/FieldServiceAdapter';
import { normalizeToE164 } from './adapters/field-service/phoneVerification';

async function getFieldServiceAdapter(locationId: string): Promise<FieldServiceAdapter | null> {
  // Get location with organization
  const location = await prisma.location.findUnique({
    where: { id: locationId },
    include: { organization: true }
  });
  if (!location?.organization) return null;

  // Check for active Jobber connection
  const activeConnection = await prisma.nangoConnection.findFirst({
    where: {
      organizationId: location.organization.id,
      integrationType: 'jobber',
      isActive: true,
      status: 'active'
    }
  });
  if (!activeConnection) return null;

  const registry = new FieldServiceAdapterRegistry({
    prisma,
    nangoSecretKey: process.env.NANGO_SECRET_KEY!
  });

  try {
    return await registry.getAdapter(locationId);
  } catch (error: any) {
    console.error(`[getFieldServiceAdapter] Error: ${error.message}`);
    return null;
  }
}
```

### Step 3: Create First `/internal/tools/jobber-*` Endpoint (1 hour)

Start with `jobber-get-customer-by-phone` as the proof-of-concept. This validates the entire chain:
Nango OAuth → JobberClient → GraphQL → JobberAdapter → API response.

Add to `server.ts` after the existing `/internal/tools/google-calendar-*` endpoints:

```typescript
// ============================================================================
// JOBBER INTERNAL TOOL ENDPOINTS
// ============================================================================

app.post('/internal/tools/jobber-get-customer-by-phone', verifyInternalApiKey, async (req, res) => {
  try {
    const { locationId, callerPhoneNumber } = req.body;
    if (!locationId) return res.status(400).json({ message: 'locationId is required' });
    if (!callerPhoneNumber) return res.status(400).json({ message: 'callerPhoneNumber is required' });

    const adapter = await getFieldServiceAdapter(locationId);
    if (!adapter) {
      return res.status(404).json({ message: 'Jobber integration not active for this location' });
    }

    const normalizedPhone = normalizeToE164(callerPhoneNumber);
    if (!normalizedPhone) {
      return res.status(400).json({ message: 'Invalid phone number format' });
    }

    const context: CallerContext = { callerPhoneNumber: normalizedPhone };
    const customer = await adapter.findCustomerByPhone(context);

    if (!customer) {
      return res.json({
        customer: null,
        message: 'Customer not found in Jobber.'
      });
    }

    return res.json({
      customer,
      message: `Found customer: ${customer.name || customer.firstName || 'Unknown'}. Email: ${customer.email || 'not on file'}.`
    });
  } catch (error: any) {
    console.error('[jobber-get-customer-by-phone] Error:', error.message);
    return res.status(500).json({ message: error.message || 'Failed to get customer' });
  }
});
```

### Step 4: Test the Proof-of-Concept (30 min)

**Prerequisites:**
- A Jobber test account connected via Nango
- A test organization in CallSaver with a Jobber `NangoConnection` (isActive: true, status: 'active')
- At least one customer in the Jobber test account with a phone number

**Test with curl:**
```bash
curl -X POST http://localhost:3001/internal/tools/jobber-get-customer-by-phone \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $INTERNAL_API_KEY" \
  -d '{
    "locationId": "<your-test-location-id>",
    "callerPhoneNumber": "+15551234567"
  }'
```

**Expected success response:**
```json
{
  "customer": {
    "id": "abc123",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+15551234567",
    ...
  },
  "message": "Found customer: John Doe. Email: john@example.com."
}
```

**If this works:** The entire adapter chain is functional — Nango OAuth, JobberClient GraphQL, JobberAdapter, and the endpoint. Remaining endpoints are mechanical.

### Step 5: Convert Remaining 18 Endpoints (1-2 days)

Each follows the same pattern. Here's the full list with the adapter method each calls:

| # | Endpoint | Adapter Method | Request Body |
|---|----------|---------------|-------------|
| 1 | `jobber-get-customer-by-phone` | `findCustomerByPhone(context)` | `locationId, callerPhoneNumber` |
| 2 | `jobber-update-customer` | `updateCustomer(context, customerId, data)` | `locationId, callerPhoneNumber, customerId, firstName?, lastName?, email?, address?` |
| 3 | `jobber-list-properties` | `listProperties(context, customerId)` | `locationId, callerPhoneNumber, customerId` |
| 4 | `jobber-get-property` | `getProperty(context, propertyId)` | `locationId, callerPhoneNumber, propertyId` |
| 5 | `jobber-create-property` | `createProperty(context, data)` | `locationId, callerPhoneNumber, customerId, street, city, state, zipCode, country?` |
| 6 | `jobber-update-property` | `updateProperty(context, propertyId, data)` | `locationId, callerPhoneNumber, propertyId, street?, city?, state?, zipCode?` |
| 7 | `jobber-delete-property` | `deleteProperty(context, propertyId)` | `locationId, callerPhoneNumber, propertyId` |
| 8 | `jobber-get-jobs` | `getJobs(context, customerId, filters?, limit?)` | `locationId, callerPhoneNumber, customerId` |
| 9 | `jobber-get-job` | `getJob(context, jobId)` | `locationId, callerPhoneNumber, jobId` |
| 10 | `jobber-get-appointments` | `getAppointments(context, customerId, dateRange?, limit?)` | `locationId, callerPhoneNumber, customerId` |
| 11 | `jobber-get-appointment` | `getAppointment(context, appointmentId)` | `locationId, callerPhoneNumber, appointmentId` |
| 12 | `jobber-create-appointment` | `createAppointment(context, data)` | `locationId, callerPhoneNumber, customerId, startTime, endTime, description?, jobId?` |
| 13 | `jobber-reschedule-appointment` | `rescheduleAppointment(context, appointmentId, newTime)` | `locationId, callerPhoneNumber, appointmentId, newStartTime, newEndTime` |
| 14 | `jobber-cancel-appointment` | `cancelAppointment(context, appointmentId, reason?)` | `locationId, callerPhoneNumber, appointmentId, reason?` |
| 15 | `jobber-get-account-balance` | `getAccountBalance(context, customerId)` | `locationId, callerPhoneNumber, customerId` |
| 16 | `jobber-get-invoices` | `getInvoices(context, customerId, status?, limit?)` | `locationId, callerPhoneNumber, customerId` |
| 17 | `jobber-create-service-request` | `createServiceRequest(context, data)` | `locationId, callerPhoneNumber, customerId, description, priority?` |
| 18 | `jobber-get-service-catalog` | `getServiceCatalog(context, limit?)` | `locationId, callerPhoneNumber` |
| 19 | `jobber-get-services` | `getServices(context, filters?, limit?)` | `locationId, callerPhoneNumber, category?` |

Each endpoint is ~30-50 lines of boilerplate. The adapter does all the heavy lifting.

### Step 6: Uncomment Adapter in `utils.ts` (15 min)

In `src/utils.ts`, `generateSystemPromptForLocationWithJobberV1()` (lines ~3263-3337) has the adapter calls commented out with `// Temporarily commented out for CI/CD`.

Uncomment and update to use the restored adapter:
```typescript
const { FieldServiceAdapterRegistry } = await import('./adapters/field-service/FieldServiceAdapterRegistry.js');
const { normalizeToE164 } = await import('./adapters/field-service/phoneVerification.js');
```

### Step 7: Register Jobber Tool Names in Agent Config (30 min)

The agent config builder (`buildDynamicAssistantConfig` or equivalent) needs to return Jobber tool names when the org has a Jobber integration instead of Google Calendar tool names.

Find where the Google Calendar tool names are added to the agent config response (search for `google-calendar-check-availability` in the agent config code) and add a parallel branch for Jobber:

```typescript
if (integrationType === 'jobber') {
  tools.push(
    'jobber-get-customer-by-phone',
    'jobber-update-customer',
    'jobber-get-jobs',
    'jobber-get-job',
    'jobber-get-appointments',
    'jobber-get-appointment',
    'jobber-create-appointment',
    'jobber-reschedule-appointment',
    'jobber-cancel-appointment',
    'jobber-get-account-balance',
    'jobber-get-invoices',
    'jobber-create-service-request',
    'jobber-get-service-catalog',
    'jobber-get-services',
    'jobber-list-properties',
    'jobber-get-property',
    'jobber-create-property',
    'jobber-update-property',
    'jobber-delete-property',
  );
}
```

### Step 8: Create Python LiveKit Tools (1-2 days)

Create 19 Python tool files in `livekit-python/tools/`. Each follows the exact pattern of `google_calendar_list_events.py`:

```python
# livekit-python/tools/jobber_get_appointments.py
"""Jobber Get Appointments Tool"""

from livekit.agents import function_tool, RunContext
from typing import TYPE_CHECKING, Optional
import httpx
import asyncio

if TYPE_CHECKING:
    from .__init__ import ToolContext

def jobber_get_appointments_tool(context: "ToolContext"):
    @function_tool()
    async def jobber_get_appointments(
        ctx: RunContext,
        customer_id: str,
    ) -> str:
        """
        Get upcoming appointments/visits for a customer from Jobber.
        Use when the caller asks about their appointments or scheduled visits.
        """
        try:
            tool_context = None
            try:
                userdata = ctx.session.userdata
                if userdata:
                    tool_context = userdata.get("tool_context")
            except ValueError:
                pass
            if not tool_context:
                agent = getattr(ctx.session, "agent", None)
                if agent:
                    tool_context = getattr(agent, "_tool_context", None)
            if not tool_context:
                raise Exception("Tool context not available.")

            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    f"{tool_context.api_url}/internal/tools/jobber-get-appointments",
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {tool_context.internal_api_key}",
                    },
                    json={
                        "locationId": tool_context.location_id,
                        "callerPhoneNumber": tool_context.caller_phone_number,
                        "customerId": customer_id,
                    },
                )
                if not response.is_success:
                    raise Exception(f"API error: {response.status_code}")
                result = response.json()
                return result.get("message", "No appointments found.")
        except httpx.TimeoutException:
            return "Request timed out. Please try again."
        except Exception as error:
            return f"Error getting appointments: {str(error)}"

    return jobber_get_appointments
```

Then register all 19 in `livekit-python/tools/__init__.py` — add imports and `elif` branches.

---

## Dependency Notes

### npm packages already installed
- `@nangohq/node` — used by JobberClient for OAuth
- `axios` — used by JobberClient for HTTP
- `@prisma/client` — used by Registry for DB queries

No new npm dependencies needed.

### Python packages already installed
- `httpx` — used by all existing tools
- `livekit.agents` — agent framework

No new Python dependencies needed.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Jobber GraphQL API version `2025-01-20` deprecated | Low | High | Check Jobber changelog; the version should still work |
| Nango `jobber` provider OAuth credentials expired | Medium | High | Re-verify in Nango dashboard before testing |
| Prisma schema drift breaks Registry queries | Low | Medium | We verified — `NangoConnection` schema is compatible |
| Adapter's GraphQL queries use deprecated fields | Low | Medium | Jobber versions are stable; test each endpoint |
| `@nangohq/node` SDK version mismatch | Low | Low | Already installed; just verify import works |

---

## Execution Order Summary

| Step | Time | What | Blocks |
|------|------|------|--------|
| **1** | 30 min | Fix 4 compile errors | Everything |
| **2** | 15 min | Restore `getFieldServiceAdapter()` helper in server.ts | Step 3 |
| **3** | 1 hour | Create first endpoint (`jobber-get-customer-by-phone`) | Step 4 |
| **4** | 30 min | Test proof-of-concept with curl against Jobber test account | Step 5 |
| **5** | 1-2 days | Convert remaining 18 endpoints | Step 8 |
| **6** | 15 min | Uncomment adapter in `utils.ts` prompt generation | Step 7 |
| **7** | 30 min | Register Jobber tool names in agent config builder | Step 8 |
| **8** | 1-2 days | Create 19 Python LiveKit tools + register in `__init__.py` | Testing plan |

**Total: ~3-4 days for backend integration, plus ~3-4 days for frontend adaptation.**

After Step 4 succeeds, Steps 5-8 are mechanical and low-risk.

---

## Frontend Adaptation: Jobber-Connected Experience

### Design Principle

Existing Jobber users already know Jobber's terminology. When they connect Jobber and open
CallSaver, the UI should feel like a **natural extension of Jobber** — not a foreign app
that relabels everything. Sidebar labels, page titles, column headers, and data sources
all change based on the connected integration.

### Terminology Mapping

| Current (Google Calendar) | Jobber-Connected | Why |
|--------------------------|-----------------|-----|
| **Callers** | **Clients** | Jobber calls them "clients" — familiar to users |
| **Caller Detail** | **Client Detail** | Consistent |
| **Appointments** | **Schedule** | Jobber's nav uses "Schedule" for the visit calendar |
| *(not shown)* | **Jobs** | New concept — Jobber users think in jobs |
| **Calendar Events** | **Visits** | Jobber calls scheduled events "visits" |
| **Caller Address** | **Property** / **Service Location** | Jobber calls them "properties" |

### Data Source Switching

The frontend already has `useIntegrations()` → `connectedIntegration` which returns the
active integration type. This is the switch point:

```typescript
// hooks/use-integration-context.ts (new)
export function useIntegrationContext() {
  const { connectedIntegration } = useIntegrations();
  const isJobber = connectedIntegration?.type === 'jobber';
  const isGoogleCalendar = connectedIntegration?.type === 'google-calendar';
  
  return {
    isJobber,
    isGoogleCalendar,
    // Terminology
    customerLabel: isJobber ? 'Client' : 'Caller',
    customersLabel: isJobber ? 'Clients' : 'Callers',
    appointmentLabel: isJobber ? 'Visit' : 'Appointment',
    appointmentsLabel: isJobber ? 'Schedule' : 'Appointments',
    addressLabel: isJobber ? 'Property' : 'Address',
    addressesLabel: isJobber ? 'Properties' : 'Addresses',
    // Data sources
    customersEndpoint: isJobber ? '/me/jobber/clients' : '/me/callers',
    appointmentsEndpoint: isJobber ? '/me/jobber/visits' : '/me/calendar/events',
  };
}
```

### Page-by-Page Changes

#### 1. Sidebar Navigation (`sidebar-data.ts`)

The sidebar is currently static. It needs to become integration-aware:

| Item | Google Calendar | Jobber |
|------|----------------|--------|
| Row 3 | `Callers` → `/callers` (Phone icon) | `Clients` → `/clients` (Users icon) |
| Row 5 | `Appointments` → `/appointments` (Calendar icon) | `Schedule` → `/schedule` (Calendar icon) |
| *(new)* | — | `Jobs` → `/jobs` (Briefcase icon) |

**Implementation:** Make `sidebar-data.ts` export a function that takes `connectedIntegration`
and returns the appropriate nav items. Or use the `useIntegrationContext` hook in
`app-sidebar.tsx` to swap labels and routes.

#### 2. Callers Page → Clients Page (`/callers` or `/clients`)

**Current** (`CallersPage.tsx`):
- `useCallersList()` → `GET /me/callers` → our Caller DB table
- Shows: name, phone, email, call count, last call date, spam flag
- Click → `/callers/:callerId` (CallerDetailPage)

**Jobber mode** — same page component, different data source:
- `useClientsList()` → `GET /me/jobber/clients` → Jobber GraphQL `clients` query
- Shows: name, phone, email, **active jobs count**, **outstanding balance**, last visit date
- Click → `/clients/:jobberClientId` (ClientDetailPage — may reuse CallerDetailPage)

**Key differences:**
- **No spam filtering** — Jobber clients are all legitimate customers
- **Extra columns:** active jobs, balance owed, properties count
- **Search** should search Jobber's `clients(searchTerm)` API, not our DB
- **No "add caller" button** — clients are managed in Jobber

**Backend endpoint needed:** `GET /me/jobber/clients` that calls `adapter.findCustomerByPhone()`
for each, or better, adds a `listClients()` method to the adapter that does a paginated
`clients(first: N)` GraphQL query.

#### 3. Caller Detail → Client Detail (`/callers/:id` or `/clients/:id`)

**Current** (`CallerDetailPage.tsx`):
- Tabs: Overview, Call History
- Overview: name, phone, email, address, notes
- Embedded `CalendarEvents` component showing events for this phone number
- Call recordings + transcripts

**Jobber mode:**
- Tabs: **Overview**, **Jobs**, **Visits**, **Invoices**, **Call History**
- **Overview tab:**
  - Client info from Jobber (name, email, phones, billing address)
  - Properties list (service locations) — each with address, can expand
  - Quick stats: total jobs, upcoming visits, outstanding balance
- **Jobs tab:**
  - List of jobs from `adapter.getJobs(context, clientId)`
  - Each job shows: job number, title, status badge, total value, visit count
  - Click job → expand to show visits under that job
- **Visits tab:**
  - Upcoming and recent visits from `adapter.getAppointments(context, clientId)`
  - Each visit shows: date/time, assigned crew, status, property address
  - Street View thumbnail using property address (reuse existing component)
  - Route calculation between visits (reuse existing route component)
- **Invoices tab:**
  - From `adapter.getInvoices(context, clientId)`
  - Each invoice: number, date, amount, status (paid/outstanding/overdue)
  - Balance summary at top
- **Call History tab:**
  - Same as current — from our CallRecord table (we always own this)
  - Links back to call recordings, transcripts

**Backend endpoints needed:**
- `GET /me/jobber/clients/:clientId` — full client detail
- `GET /me/jobber/clients/:clientId/jobs` — jobs for client
- `GET /me/jobber/clients/:clientId/visits` — visits for client
- `GET /me/jobber/clients/:clientId/invoices` — invoices for client
- `GET /me/jobber/clients/:clientId/properties` — properties for client

#### 4. Appointments Page → Schedule Page (`/appointments` or `/schedule`)

**Current** (`AppointmentsPage.tsx`):
- `CalendarEvents` component → `useCalendarEvents()` → `GET /me/calendar/events`
- Groups events by day, shows weather, route legs between appointments
- Filters: upcoming, past

**Jobber mode:**
- `VisitsSchedule` component → `useVisits()` → `GET /me/jobber/visits`
- Same day-grouping and chronological display
- Each visit card shows:
  - **Time range** (start → end)
  - **Job context:** "Job #1234 — Weekly Lawn Care" (badge + title)
  - **Client name** (linked to client detail)
  - **Property address** (for Street View + routing)
  - **Assigned crew** (team member names/avatars)
  - **Status badge** (scheduled, in progress, complete, cancelled)
- Route legs between visits (reuse existing route calculation — same concept)
- Weather overlay (reuse existing — uses property address like GCal uses event location)

**Key difference:** Each visit carries its parent Job, so the card has a two-line header:
```
┌──────────────────────────────────────────────┐
│ 9:00 AM - 10:30 AM                          │
│ Job #1234 — Weekly Lawn Care    [Scheduled]  │
│ 📍 123 Oak St, Springfield                   │
│ 👤 John Smith  →  🔧 Mike, Sarah            │
│ ☁️ 72°F Partly Cloudy                       │
└──────────────────────────────────────────────┘
```

**Backend endpoint needed:** `GET /me/jobber/visits` — returns visits with embedded job
and client context, sorted chronologically.

#### 5. Jobs Page (NEW — Jobber only, `/jobs`)

This page doesn't exist in the Google Calendar experience. It shows the job pipeline:

- List of jobs grouped by status: **Active**, **Upcoming**, **Completed**, **Cancelled**
- Each job card: job number, title, client name, total value, visit count, date range
- Click → job detail (could be inline expand or separate page)
- Job detail shows: line items, all visits, invoices, notes

**Backend endpoint needed:** `GET /me/jobber/jobs` — returns jobs with summary stats.

#### 6. Dashboard Page (`/dashboard`)

The dashboard already shows:
- Recent calls (stays the same — our data)
- Caller cards with last call info

**Jobber mode additions:**
- **Today's visits** widget (next 3-5 visits for the day)
- **Active jobs** count
- **Outstanding balance** across all clients
- Caller cards → Client cards (show Jobber client name + job context)

#### 7. Routes (`App.tsx`)

New routes needed for Jobber mode (can coexist with existing routes):

```tsx
// Jobber-specific routes (loaded when Jobber is connected)
<Route path="/clients" element={<ClientsPage />} />
<Route path="/clients/:clientId" element={<ClientDetailPage />} />
<Route path="/schedule" element={<SchedulePage />} />
<Route path="/jobs" element={<JobsPage />} />
<Route path="/jobs/:jobId" element={<JobDetailPage />} />

// Existing routes still work for Google Calendar mode
<Route path="/callers" element={<CallersPage />} />
<Route path="/callers/:callerId" element={<CallerDetailPage />} />
<Route path="/appointments" element={<AppointmentsPage />} />
```

Alternatively, reuse the same page components and switch data sources internally.
The cleaner approach is **separate page components** that share UI primitives (cards,
badges, route calculator, weather overlay, street view) but have different data hooks.

### Shared Components (Reusable Across Both Modes)

These existing components work regardless of integration:

| Component | Used For |
|-----------|---------|
| Street View thumbnail | GCal event location / Jobber property address |
| Route legs calculator | Between GCal events / between Jobber visits |
| Weather overlay | Event location / visit property address |
| Call transcript viewer | Always our data |
| Recording player | Always our data |
| Day grouping / timeline | Events / visits |

### New Backend Endpoints Summary (Frontend-Facing)

All endpoints are user-authenticated (`requireAuth`), not internal tool endpoints.

| Endpoint | Returns | Used By |
|----------|---------|---------|
| `GET /me/jobber/clients` | Paginated client list | ClientsPage |
| `GET /me/jobber/clients/:id` | Full client detail | ClientDetailPage |
| `GET /me/jobber/clients/:id/jobs` | Client's jobs | ClientDetailPage Jobs tab |
| `GET /me/jobber/clients/:id/visits` | Client's visits | ClientDetailPage Visits tab |
| `GET /me/jobber/clients/:id/invoices` | Client's invoices | ClientDetailPage Invoices tab |
| `GET /me/jobber/clients/:id/properties` | Client's properties | ClientDetailPage Overview tab |
| `GET /me/jobber/visits` | All visits (date-filtered) | SchedulePage |
| `GET /me/jobber/jobs` | All jobs (status-filtered) | JobsPage |
| `GET /me/jobber/dashboard` | Today's visits, stats | DashboardPage widgets |

These are distinct from the `/internal/tools/jobber-*` endpoints (which are for the
voice agent). The `/me/jobber/*` endpoints use the same `JobberAdapter` but are
authenticated via user session, not internal API key.

### Implementation Strategy: Incremental, Not Big Bang

Don't rewrite every page at once. Layer it in:

1. **Phase A** — Add `useIntegrationContext()` hook + sidebar label switching (~0.5 day)
2. **Phase B** — SchedulePage (Jobber visits, replacing AppointmentsPage) (~2 days)
   - This is the highest-value page for field service businesses
   - Reuses existing day-grouping, route, weather components
3. **Phase C** — ClientsPage (Jobber clients, replacing CallersPage) (~1.5 days)
4. **Phase D** — ClientDetailPage with Jobs/Visits/Invoices tabs (~2 days)
5. **Phase E** — JobsPage (new, Jobber only) (~1 day)
6. **Phase F** — Dashboard Jobber widgets (~1 day)

**Total frontend effort: ~1-1.5 weeks**

### URL Strategy Decision

Two options:

**Option A: Separate URLs** (`/clients`, `/schedule`, `/jobs`)
- Pro: Clean, Jobber-native feeling, SEO-friendly
- Pro: Can build new pages without touching existing ones
- Con: Need redirects if user switches integration
- Con: More route configuration

**Option B: Same URLs, different content** (`/callers` shows clients, `/appointments` shows visits)
- Pro: Simpler routing, fewer changes
- Con: URL says "callers" but shows "clients" — confusing
- Con: Harder to add Jobs page (no existing route)

**Recommendation:** Option A — separate URLs. The sidebar already switches dynamically,
so the routes should match. Add redirects: `/callers` → `/clients` and
`/appointments` → `/schedule` when Jobber is connected.

---

## Revised Execution Order (Full Stack)

| Step | Time | What |
|------|------|------|
| **1** | 30 min | Fix 4 compile errors |
| **2** | 15 min | Restore `getFieldServiceAdapter()` in server.ts |
| **3** | 1 hour | First endpoint: `jobber-get-customer-by-phone` |
| **4** | 30 min | Test POC with curl |
| **5** | 1-2 days | Convert remaining 18 internal tool endpoints |
| **6** | 15 min | Uncomment adapter in utils.ts |
| **7** | 30 min | Register Jobber tools in agent config |
| **8** | 1-2 days | Create 19 Python LiveKit tools |
| **9** | 1 day | Build `/me/jobber/*` frontend-facing endpoints (visits, clients, jobs) |
| **10** | 0.5 day | `useIntegrationContext()` hook + sidebar switching |
| **11** | 2 days | SchedulePage (visits) + ClientsPage |
| **12** | 2 days | ClientDetailPage with tabbed Jobber data |
| **13** | 1 day | JobsPage + Dashboard widgets |

**Total: ~2-2.5 weeks** (backend ~1 week, frontend ~1-1.5 weeks, can overlap)
