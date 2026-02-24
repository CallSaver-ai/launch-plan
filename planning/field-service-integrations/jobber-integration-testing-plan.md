# Jobber Integration Testing Plan

> Created: Feb 17, 2026
> Status: Planning — tools not yet implemented, but full prior implementation recoverable from git

---

## Current State Assessment

### What EXISTS today (in active codebase)

| Layer | Component | Status |
|-------|-----------|--------|
| **Frontend** | `integrations-config.ts` — Jobber listed as available integration | ✅ Exists |
| **Frontend** | Nango OAuth connect flow for Jobber | ✅ Exists (via `sessionTokenKey: 'jobber'`) |
| **Backend** | Nango webhook handler — detects `jobber` provider, creates `NangoConnection` | ✅ Exists |
| **Backend** | `getIntegrationToolInstructions()` — returns Jobber V1 tool instructions for system prompt | ✅ Exists |
| **Backend** | `generateSystemPromptForLocationWithJobberV1()` — prompt generation with Jobber context | ✅ Exists (adapter calls commented out) |
| **Backend** | `getJobberV1ToolInstructions()` — 19 tool descriptions for LLM | ✅ Exists |
| **Backend** | Nango session token endpoint — allows `jobber` integration | ✅ Exists |

### What EXISTS in git history (recoverable — see "Recovered Code" section below)

| Layer | Component | Git Commit | Lines |
|-------|-----------|-----------|-------|
| **Backend** | `JobberAdapter` — full 4,956-line adapter with all GraphQL queries | `1d966a6c6` | 4,956 |
| **Backend** | `JobberClient` — GraphQL client with Nango OAuth token mgmt | `1d966a6c6` | 200 |
| **Backend** | `FieldServiceAdapterV1` — MVP interface (14 methods) | `1d966a6c6` | ~80 |
| **Backend** | `FieldServiceAdapterRegistry` — factory for creating adapters | `1d966a6c6` | exists |
| **Backend** | `BaseFieldServiceAdapter` — base class | `1d966a6c6` | exists |
| **Backend** | `phoneVerification.ts` — E164 normalization for Jobber | `1d966a6c6` | exists |
| **Backend** | `errors.ts` — field service error types | `1d966a6c6` | exists |
| **Backend** | 19 VAPI webhook endpoints (`/webhooks/vapi/tool/jobber-*`) | `d916c8f10~1` | ~2,000 |
| **Backend** | Archived tool list + instructions | `1061e98dc` | ~550 |
| **Docs** | `JOBBER_V1_TOOLS.md`, `TESTING.md`, `NANGO_SETUP_GUIDE.md`, etc. | `1d966a6c6` | multiple |

### What DOES NOT EXIST (must be built new)

| Layer | Component | Needed |
|-------|-----------|--------|
| **Python Agent** | Jobber tool files (`livekit-python/tools/jobber_*.py`) | ❌ None exist — only Google Calendar tools |
| **Python Agent** | Tool registration in `__init__.py` for Jobber tools | ❌ Not registered |
| **Backend** | `/internal/tools/jobber-*` API endpoints (LiveKit style, not VAPI style) | ❌ VAPI-style endpoints exist in git but need conversion |
| **Backend** | `/me/jobber/appointments` (or unified `/me/appointments`) endpoint for frontend | ❌ Only `/me/calendar/events` (Google Calendar) |
| **Frontend** | `AppointmentsPage` support for Jobber visits/jobs | ❌ Hardcoded to Google Calendar events |
| **Frontend** | `useCalendarEvents` → unified `useAppointments` hook | ❌ Only calls Google Calendar |

---

## Recovered Code from Git History

### How to recover

```bash
# Recovery commands (from ~/callsaver-api):

# 1. Full field-service adapter directory (JobberAdapter, Client, types, docs)
git checkout 1d966a6c6 -- src/adapters/field-service/

# 2. Archived tool list + prompt instructions
git show 1061e98dc:archive/jobber-square-bookings-livekit-tools.ts > /tmp/jobber-tools-archive.ts

# 3. VAPI webhook endpoints (19 Jobber tool handlers in server.ts)
#    These were at lines 9591-11130 in the pre-VAPI-removal commit:
git show d916c8f10~1:src/server.ts | sed -n '9591,11140p' > /tmp/jobber-vapi-endpoints.ts

# 4. View the node-agent code (no Jobber tools — only Google Calendar)
git show 44388424a~1:node-agent/tools/index.ts
```

### Key git commits (chronological)

