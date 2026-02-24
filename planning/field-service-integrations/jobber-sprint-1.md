# Jobber Sprint 1: Prove the Adapter End-to-End

> Duration: 4-5 days (Day 0 is setup, Days 1-4 are implementation)
> Goal: Voice agent creates a Jobber client from an unknown caller, schedules a visit, and the frontend shows it
> Prerequisites: Jobber developer account + Jobber test account (both available)

---

## Sprint Goal

By the end of this sprint, you can:
1. Call the test phone number from an **unknown number** (not in Jobber)
2. The voice agent creates a new Jobber **client** during the call
3. The agent schedules a **job + visit** in Jobber for the new client
4. Call back — agent now **recognizes** the caller and reads back their visit
5. The **SchedulePage** in the frontend shows the visit from Jobber

This is the real-world flow: new customer calls → agent onboards them → schedules service.
No manual data entry needed in Jobber.

---

## Day 0: Nango + Jobber Connection Setup (prerequisite)

This is the plumbing that connects your Jobber test account to CallSaver via OAuth.

### Task 0.1: Verify Nango Jobber provider exists

- [ ] Log into Nango dashboard (https://app.nango.dev)
- [ ] Go to **Integrations** → check if `jobber` provider exists
- [ ] If not, create it:
  - Provider: `jobber`
  - Auth type: OAuth 2.0
  - Client ID: from your Jobber developer account → App → Credentials
  - Client Secret: from your Jobber developer account → App → Credentials
  - Scopes: (Jobber uses app-level scopes, not per-connection — check your app settings)
  - Authorization URL: `https://api.getjobber.com/api/oauth/authorize`
  - Token URL: `https://api.getjobber.com/api/oauth/token`
- [ ] Note the `provider_config_key` — should be `jobber`

### Task 0.2: Create Nango connection via OAuth flow

Two options:

**Option A: Via CallSaver frontend (recommended — tests the real flow)**
- [ ] Start local dev server (`callsaver-api` + `callsaver-frontend`)
- [ ] Start ngrok for webhooks: `ngrok http 3001`
- [ ] Update Nango webhook URL to ngrok URL + `/webhooks/nango`
- [ ] Log into CallSaver frontend as test user
- [ ] Go to Settings → Integrations → Connect Jobber
- [ ] Complete OAuth flow with your Jobber test account
- [ ] Watch server logs for `🔧 JOBBER INTEGRATION DETECTED` and `🎉 JOBBER CONNECTION CREATED SUCCESSFULLY!`

**Option B: Via Nango dashboard (faster for initial testing)**
- [ ] In Nango dashboard → Connections → Create Connection
- [ ] Provider: `jobber`
- [ ] Connection ID: something like `jobber-test-<your-org-id>`
- [ ] Complete OAuth with your Jobber test account
- [ ] Then manually create the `NangoConnection` record in your local DB:
  ```sql
  INSERT INTO nango_connections (id, connection_id, user_id, organization_id, integration_type, status, is_active, provider_config_key)
  VALUES (
    'cuid-here',
    'jobber-test-<your-org-id>',  -- must match Nango connection ID
    '<your-user-id>',
    '<your-org-id>',
    'jobber',
    'active',
    true,
    'jobber'
  );
  ```

### Task 0.3: Verify the connection works

- [ ] Check DB: `SELECT * FROM nango_connections WHERE integration_type = 'jobber';`
- [ ] Verify `is_active = true`, `status = 'active'`
- [ ] Note the `connection_id` — you'll need it for curl tests
- [ ] Quick health check (after Day 1 adapter fix):
  ```bash
  # We'll test this after fixing compile errors
  ```

### Task 0.4: Verify Jobber test account is empty (clean slate)

- [ ] Log into your Jobber test account at https://app.getjobber.com
- [ ] Check Clients list — note if any exist (OK if empty, that's the point)
- [ ] Check Schedule — should be empty
- [ ] This confirms: when we create clients/jobs/visits via the API, they'll show up here

**Day 0 exit criteria:** `NangoConnection` record exists with `integrationType: 'jobber'`,
`isActive: true`, and the Nango dashboard shows a valid OAuth token for the connection.

---

## Day 1: Fix Adapter + Creation Endpoints

The test flow is **creation-first**: the agent creates data in Jobber, not reads pre-existing data.

### Task 1.1: Fix compile errors (30 min)

- [ ] Add `CallerContext` interface to `src/types/field-service.ts`
- [ ] Fix import path in `JobberAdapter.ts` line 45: `'../../../types/field-service'` → `'../../../../types/field-service'`
- [ ] Fix null/undefined in `FieldServiceAdapterRegistry.ts` line 51
- [ ] Run `npx tsc --noEmit 2>&1 | grep "field-service"` — expect 0 errors

### Task 1.2: Restore `getFieldServiceAdapter()` helper (15 min)

- [ ] Add import for `FieldServiceAdapterRegistry` at top of `server.ts`
- [ ] Add import for `normalizeToE164` from `phoneVerification.ts`
- [ ] Add `getFieldServiceAdapter(locationId)` function to `server.ts`

### Task 1.3: Create `POST /internal/tools/jobber-get-customer-by-phone` (30 min)

- [ ] Accepts: `{ locationId, callerPhoneNumber }`
- [ ] Calls `adapter.findCustomerByPhone(context)`
- [ ] Returns: `{ customer, found: boolean, message }` — voice-friendly
- [ ] When not found: `{ customer: null, found: false, message: "No client found for this phone number." }`

### Task 1.4: Create `POST /internal/tools/jobber-create-customer` (30 min)

This is the key creation endpoint — the agent calls this when a caller isn't in Jobber.

- [ ] Accepts: `{ locationId, callerPhoneNumber, firstName, lastName, email?, address? }`
- [ ] Calls `adapter.createCustomer(context, data)`
- [ ] The adapter already:
  - Uses `callerPhoneNumber` as the primary phone
  - Creates a `clientProperty` if address is provided
  - Returns the full Customer object
- [ ] Returns: `{ customer, message: "Created new client: [name]. Jobber ID: [id]." }`

### Task 1.5: Create `POST /internal/tools/jobber-create-appointment` (30 min)

This creates a Job + Visit in one call (the adapter auto-creates a Job if none provided).

- [ ] Accepts: `{ locationId, callerPhoneNumber, customerId, serviceType, startTime, endTime, notes?, address? }`
- [ ] Calls `adapter.createAppointment(context, data)`
- [ ] The adapter already:
  - Auto-creates a Job if no `jobId` provided
  - Creates a Visit under that Job via `visitCreate` GraphQL mutation
  - Assigns team members if `technicianId` provided
- [ ] Returns: `{ appointment, job, message: "Scheduled [serviceType] for [date] at [time]." }`

### Task 1.6: Create `POST /internal/tools/jobber-get-appointments` (30 min)

- [ ] Accepts: `{ locationId, callerPhoneNumber, customerId }`
- [ ] Calls `adapter.getAppointments(context, customerId)`
- [ ] Returns: `{ appointments, message }` — lists upcoming visits naturally

### Task 1.7: Test the full creation flow with curl (45 min)

```bash
export API_URL=http://localhost:3001
export API_KEY=<your-internal-api-key>
export LOC_ID=<your-test-location-id>
export PHONE="+15551234567"  # Use a real test number

# Step 1: Look up caller — should return found: false
curl -s -X POST $API_URL/internal/tools/jobber-get-customer-by-phone \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"locationId\": \"$LOC_ID\", \"callerPhoneNumber\": \"$PHONE\"}" | jq .

# Step 2: Create the client
curl -s -X POST $API_URL/internal/tools/jobber-create-customer \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"locationId\": \"$LOC_ID\", \"callerPhoneNumber\": \"$PHONE\", \"firstName\": \"Test\", \"lastName\": \"Caller\"}" | jq .
# → Note the customer.id from the response

# Step 3: Schedule a visit (creates Job + Visit)
curl -s -X POST $API_URL/internal/tools/jobber-create-appointment \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "locationId": "'$LOC_ID'",
    "callerPhoneNumber": "'$PHONE'",
    "customerId": "<customer-id-from-step-2>",
    "serviceType": "Lawn Care",
    "startTime": "2026-02-20T09:00:00-08:00",
    "endTime": "2026-02-20T10:30:00-08:00",
    "notes": "Test visit created by voice agent"
  }' | jq .

# Step 4: Look up caller again — should now return found: true
curl -s -X POST $API_URL/internal/tools/jobber-get-customer-by-phone \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"locationId\": \"$LOC_ID\", \"callerPhoneNumber\": \"$PHONE\"}" | jq .

# Step 5: Get appointments — should return the visit we just created
curl -s -X POST $API_URL/internal/tools/jobber-get-appointments \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "locationId": "'$LOC_ID'",
    "callerPhoneNumber": "'$PHONE'",
    "customerId": "<customer-id-from-step-2>"
  }' | jq .

# Step 6: Verify in Jobber UI
# → Log into https://app.getjobber.com
# → Check Clients → "Test Caller" should appear
# → Check Schedule → Visit on Feb 20 should appear
```

**Day 1 exit criteria:** All 5 curl commands succeed. New client + job + visit visible in Jobber UI.

---

## Day 2: Python Tools + Voice Agent Test

### Task 2.1: Register Jobber tool names in agent config (30 min)

- [ ] Find `getLiveKitToolsForLocation()` in `server.ts` (line ~8372)
- [ ] Replace the `console.log('archived')` with actual tool name array:
  ```typescript
  case 'jobber':
    tools.push(
      'jobber-get-customer-by-phone',
      'jobber-create-customer',
      'jobber-create-appointment',
      'jobber-get-appointments'
    );
    break;
  ```
- [ ] Verify: agent config endpoint returns Jobber tool names for test org

### Task 2.2: Create Python tool — `jobber_get_customer_by_phone.py` (45 min)

- [ ] Follow exact pattern of `google_calendar_list_events.py`
- [ ] POST to `/internal/tools/jobber-get-customer-by-phone`
- [ ] Return voice-friendly string
- [ ] When not found, return message that tells agent to ask for name and create client

### Task 2.3: Create Python tool — `jobber_create_customer.py` (45 min)

- [ ] POST to `/internal/tools/jobber-create-customer`
- [ ] Tool parameters: `first_name` (required), `last_name` (required), `email` (optional)
- [ ] `callerPhoneNumber` comes from agent context (not a tool parameter — agent already has it)
- [ ] Return: "Created new client: [name]. I can now schedule appointments for them."

### Task 2.4: Create Python tool — `jobber_create_appointment.py` (45 min)

- [ ] POST to `/internal/tools/jobber-create-appointment`
- [ ] Tool parameters: `customer_id`, `service_type`, `start_time`, `end_time`, `notes`
- [ ] Return: "Scheduled [service_type] for [date] at [time]."

### Task 2.5: Create Python tool — `jobber_get_appointments.py` (45 min)

- [ ] POST to `/internal/tools/jobber-get-appointments`
- [ ] Tool parameters: `customer_id`
- [ ] Return: voice-friendly list of upcoming visits

### Task 2.6: Register tools in `__init__.py` (15 min)

- [ ] Add imports for all 4 new tools
- [ ] Add `elif` branches in `register_tools()` for each

### Task 2.7: Voice test — new caller creation flow (30 min)

Call from a number NOT in Jobber:

1. Agent: "Hi, thanks for calling [business]. How can I help?"
2. Caller: "I'd like to schedule a lawn mowing."
3. Agent uses `jobber-get-customer-by-phone` → not found
4. Agent: "I don't have your info on file. Can I get your name?"
5. Caller: "John Smith"
6. Agent uses `jobber-create-customer` → creates client
7. Agent: "Great, I've got you set up, John. When would you like to schedule?"
8. Caller: "Next Thursday morning"
9. Agent uses `jobber-create-appointment` → creates job + visit
10. Agent: "You're all set for Thursday at 9 AM for lawn mowing."

Verify in Jobber UI: new client "John Smith" with a job and visit.

### Task 2.8: Voice test — returning caller flow (15 min)

Call again from the same number:

1. Agent uses `jobber-get-customer-by-phone` → found: John Smith
2. Agent: "Hi John! How can I help?"
3. Caller: "When is my appointment?"
4. Agent uses `jobber-get-appointments` → returns the visit
5. Agent: "You have a lawn mowing scheduled for Thursday at 9 AM."

**Day 2 exit criteria:** Both voice flows work. Client, job, and visit created via voice call
are visible in Jobber UI.

---

## Day 3: More Endpoints + SchedulePage

### Task 3.1: Create 4 more critical endpoints (2 hours)

- [ ] `POST /internal/tools/jobber-reschedule-appointment` — move a visit
- [ ] `POST /internal/tools/jobber-cancel-appointment` — cancel a visit
- [ ] `POST /internal/tools/jobber-get-jobs` — list client's jobs
- [ ] `POST /internal/tools/jobber-get-account-balance` — check what client owes

### Task 3.2: Create frontend-facing visits endpoint (1 hour)

- [ ] `GET /me/jobber/visits` — user-authenticated, returns visits with job + client context
- [ ] Uses same adapter, but authenticated via session (like `/me/calendar/events`)
- [ ] Returns normalized format with `startTime`, `endTime`, `title`, `jobNumber`, `clientName`, `propertyAddress`, `assignedTo`, `status`

### Task 3.3: Create `useIntegrationContext()` hook (30 min)

- [ ] New file: `callsaver-frontend/src/hooks/use-integration-context.ts`
- [ ] Returns `isJobber`, `isGoogleCalendar`, terminology labels, endpoint URLs

### Task 3.4: Wire SchedulePage to Jobber visits (2 hours)

- [ ] Create `useVisits()` hook that calls `GET /me/jobber/visits`
- [ ] Create `SchedulePage.tsx` (or adapt `AppointmentsPage.tsx`)
- [ ] Reuse day-grouping, route calculation, weather overlay from `CalendarEvents`
- [ ] Visit cards show: time, job number + title, client name, property, crew, status badge

### Task 3.5: Update sidebar to show "Schedule" when Jobber connected (30 min)

- [ ] Make sidebar integration-aware using `useIntegrationContext()`
- [ ] Jobber: "Schedule" → `/schedule` instead of "Appointments" → `/appointments`
- [ ] Add route in `App.tsx`: `/schedule` → `SchedulePage`

**Day 3 exit criteria:** SchedulePage shows the visits created via voice call on Day 2.

---

## Day 4: Polish + Full Voice Flow

### Task 4.1: Create Python tools for Day 3 endpoints (2 hours)

- [ ] `jobber_reschedule_appointment.py`
- [ ] `jobber_cancel_appointment.py`
- [ ] `jobber_get_jobs.py`
- [ ] `jobber_get_account_balance.py`
- [ ] Register all in `__init__.py`
- [ ] Update `getLiveKitToolsForLocation()` with all 8 tool names

### Task 4.2: E2E voice test — full lifecycle (1 hour)

- [ ] Call from unknown number → agent creates client ✅
- [ ] Agent schedules visit ✅
- [ ] Call back → agent recognizes caller ✅
- [ ] "When is my appointment?" → reads visits ✅
- [ ] "I need to reschedule to Friday" → reschedules visit ✅
- [ ] "What do I owe?" → reads balance ✅
- [ ] Verify all changes in Jobber UI
- [ ] Verify SchedulePage reflects changes

### Task 4.3: E2E frontend test (30 min)

- [ ] SchedulePage loads visits from Jobber ✅
- [ ] Day grouping works ✅
- [ ] Visit cards show job context ✅
- [ ] Sidebar shows "Schedule" label ✅

### Task 4.4: Commit + deploy to staging (30 min)

- [ ] Commit recovered adapter + new endpoints + Python tools + frontend changes
- [ ] Deploy to staging
- [ ] Smoke test on staging with Jobber test account

---

## Sprint 1 Deliverables

| Deliverable | Type | Count |
|-------------|------|-------|
| Nango Jobber OAuth connection | Setup | 1 |
| Compile errors fixed | Backend | 4 fixes |
| `getFieldServiceAdapter()` helper restored | Backend | 1 function |
| `/internal/tools/jobber-*` endpoints | Backend | 8 endpoints |
| `GET /me/jobber/visits` endpoint | Backend | 1 endpoint |
| Python LiveKit tools | Agent | 8 tools |
| Tool registration in `__init__.py` | Agent | 8 registrations |
| Agent config returns Jobber tools | Backend | 1 change |
| `useIntegrationContext()` hook | Frontend | 1 hook |
| `useVisits()` hook | Frontend | 1 hook |
| SchedulePage | Frontend | 1 page |
| Sidebar integration switching | Frontend | 1 change |
| `/schedule` route | Frontend | 1 route |

## What's NOT in Sprint 1 (deferred to Sprint 2)

- Remaining 11 internal tool endpoints (properties, invoices, service requests, catalog, estimates)
- Remaining 11 Python tools
- ClientsPage (Jobber clients replacing CallersPage)
- ClientDetailPage with Jobs/Visits/Invoices tabs
- JobsPage
- Dashboard Jobber widgets
- Uncomment context injection in `utils.ts` (pre-loading caller data into system prompt)
- Frontend-facing endpoints for clients, jobs, invoices, properties

## Sprint 1 Success Criteria

1. ✅ Voice agent creates a new Jobber client from an unknown caller
2. ✅ Voice agent creates a job + visit in Jobber during the call
3. ✅ Voice agent recognizes returning callers from Jobber
4. ✅ Voice agent reads back upcoming visits from Jobber
5. ✅ Voice agent can reschedule and cancel visits
6. ✅ Voice agent can read account balance
7. ✅ SchedulePage shows Jobber visits with job context
8. ✅ Sidebar shows "Schedule" when Jobber is connected
9. ✅ All changes deployed to staging and smoke-tested
10. ✅ All created data visible in Jobber UI (clients, jobs, visits)