| Commit | Date | Description |
|--------|------|-------------|
| `1d966a6c6` | Nov 10, 2025 | **Add property management to Jobber adapter** — last commit with full adapter code |
| `d916c8f10` | Dec 1, 2025 | **Remove VAPI integration** — deleted ~6,700 lines of VAPI webhook endpoints including all 19 Jobber tool handlers |
| `1061e98dc` | Dec 1, 2025 | **Archive Jobber and Square Bookings tool logic** — preserved tool lists + prompt instructions in `archive/` |
| `01ae21e0e` | later | **Clean up repository** — deleted the `archive/` directory |
| `44388424a` | later | **Remove node-agent** — removed Node.js agent (had no Jobber tools, only Google Calendar) |

### What the node-agent had (no Jobber)

The node-agent at `node-agent/tools/` only contained:
- `google-calendar-cancel-event.ts`
- `google-calendar-check-availability.ts`
- `google-calendar-create-event.ts`
- `google-calendar-list-events.ts`
- `google-calendar-reschedule-event.ts`
- `google-calendar-update-event-address.ts`
- `transfer-call.ts`, `validate-address.ts`, `warm-transfer.ts`, `get-caller-info.ts`

**No Jobber tools were ever implemented in the node-agent or python agent.** The Jobber tools only existed as VAPI webhook endpoints in `server.ts`.

### What the VAPI endpoints looked like (pattern to convert)

The old VAPI endpoints followed this pattern (example: `jobber-get-appointments`):

```typescript
app.post('/webhooks/vapi/tool/jobber-get-appointments', webhookTimeout, webhookRateLimit, verifyVapiWebhookAuth, async (req, res) => {
  // 1. Extract tool call from VAPI webhook format
  const { message } = req.body;
  const toolCall = message.toolCallList[0];
  const args = toolCall.function?.arguments;
  
  // 2. Find location by business phone number
  const businessNumber = message.call?.to?.phoneNumber;
  const location = await findLocationByBusinessPhoneNumber(businessNumber, false);
  
  // 3. Get field service adapter (JobberAdapter)
  const adapter = await getFieldServiceAdapter(location);
  
  // 4. Call adapter method
  const appointments = await adapter.getAppointments(context, args.customerId);
  
  // 5. Return in VAPI format
  return res.json({ results: [{ toolCallId, result: JSON.stringify(appointments) }] });
});
```

**Conversion to LiveKit `/internal/tools/` pattern:**

```typescript
app.post('/internal/tools/jobber-get-appointments', verifyInternalApiKey, async (req, res) => {
  // 1. Extract from simple JSON body (not VAPI webhook format)
  const { locationId, callerPhoneNumber, customerId } = req.body;
  
  // 2. Get location directly by ID
  const location = await prisma.location.findUnique({ where: { id: locationId } });
  
  // 3. Get field service adapter (same as before)
  const adapter = await getFieldServiceAdapter(location);
  
  // 4. Call adapter method (identical)
  const context = { callerPhoneNumber };
  const appointments = await adapter.getAppointments(context, customerId);
  
  // 5. Return formatted message for voice agent
  return res.json({ appointments, message: formatAppointmentsForVoice(appointments) });
});
```

### Recovered adapter methods (JobberAdapter — 4,956 lines)

The `JobberAdapter` at commit `1d966a6c6` implements **all 19 V1 tools** plus extras:

| Method | Lines | GraphQL Operation | Status |
|--------|-------|------------------|--------|
| `findCustomerByPhone()` | 98-222 | `clients(searchTerm)` query + fallback | ✅ Full impl |
| `getCustomer()` | 533-627 | `client(id)` query with full fields | ✅ Full impl |
| `createCustomer()` | 628-739 | `clientCreate` mutation | ✅ Full impl |
| `updateCustomer()` | 1155-1428 | `clientEdit` mutation | ✅ Full impl |
| `listProperties()` | 740-800 | `client(id).properties` query | ✅ Full impl |
| `getProperty()` | 801-892 | `property(id)` query | ✅ Full impl |
| `createProperty()` | 893-988 | `propertyCreate` mutation | ✅ Full impl |
| `updateProperty()` | 989-1105 | `propertyEdit` mutation | ✅ Full impl |
| `deleteProperty()` | 1106-1154 | `propertyDelete` mutation | ✅ Full impl |
| `getJobs()` | 1723-1802 | `jobs(filter)` query | ✅ Full impl |
| `getJob()` | 1807-1903 | `job(id)` query | ✅ Full impl |
| `createJob()` | 1914-2191 | `jobCreate` mutation | ✅ Full impl |
| `createServiceRequest()` | 2192-2400 | `requestCreate` mutation | ✅ Full impl |
| `getAppointments()` | 2701-2822 | `visits(filter)` query | ✅ Full impl |
| `getAppointment()` | 2603-2700 | `visit(id)` query | ✅ Full impl |
| `createAppointment()` | 2436-2602 | `visitCreate` mutation | ✅ Full impl |
| `rescheduleAppointment()` | 2823-2830 | delegates to `updateAppointmentTime` | ✅ Full impl |
| `updateAppointmentTime()` | 2831-3132 | `visitEdit` mutation with fallback | ✅ Full impl |
| `cancelAppointment()` | 3133-3260 | `visitCancel` mutation | ✅ Full impl |
| `getAccountBalance()` | (in adapter) | `client(id).balance` query | ✅ Full impl |
| `getInvoices()` | (in adapter) | `invoices(filter)` query | ✅ Full impl |
| `getServiceCatalog()` | (in adapter) | `productsAndServices` query | ✅ Full impl |
| `getServices()` | (in adapter) | `productsAndServices(filter)` query | ✅ Full impl |
| `getEstimate()` | 3448-3552 | `quote(id)` query | ✅ Full impl (bonus) |
| `getEstimates()` | 3553-3668 | `quotes(filter)` query | ✅ Full impl (bonus) |
| `createEstimate()` | 3261-3447 | `quoteCreate` mutation | ✅ Full impl (bonus) |

---

## Architecture: How Google Calendar Works (Reference Pattern)

The Jobber integration should follow the same architecture:

```
┌─────────────────┐     HTTP POST      ┌───────────────────────┐    Nango Proxy     ┌──────────────┐
│ LiveKit Python   │ ─────────────────→ │ CallSaver API         │ ─────────────────→ │ Google       │
│ Tool             │                    │ /internal/tools/      │   (OAuth tokens)   │ Calendar API │
│ (google_calendar │                    │ google-calendar-*     │                    │              │
│  _list_events.py)│ ←───────────────── │                       │ ←───────────────── │              │
└─────────────────┘     JSON response   └───────────────────────┘                    └──────────────┘

┌─────────────────┐     GET             ┌───────────────────────┐    Nango Proxy     ┌──────────────┐
│ Frontend         │ ─────────────────→ │ CallSaver API         │ ─────────────────→ │ Google       │
│ AppointmentsPage │                    │ /me/calendar/events   │   (OAuth tokens)   │ Calendar API │
│ (CalendarEvents) │ ←───────────────── │                       │ ←───────────────── │              │
└─────────────────┘     JSON events     └───────────────────────┘                    └──────────────┘
```

**Target Jobber pattern:**

```
┌─────────────────┐     HTTP POST      ┌───────────────────────┐    Nango Proxy     ┌──────────────┐
│ LiveKit Python   │ ─────────────────→ │ CallSaver API         │ ─────────────────→ │ Jobber       │
│ Tool             │                    │ /internal/tools/      │   (OAuth tokens)   │ GraphQL API  │
│ (jobber_get_     │                    │ jobber-*              │                    │              │
│  appointments.py)│ ←───────────────── │                       │ ←───────────────── │              │
└─────────────────┘     JSON response   └───────────────────────┘                    └──────────────┘

┌─────────────────┐     GET             ┌───────────────────────┐    Nango Proxy     ┌──────────────┐
│ Frontend         │ ─────────────────→ │ CallSaver API         │ ─────────────────→ │ Jobber       │
│ AppointmentsPage │                    │ /me/appointments      │   (OAuth tokens)   │ GraphQL API  │
│ (unified)        │ ←───────────────── │ (or /me/jobber/*)     │ ←───────────────── │              │
└─────────────────┘     JSON events     └───────────────────────┘                    └──────────────┘
```

---

## Phase 0: Jobber OAuth & Nango Connection (Prerequisite)

### 0.1 Verify Nango Jobber Provider

- [ ] Confirm `jobber` provider is configured in Nango dashboard with correct OAuth scopes
- [ ] Verify Jobber OAuth app credentials (client ID, secret) in Nango
- [ ] Required Jobber scopes: `read_clients`, `write_clients`, `read_jobs`, `write_jobs`, `read_visits`, `write_visits`, `read_invoices`, `read_requests`, `write_requests`, `read_properties`, `write_properties`
- [ ] Test: Connect Jobber from frontend integrations page → Nango OAuth flow completes → webhook fires → `NangoConnection` created with `integrationType: 'jobber'`

### 0.2 Verify Nango Proxy Works for Jobber

- [ ] Use Nango dashboard or CLI to make a test Jobber GraphQL request via proxy
- [ ] Jobber GraphQL endpoint: `https://api.getjobber.com/api/graphql`
- [ ] Test query: `{ currentUser { email { raw } } }` — confirm OAuth token is valid

---

## Phase 1: Build & Test Backend Jobber Endpoints

These are the `/internal/tools/jobber-*` endpoints the Python agent will call. Each mirrors the pattern of `/internal/tools/google-calendar-*`.

### 1.1 Jobber GraphQL Client

Build a `makeJobberGraphQLRequest()` utility (analogous to `makeGoogleCalendarRequest()` in `server.ts`):

```
Input:  nango instance, connectionId, GraphQL query, variables
Output: parsed JSON response
```

- [ ] Implement `makeJobberGraphQLRequest()` using Nango proxy
- [ ] Test: Make a raw GraphQL query against Jobber API via Nango
- [ ] Handle Jobber-specific errors (rate limits, auth expiry, GraphQL errors array)

### 1.2 Customer Endpoints

| Endpoint | Jobber GraphQL | Test |
|----------|---------------|------|
| `POST /internal/tools/jobber-get-customer-by-phone` | `clients(filter: {phones: [$phone]})` | Lookup by phone → returns customer name, email, address, ID |
| `POST /internal/tools/jobber-update-customer` | `clientEdit(clientId, input)` mutation | Update email → verify changed in Jobber |

**Tests:**
- [ ] Known phone → returns customer object with `id`, `name`, `email`, `phones`, `billingAddress`
- [ ] Unknown phone → returns empty/null (not an error)
- [ ] Update customer email → confirm via Jobber UI or re-query
- [ ] Phone number normalization (E164 ↔ Jobber format)

### 1.3 Property Endpoints

| Endpoint | Jobber GraphQL | Test |
|----------|---------------|------|
| `POST /internal/tools/jobber-list-properties` | `client(id).properties` | List all properties for customer |
| `POST /internal/tools/jobber-get-property` | `property(id)` | Get single property details |
| `POST /internal/tools/jobber-create-property` | `propertyCreate(input)` mutation | Create new property |
| `POST /internal/tools/jobber-update-property` | `propertyEdit(propertyId, input)` mutation | Update property address |
| `POST /internal/tools/jobber-delete-property` | `propertyDelete(propertyId)` mutation | Delete property |

**Tests:**
- [ ] List properties for known customer → returns array with addresses
- [ ] Create property → verify in Jobber UI
- [ ] Update property address → verify address changed
- [ ] Delete property → verify removed

### 1.4 Job Endpoints

| Endpoint | Jobber GraphQL | Test |
|----------|---------------|------|
| `POST /internal/tools/jobber-get-jobs` | `jobs(filter: {clientId: $id}, first: 10)` | List customer's jobs |
| `POST /internal/tools/jobber-get-job` | `job(id)` | Get single job details |

**Tests:**
- [ ] Customer with active jobs → returns up to 10 jobs with `title`, `status`, `jobNumber`, `startAt`, `endAt`
- [ ] Customer with no jobs → returns empty array
- [ ] Get specific job by ID → returns full job details with line items

### 1.5 Appointment/Visit Endpoints

| Endpoint | Jobber GraphQL | Test |
|----------|---------------|------|
| `POST /internal/tools/jobber-get-appointments` | `visits(filter: {clientId: $id, startAt_gte: $now}, first: 5)` | Upcoming visits |
| `POST /internal/tools/jobber-get-appointment` | `visit(id)` | Get single visit |
| `POST /internal/tools/jobber-create-appointment` | `visitCreate(input)` mutation | Schedule new visit |
| `POST /internal/tools/jobber-reschedule-appointment` | `visitEdit(visitId, input)` mutation | Reschedule visit |
| `POST /internal/tools/jobber-cancel-appointment` | `visitCancel(visitId)` mutation | Cancel visit |

> **Key terminology mapping:** Jobber calls appointments "Visits" in their API. A Visit belongs to a Job. The system prompt says "appointments" to callers but the API uses "visits."

**Tests:**
- [ ] Customer with upcoming visits → returns up to 5 visits with `startAt`, `endAt`, `title`, `status`, `assignedTo`
- [ ] Customer with no upcoming visits → returns empty array
- [ ] Create visit → verify appears in Jobber calendar
- [ ] Reschedule visit → verify time changed in Jobber
- [ ] Cancel visit → verify status changed to cancelled in Jobber
- [ ] Visit response includes job context (job title, job number)

### 1.6 Billing Endpoints

| Endpoint | Jobber GraphQL | Test |
|----------|---------------|------|
| `POST /internal/tools/jobber-get-account-balance` | `client(id).accountBalance` or sum of unpaid invoices | Balance |
| `POST /internal/tools/jobber-get-invoices` | `invoices(filter: {clientId: $id}, first: 5)` | Recent invoices |

**Tests:**
- [ ] Customer with outstanding balance → returns amount owed
- [ ] Customer with $0 balance → returns zero/paid message
- [ ] Customer with invoices → returns up to 5 with `invoiceNumber`, `total`, `amountOwing`, `status`, `issuedDate`
- [ ] Customer with no invoices → returns empty array

### 1.7 Service Request & Catalog Endpoints

| Endpoint | Jobber GraphQL | Test |
|----------|---------------|------|
| `POST /internal/tools/jobber-create-service-request` | `requestCreate(input)` mutation | New service request |
| `POST /internal/tools/jobber-get-service-catalog` | `productsAndServices(first: 50)` | Service catalog |
| `POST /internal/tools/jobber-get-services` | `productsAndServices(filter: {category: $cat})` | Filtered services |

**Tests:**
- [ ] Create service request with description and priority → verify in Jobber
- [ ] Get service catalog → returns categories and services
- [ ] Get services filtered by category → returns correct subset

### 1.8 Security: Phone Number Verification

All `/internal/tools/jobber-*` endpoints must verify the caller's phone matches the customer record (same pattern as Google Calendar's `callerPhoneNumber` extended property filtering).

- [ ] Request with matching phone → succeeds
- [ ] Request with non-matching phone → returns 403 or empty results
- [ ] Request with missing phone → returns 400

---

## Phase 2: Build & Test Python LiveKit Tools

Each tool follows the exact pattern of `google_calendar_list_events.py`:
1. Get `tool_context` from session userdata
2. POST to `/internal/tools/jobber-*` with `Authorization: Bearer {internal_api_key}`
3. Return formatted string message to LLM

### 2.1 Python Tool Files to Create

| File | Calls Endpoint | Tool Name in Agent |
|------|---------------|-------------------|
| `jobber_get_customer_by_phone.py` | `/internal/tools/jobber-get-customer-by-phone` | `get_customer_by_phone` |
| `jobber_update_customer.py` | `/internal/tools/jobber-update-customer` | `update_customer` |
| `jobber_list_properties.py` | `/internal/tools/jobber-list-properties` | `list_properties` |
| `jobber_get_property.py` | `/internal/tools/jobber-get-property` | `get_property` |
| `jobber_create_property.py` | `/internal/tools/jobber-create-property` | `create_property` |
| `jobber_update_property.py` | `/internal/tools/jobber-update-property` | `update_property` |
| `jobber_delete_property.py` | `/internal/tools/jobber-delete-property` | `delete_property` |
| `jobber_get_jobs.py` | `/internal/tools/jobber-get-jobs` | `get_jobs` |
| `jobber_get_job.py` | `/internal/tools/jobber-get-job` | `get_job` |
| `jobber_get_appointments.py` | `/internal/tools/jobber-get-appointments` | `get_appointments` |
| `jobber_get_appointment.py` | `/internal/tools/jobber-get-appointment` | `get_appointment` |
| `jobber_create_appointment.py` | `/internal/tools/jobber-create-appointment` | `create_appointment` |
| `jobber_reschedule_appointment.py` | `/internal/tools/jobber-reschedule-appointment` | `reschedule_appointment` |
| `jobber_cancel_appointment.py` | `/internal/tools/jobber-cancel-appointment` | `cancel_appointment` |
| `jobber_get_account_balance.py` | `/internal/tools/jobber-get-account-balance` | `get_account_balance` |
| `jobber_get_invoices.py` | `/internal/tools/jobber-get-invoices` | `get_invoices` |
| `jobber_create_service_request.py` | `/internal/tools/jobber-create-service-request` | `create_service_request` |
| `jobber_get_service_catalog.py` | `/internal/tools/jobber-get-service-catalog` | `get_service_catalog` |
| `jobber_get_services.py` | `/internal/tools/jobber-get-services` | `get_services` |

### 2.2 Tool Registration in `__init__.py`

Update `livekit-python/tools/__init__.py`:
- [ ] Import all `jobber_*.py` tools
- [ ] Add `elif` branches in `register_tools()` for each Jobber tool name
- [ ] Tool names should follow kebab-case pattern: `jobber-get-customer-by-phone`, `jobber-get-appointments`, etc.

### 2.3 Agent Config Must Return Jobber Tool Names

The `buildDynamicAssistantConfig()` (or wherever the agent config is built) must:
- [ ] Detect when org has Jobber integration (not Google Calendar)
- [ ] Return Jobber tool names in the `tools` array instead of `google-calendar-*` tool names
- [ ] Verify: agent config API returns correct tool names for Jobber-connected org

### 2.4 Tool-Level Tests

For each Python tool:
- [ ] Tool registers successfully when tool name is in the list
- [ ] Tool makes correct HTTP POST to the right endpoint
- [ ] Tool returns formatted string (not raw JSON) suitable for voice agent
- [ ] Tool handles timeout gracefully (15s httpx timeout)
- [ ] Tool handles API errors gracefully (returns error message, doesn't crash agent)

---

## Phase 3: End-to-End Voice Agent Tests

### 3.1 Call Flow: Identify Caller

1. [ ] Inbound call from known Jobber customer phone
2. [ ] Agent auto-calls `get_customer_by_phone` → finds customer
3. [ ] Agent greets by name: "Hi [name], how can I help you?"

### 3.2 Call Flow: Check Appointments

1. [ ] Caller: "When is my next appointment?"
2. [ ] Agent calls `get_appointments` → returns upcoming visits
3. [ ] Agent reads back visit time/date naturally

### 3.3 Call Flow: Schedule Appointment

1. [ ] Caller: "I need to schedule a visit"
2. [ ] Agent calls `get_service_catalog` → lists services
3. [ ] Caller selects service
4. [ ] Agent calls `create_appointment` with service, time, customer
5. [ ] Visit appears in Jobber calendar

### 3.4 Call Flow: Reschedule Appointment

1. [ ] Caller: "I need to move my appointment"
2. [ ] Agent calls `get_appointments` → shows current
3. [ ] Agent calls `reschedule_appointment` with new time
4. [ ] Visit updated in Jobber

### 3.5 Call Flow: Cancel Appointment

1. [ ] Caller: "Cancel my appointment"
2. [ ] Agent calls `get_appointments` → shows current
3. [ ] Agent calls `cancel_appointment`
4. [ ] Visit cancelled in Jobber

### 3.6 Call Flow: Billing

1. [ ] Caller: "What do I owe?"
2. [ ] Agent calls `get_account_balance` → returns balance
3. [ ] Agent reads balance naturally

### 3.7 Call Flow: Service Request

1. [ ] Caller: "I have a leak in my basement"
2. [ ] Agent calls `create_service_request` with description
3. [ ] Request appears in Jobber

### 3.8 Call Flow: Update Customer Info

1. [ ] Caller: "Update my email"
2. [ ] Agent calls `update_customer` with new email
3. [ ] Customer updated in Jobber

### 3.9 Call Flow: Property Management

1. [ ] Caller: "I need to add a new service location"
2. [ ] Agent collects address
3. [ ] Agent calls `create_property`
4. [ ] Property appears in Jobber

### 3.10 Call Flow: Unknown Caller

1. [ ] Inbound call from unknown phone
2. [ ] Agent calls `get_customer_by_phone` → no match
3. [ ] Agent handles gracefully (asks for name, offers to help)

---

## Phase 4: Frontend — AppointmentsPage Refactor

### 4.1 Current State (Google Calendar Only)

The data flow today:

```
AppointmentsPage.tsx
  └→ CalendarEvents component
       └→ useCalendarEvents() hook
            └→ apiClient.user.getCalendarEvents({ source: 'callsaver' })
                 └→ GET /me/calendar/events?source=callsaver
                      └→ makeGoogleCalendarRequest() → Google Calendar API
                           └→ Returns: CalendarEvent[] with Google Calendar schema
```

**Key Google Calendar schema** (used by `CalendarEvents` component):
```typescript
interface CalendarEvent {
  id: string;
  summary: string;
  start: { dateTime?: string | null; date?: string | null; timeZone?: string | null };
  end: { dateTime?: string | null; date?: string | null; timeZone?: string | null };
  location?: string;
  description?: string;
  attendees?: Array<{ email: string; displayName?: string }>;
  extendedProperties?: {
    shared?: {
      callerPhoneNumber?: string;
      callerId?: string;
    };
  };
  weather?: WeatherData | null;
}
```

### 4.2 Target State (Unified Appointments)

Two approaches to consider:

#### Option A: Unified `/me/appointments` Endpoint (Recommended)

Backend creates a single `/me/appointments` endpoint that:
1. Detects which integration the org uses (Google Calendar vs Jobber)
2. Calls the appropriate API
3. Returns a **normalized** appointment schema

```typescript
interface Appointment {
  id: string;
  title: string;                    // GCal: summary, Jobber: visit title or job title
  startTime: string;                // ISO 8601
  endTime: string;                  // ISO 8601
  timeZone: string;
  location?: string;                // GCal: location, Jobber: property address
  description?: string;             // GCal: description, Jobber: job/visit description
  status: string;                   // GCal: 'confirmed', Jobber: visit status
  source: 'google-calendar' | 'jobber';
  customer?: {
    name?: string;
    phone?: string;
    id?: string;                    // For deep-linking to caller page
  };
  // Jobber-specific
  jobNumber?: string;
  jobTitle?: string;
  assignedTo?: string[];
  // GCal-specific
  attendees?: Array<{ email: string; displayName?: string }>;
  // Shared
  weather?: WeatherData | null;
}
```

**Frontend changes:**
- [ ] Rename `useCalendarEvents` → `useAppointments` (or add new hook that delegates)
- [ ] Point to new `GET /me/appointments` endpoint
- [ ] Update `CalendarEvents` component to use `Appointment` interface
- [ ] Replace Google Calendar icon with dynamic icon based on `source`
- [ ] Map `customer.phone` → `callerPhoneNumber` for phone display
- [ ] Map `customer.id` → `callerId` for deep-linking
- [ ] Handle Jobber-specific fields: show `jobNumber` badge, `assignedTo` list

#### Option B: Frontend Integration Detection (Simpler Short-Term)

Frontend checks which integration is connected, then calls different endpoint:
- If Google Calendar → `GET /me/calendar/events` (existing)
- If Jobber → `GET /me/jobber/visits` (new)
- Frontend maps both to common display format

### 4.3 Jobber-Specific UI Considerations

Jobber visits have fields Google Calendar events don't:

| Jobber Field | UI Treatment |
|-------------|-------------|
| `jobNumber` | Show as badge: "Job #1234" |
| `visitStatus` | Color-coded badge (scheduled, in_progress, complete, cancelled) |
| `assignedTo` | Show team member names |
| `lineItems` | Optional expandable section showing services/pricing |
| Property address | Use for Street View (same as GCal `location`) |
| `invoiceStatus` | Optional badge showing payment status |

### 4.4 Frontend Tests

- [ ] Jobber-connected org → AppointmentsPage loads visits from Jobber
- [ ] Google Calendar-connected org → AppointmentsPage loads events from GCal (no regression)
- [ ] No integration connected → Shows "Connect an integration" message
- [ ] Jobber visits show job number, status, assigned team
- [ ] Street View / 3D Map works with Jobber property addresses
- [ ] Route calculation works between Jobber visits (same as GCal)
- [ ] Caller name click → navigates to caller detail page
- [ ] Phone number displays correctly
- [ ] Skeleton loading states work for Jobber
- [ ] Error states handled (Jobber API down, token expired)

---

## Phase 5: Uncomment & Activate Jobber Context Injection

The `generateSystemPromptForLocationWithJobberV1()` function in `src/utils.ts` has the Jobber adapter calls **commented out** (lines ~3263-3337). After Phases 1-2:

- [ ] Uncomment the adapter code in `generateSystemPromptForLocationWithJobberV1()`
- [ ] Build and wire `FieldServiceAdapterRegistry` and `phoneVerification.ts`
- [ ] Test: Inbound call to Jobber-connected org → system prompt includes pre-loaded customer context
- [ ] Test: Pre-loaded appointments appear in system prompt context section
- [ ] Test: Performance — prompt generation stays under 2s with Jobber context fetch

---

## Phase 6: Parity Checklist (Google Calendar ↔ Jobber)

Ensure feature parity between integrations:

| Feature | Google Calendar | Jobber | Status |
|---------|----------------|--------|--------|
| OAuth connect via Nango | ✅ | ✅ (Nango config exists) | Verify |
| Disconnect integration | ✅ | ✅ (webhook handles) | Verify |
| Switch integration (replaces old) | ✅ | ✅ (single-integration model) | Verify |
| Voice: identify caller | Via `callerPhoneNumber` extended property | Via `get_customer_by_phone` | Build |
| Voice: list appointments | `google-calendar-list-events` tool | `jobber-get-appointments` tool | Build |
| Voice: check availability | `google-calendar-check-availability` tool | *No Jobber equivalent — Jobber doesn't have freebusy* | Design decision needed |
| Voice: create appointment | `google-calendar-create-event` tool | `jobber-create-appointment` tool | Build |
| Voice: reschedule | `google-calendar-update-event` tool | `jobber-reschedule-appointment` tool | Build |
| Voice: cancel | `google-calendar-cancel-event` tool | `jobber-cancel-appointment` tool | Build |
| Voice: billing | ❌ N/A for GCal | `get_account_balance`, `get_invoices` | Build |
| Voice: service requests | ❌ N/A for GCal | `create_service_request` | Build |
| Voice: property management | ❌ N/A for GCal | `list/get/create/update/delete_property` | Build |
| Frontend: AppointmentsPage | ✅ CalendarEvents component | Needs unified adapter | Build |
| Frontend: caller card events | ✅ useCalendarEvents(phone) | Needs Jobber equivalent | Build |
| Route calculation (driving) | ✅ Using event locations | Should work with Jobber property addresses | Verify |
| Weather overlay | ✅ Weather for event locations | Should work with Jobber property addresses | Verify |

### Availability Check Design Decision

Google Calendar has a FreeBusy API. Jobber does not have an equivalent. Options:
1. **Query existing visits** — check if the requested time conflicts with existing visits
2. **Skip availability** — let the business owner manage their schedule in Jobber
3. **Hybrid** — check for visit conflicts but don't claim availability knowledge

---

## Test Accounts & Data Setup

- [ ] Jobber test/sandbox account with:
  - At least 3 customers with phone numbers
  - At least 5 jobs (mix of active, completed, cancelled)
  - At least 3 upcoming visits
  - At least 2 invoices (1 paid, 1 outstanding)
  - Service catalog with multiple categories
  - At least 2 properties per customer
- [ ] Nango `jobber` provider configured with test account credentials
- [ ] A test organization in CallSaver connected to Jobber via Nango

---

## Implementation Order (Recommended)

### Revised estimates (with recovered code from git)

The recovery of `JobberAdapter` (4,956 lines), `JobberClient` (200 lines), and the full
field-service adapter framework dramatically reduces backend work. The adapter's GraphQL
queries, type mappings, error handling, and phone verification are all production-tested
from the VAPI era. The main work is:
- **Converting** 19 VAPI webhook endpoints → 19 `/internal/tools/jobber-*` endpoints (thin wrappers)
- **Creating** 19 Python LiveKit tools (mechanical — follow `google_calendar_*.py` pattern)
- **Frontend** AppointmentsPage refactor

1. **Phase 0** — Recover adapter + verify Nango Jobber OAuth (~0.5 day)
   - `git checkout 1d966a6c6 -- src/adapters/field-service/`
   - Fix any import issues (types moved, Prisma schema changes since Nov 2025)
   - Verify Nango `jobber` provider OAuth flow works end-to-end
2. **Phase 1.1** — Restore `JobberClient` + `getFieldServiceAdapter()` (~0.5 day)
   - Already written — just needs re-integration into current codebase
   - May need Jobber GraphQL API version bump (`X-JOBBER-GRAPHQL-VERSION`)
3. **Phase 1.2-1.7** — Convert 19 VAPI endpoints → `/internal/tools/jobber-*` (~2 days)
   - Mechanical conversion: strip VAPI format, use `verifyInternalApiKey`, accept `locationId` directly
   - Add voice-friendly `message` formatting to each response
4. **Phase 2** — Create 19 Python LiveKit tools + register in `__init__.py` (~2 days)
   - Mechanical: copy `google_calendar_list_events.py` pattern, change endpoint URL + args
5. **Phase 3** — E2E voice agent tests for core flows (~1 day)
6. **Phase 4** — Frontend AppointmentsPage refactor (~2-3 days)
   - Unified `/me/appointments` endpoint
   - `useAppointments` hook
   - `CalendarEvents` component → `Appointments` component
7. **Phase 5** — Uncomment context injection in `utils.ts` (~0.5 day)
8. **Phase 6** — Full parity verification (~1 day)

**Total estimated effort: ~1.5-2 weeks** (down from ~2-3 weeks thanks to recovered adapter)
