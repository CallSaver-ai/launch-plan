# ServiceTitan API Mapping — FieldServiceAdapter → ServiceTitan V2 REST

> **Version**: 2.0 — Grounded in official ServiceTitan OpenAPI specs (17 modules, 230 endpoints)
> **Status**: VERIFIED against `/home/alex/production-launch-plan/servicetitan-specs/tenant-*.yml`
> **API Base**: `https://api.servicetitan.io`
> **Auth**: OAuth 2.0 (client_credentials) + App Key + Tenant ID
> **All paths**: `/{module}/v2/tenant/{tenant}/...`

## ServiceTitan Domain Model

| Our Term | ServiceTitan Term | API Module | Notes |
|----------|-------------------|------------|-------|
| **Customer** | Customer | CRM | Bill-to party. Has contacts (phone, email). |
| **Property** | Location | CRM | Job site. Every customer has ≥1 location. No location can have >1 customer. |
| **ServiceRequest** | Booking | CRM | Incoming inquiry → Calls screen. CSR accepts → Job, or dismisses. |
| **Assessment** | Booking (type=Estimate) | CRM | Pre-sale site visit. Booked as a job with type "Estimate". |
| **Estimate** | Estimate | Sales/Estimates | Price quote. Can be approved by customer. |
| **Job** | Job | Job Planning | Record of work. Always has ≥1 appointment. |
| **Appointment** | Appointment | Job Planning | Schedule of a job: who, when. Auto-created with job. |
| **Invoice** | Invoice | Accounting | Billing document. Linked to job. |
| **Service** | Service Type / Job Type | Settings | Categorizes work (e.g., "AC Repair", "Plumbing Install"). |

### Entity Flow (typical)
```
Caller → Booking → Job (booked by CSR or API) → Appointment(s) → Invoice
                 ↘ Estimate (if needed) → Approved → Job
```

### Key Differences from Jobber
- **No separate Request entity** — ServiceTitan uses Bookings which go to the Calls screen
- **Locations are first-class** — Every job requires a customer ID AND location ID
- **Appointments are auto-created** — When you book a job, an appointment is created automatically
- **Contacts are separate** — Phone/email are Contact records on Customer or Location
- **Job types map to business units** — Must send matching values
- **Booking Provider Tags** — Required for API bookings (configured in ST settings)

---

## API Authentication

- **OAuth 2.0** with client credentials
- **Tenant ID** required in URL path: `https://api.servicetitan.io/crm/v2/tenant/{tenant_id}/...`
- **App Key** header: `ST-App-Key`
- **Nango integration**: `servicetitan` provider

---

## Adapter Method → ServiceTitan API Mapping (34 methods)

All paths below are prefixed with the API base: `https://api.servicetitan.io`
Path variable `{t}` = tenant ID (int64). All endpoints require OAuth2 Bearer token + `ST-App-Key` header.

### Customer Operations (3)

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 1 | `findCustomerByPhone` | `/crm/v2/tenant/{t}/customers?phoneNumber={phone}` | GET | tenant-crm-v2.yml |
| 2 | `createCustomer` | `/crm/v2/tenant/{t}/customers` | POST | tenant-crm-v2.yml |
| 3 | `updateCustomer` | `/crm/v2/tenant/{t}/customers/{id}` | PATCH | tenant-crm-v2.yml |

**Notes:**
- Phone is stored as a Contact record. `findCustomerByPhone` first queries `?phoneNumber=`, then enriches with `/customers/{id}/contacts`.
- `createCustomer` must also create a Location (`POST /crm/v2/tenant/{t}/locations`) — ST requires at least one.
- Customer contacts (phone/email) are separate: `POST /crm/v2/tenant/{t}/customers/{id}/contacts`, `PUT .../contacts/{contactId}`.

### Property / Location Operations (4)

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 4 | `listProperties` | `/crm/v2/tenant/{t}/locations?customerId={id}` | GET | tenant-crm-v2.yml |
| 5 | `createProperty` | `/crm/v2/tenant/{t}/locations` | POST | tenant-crm-v2.yml |
| 6 | `updateProperty` | `/crm/v2/tenant/{t}/locations/{id}` | PATCH | tenant-crm-v2.yml |
| 7 | `deleteProperty` | N/A — throw `UNSUPPORTED_OPERATION` | — | — |

**Notes:**
- ST locations cannot be deleted via API. Deactivation may be possible via PATCH (active: false).
- Location has own contacts (gate codes, on-site contact) separate from customer contacts.
- Address validation: `POST /crm/v2/tenant/{t}/locations/validate-address`.

### Service Request / Booking Operations (4)

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 8 | `createServiceRequest` | `/crm/v2/tenant/{t}/booking-provider/{bp}/bookings` | POST | tenant-crm-v2.yml |
| 9 | `getRequest` | `/crm/v2/tenant/{t}/bookings/{id}` | GET | tenant-crm-v2.yml |
| 10 | `getRequests` | `/crm/v2/tenant/{t}/bookings` | GET | tenant-crm-v2.yml |
| 11 | `submitLead` | Orchestrated: POST customers → POST locations → POST bookings | — | — |

**Notes:**
- Bookings require a **Booking Provider ID** (`{bp}` in URL path). Configured in ST Settings → Integrations.
- Booking schema: `{ name, address, contacts, summary, jobTypeId, businessUnitId, campaignId, priority, isFirstTimeClient, isSendConfirmationEmail, externalId }`.
- Booking status values: Pending, Scheduled, Dismissed. Filter: `?status=...`, `?createdOnOrAfter=...`, `?externalId=...`.
- When CSR accepts booking → automatically creates Job (booking.jobId populated).
- `PATCH /crm/v2/tenant/{t}/booking-provider/{bp}/bookings/{id}` to update.

### Assessment Operations (2)

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 12 | `createAssessment` | `/jpm/v2/tenant/{t}/jobs` with estimate-type jobTypeId | POST | tenant-jpm-v2.yml |
| 13 | `cancelAssessment` | `/jpm/v2/tenant/{t}/jobs/{id}/cancel` | PUT | tenant-jpm-v2.yml |

**Notes:**
- ST has no separate Assessment entity. An assessment = Job with a specific job type (e.g., "Free Estimate", "Site Visit").
- Cancel requires `cancelReasonId` from `GET /jpm/v2/tenant/{t}/job-cancel-reasons`.

### Job Operations (4) — includes new `cancelJob`

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 14 | `getJobs` | `/jpm/v2/tenant/{t}/jobs?customerId={id}` | GET | tenant-jpm-v2.yml |
| 15 | `getJobByNumber` | `/jpm/v2/tenant/{t}/jobs?jobNumber={num}` | GET | tenant-jpm-v2.yml |
| 16 | `addNoteToJob` | `/jpm/v2/tenant/{t}/jobs/{id}/notes` | POST | tenant-jpm-v2.yml |
| 17 | **`cancelJob`** ★ | `/jpm/v2/tenant/{t}/jobs/{id}/cancel` | PUT | tenant-jpm-v2.yml |

**Notes:**
- Cancel requires `cancelReasonId`. Fetch reasons: `GET /jpm/v2/tenant/{t}/job-cancel-reasons`.
- Job statuses: Pending, Hold, Canceled, Completed, InProgress.
- Also: `PUT /jpm/v2/tenant/{t}/jobs/{id}/hold` (with holdReasonId) for "put on hold" intent.
- Notes body: `{ text, isPinned }`.

### Appointment Operations (5)

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 18 | `checkAvailability` | `/dispatch/v2/tenant/{t}/capacity` | POST | tenant-dispatch-v2.yml |
| 19 | `createAppointment` | `/jpm/v2/tenant/{t}/appointments` | POST | tenant-jpm-v2.yml |
| 20 | `getAppointments` | `/jpm/v2/tenant/{t}/appointments?jobId={id}` | GET | tenant-jpm-v2.yml |
| 21 | `rescheduleAppointment` | `/jpm/v2/tenant/{t}/appointments/{id}/reschedule` | PUT | tenant-jpm-v2.yml |
| 22 | `cancelAppointment` | `/jpm/v2/tenant/{t}/appointments/{id}` | DELETE | tenant-jpm-v2.yml |

**Notes:**
- **Capacity API** (POST, not GET): Body `{ startsOnOrAfter, endsOnOrBefore, businessUnitIds, jobTypeId, skillBasedAvailability }`. Returns `availabilities[{ start, end, totalAvailability, openAvailability, technicians }]`.
- Create appointment: body `{ jobId, start, end, arrivalWindowStart, arrivalWindowEnd, technicianIds, specialInstructions }`.
- Appointment statuses: Scheduled, Dispatched, Working, Hold, Done, Canceled.
- Filter appointments: `?startsOnOrAfter=`, `?startsBefore=`, `?status=`, `?technicianId=`.
- Cannot DELETE the only appointment on a job. Cannot delete if timesheets exist.

### Estimate Operations (4) — includes new `getEstimates` and `declineEstimate`

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 23 | **`getEstimates`** ★ | `/sales/v2/tenant/{t}/estimates?jobId={id}` | GET | tenant-salestech-v2.yml |
| 24 | `createEstimate` | `/sales/v2/tenant/{t}/estimates` | POST | tenant-salestech-v2.yml |
| 25 | `acceptEstimate` | `/sales/v2/tenant/{t}/estimates/{id}/sell` | PUT | tenant-salestech-v2.yml |
| 26 | **`declineEstimate`** ★ | `/sales/v2/tenant/{t}/estimates/{id}/dismiss` | PUT | tenant-salestech-v2.yml |

**Notes:**
- Estimate response: `{ id, jobId, projectId, name, jobNumber, status: { value, name }, summary, soldOn, soldBy, active, items, externalLinks }`.
- Estimate items: `{ sku: { id, name, displayName, type }, description, qty, unitRate, total }`.
- `sell` = approve/accept. `dismiss` = decline/reject. `unsell` = undo approval.
- To get estimates for a customer: first get their jobs, then query estimates by jobId.

### Invoice & Billing Operations (2)

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 27 | `getInvoices` | `/accounting/v2/tenant/{t}/invoices` | GET | tenant-accounting-v2.yml |
| 28 | `getAccountBalance` | Computed from invoices | — | — |

**Notes:**
- Invoice filters: `?jobNumber=`, `?businessUnitIds=`, `?dateFrom=`, `?dateTo=`.
- No direct `?customerId=` filter on invoices — get customer's jobs first, then invoices by job.
- `getAccountBalance`: sum outstanding invoice amounts for the customer's jobs.

### Service Catalog Operations (1)

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 29 | `getServices` | `/pricebook/v2/tenant/{t}/services` | GET | tenant-pricebook-v2.yml |

**Notes:**
- Pricebook has categories (`/pricebook/v2/tenant/{t}/categories?categoryType=Services`) and services.
- Also: `/settings/v2/tenant/{t}/business-units` for department-level grouping.

### Company / Meta Operations (2) ★ NEW

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 30 | **`getCompanyInfo`** ★ | `/settings/v2/tenant/{t}/business-units` | GET | tenant-settings-v2.yml |
| 31 | **`checkServiceArea`** ★ | `/dispatch/v2/tenant/{t}/zones` (partial) | GET | tenant-dispatch-v2.yml |

**Notes:**
- `getCompanyInfo`: Returns business units with name, address. Combine with pricebook for service list.
- `checkServiceArea`: ST has dispatch zones but no direct address→zone lookup API. Implementation will query zones and attempt a match by zip code. Returns partial results — tool layer falls back to `Location.serviceAreas` if null.

### Extended Tier — Memberships (2) ★ NEW

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 32 | **`getMemberships`** ★ | `/memberships/v2/tenant/{t}/memberships?customerIds={id}` | GET | tenant-memberships-v2.yml |
| 33 | **`getMembershipTypes`** ★ | `/memberships/v2/tenant/{t}/membership-types` | GET | tenant-memberships-v2.yml |

**Notes:**
- Membership filters: `?customerIds=`, `?status=` (Active, Suspended, Expired, Canceled, Deleted), `?billingFrequency=` (OneTime, Monthly, Quarterly, Annual).
- Membership types define the plan (recurring services included, billing frequency, duration).
- Also: `GET /memberships/v2/tenant/{t}/recurring-service-events` for next service dates.
- Also: `GET /memberships/v2/tenant/{t}/recurring-services` for service details within memberships.

### Extended Tier — Tasks (1) ★ NEW

| # | Adapter Method | ST Endpoint | HTTP | Spec File |
|---|----------------|-------------|------|-----------|
| 34 | **`createTask`** ★ | `/taskmanagement/v2/tenant/{t}/tasks` | POST | tenant-task-management-v2.yml |

**Notes:**
- Task body: `{ name, description, customerId, jobId, priority (Low/Medium/High/Urgent), assignedToId, reportedById, businessUnitId, employeeTaskTypeId, employeeTaskSourceId, completeBy }`.
- Fetch task metadata first: `GET /taskmanagement/v2/tenant/{t}/data` returns employees, business units, task types, task sources, task priorities, task resolutions.
- Also: `POST /taskmanagement/v2/tenant/{t}/tasks/{id}/subtasks` for follow-up sub-tasks.

---

## Coverage Matrix (34 methods)

| Adapter Method | ST Support | Difficulty | Notes |
|----------------|-----------|------------|-------|
| findCustomerByPhone | ✅ Full | Medium | Contact search, not direct phone field |
| createCustomer | ✅ Full | Medium | Must also create Location + Contacts |
| updateCustomer | ✅ Full | Medium | Contacts updated separately |
| listProperties | ✅ Full | Easy | Direct filter by customerId |
| createProperty | ✅ Full | Easy | Direct endpoint |
| updateProperty | ✅ Full | Easy | Direct endpoint |
| deleteProperty | ❌ Unsupported | — | Locations can't be deleted via API |
| createServiceRequest | ✅ Full | Medium | Requires Booking Provider setup |
| getRequest | ✅ Full | Easy | Direct endpoint |
| getRequests | ✅ Full | Easy | Filter by status/date |
| submitLead | ✅ Full | Medium | Orchestrated: customer + location + booking |
| createAssessment | ✅ Full | Medium | Job with estimate-type jobTypeId |
| cancelAssessment | ✅ Full | Easy | Cancel the job (needs cancelReasonId) |
| getJobs | ✅ Full | Easy | Rich filtering |
| getJobByNumber | ✅ Full | Easy | Filter by jobNumber |
| addNoteToJob | ✅ Full | Easy | Direct endpoint |
| **cancelJob** ★ | ✅ Full | Easy | `PUT /jobs/{id}/cancel` (needs cancelReasonId) |
| checkAvailability | ✅ Full | Medium | `POST /dispatch/v2/.../capacity` — real-time capacity |
| createAppointment | ✅ Full | Medium | Add to existing job |
| getAppointments | ✅ Full | Easy | Rich filtering (jobId, status, date, technician) |
| rescheduleAppointment | ✅ Full | Easy | Direct endpoint |
| cancelAppointment | ⚠️ Partial | Easy | Can't delete only appointment on job |
| **getEstimates** ★ | ✅ Full | Easy | Filter by jobId |
| createEstimate | ✅ Full | Easy | Direct endpoint |
| acceptEstimate | ✅ Full | Easy | `PUT /estimates/{id}/sell` |
| **declineEstimate** ★ | ✅ Full | Easy | `PUT /estimates/{id}/dismiss` |
| getInvoices | ✅ Full | Easy | Filter by jobNumber |
| getAccountBalance | ✅ Full | Medium | Computed from invoices |
| getServices | ✅ Full | Easy | Pricebook services endpoint |
| **getCompanyInfo** ★ | ✅ Full | Easy | Business units endpoint |
| **checkServiceArea** ★ | ⚠️ Partial | Hard | Dispatch zones, no address→zone match |
| **getMemberships** ★ | ✅ Full | Easy | Direct endpoint with customerIds filter |
| **getMembershipTypes** ★ | ✅ Full | Easy | Direct endpoint |
| **createTask** ★ | ✅ Full | Medium | Needs task metadata lookup first |

**Summary: 34/34 methods mappable. 1 unsupported (deleteProperty), 2 partial (cancelAppointment, checkServiceArea).**

---

## Implementation Priority

### Phase 1: Core (get voice agent working)
1. `findCustomerByPhone` — Most complex (contact search)
2. `createCustomer` + `createProperty` — Required for new callers
3. `submitLead` — Orchestrated flow (customer + location + booking)
4. `createServiceRequest` — Requires Booking Provider ID setup
5. `getJobs` + `getAppointments` + `getRequests` — Status queries

### Phase 2: Scheduling & Estimates
6. `checkAvailability` — Dispatch capacity API
7. `createAppointment` + `rescheduleAppointment` + `cancelAppointment`
8. `getEstimates` + `createEstimate` + `acceptEstimate` + `declineEstimate`
9. `cancelJob` + `addNoteToJob`

### Phase 3: Billing, Memberships & Meta
10. `getInvoices` + `getAccountBalance`
11. `getMemberships` + `getMembershipTypes`
12. `getCompanyInfo` + `getServices` + `checkServiceArea`
13. `createTask` + `createAssessment` + `cancelAssessment`

---

## Required Setup (per ServiceTitan tenant)

1. **API Application** — Registered in ServiceTitan developer portal (Azure APIM)
2. **Booking Provider ID** — Configured in Settings → Integrations → Booking Provider Tags
3. **OAuth credentials** — Stored in Nango (`servicetitan` provider config key)
4. **Tenant ID** — Stored in `Location.externalPlatformId` or `OrganizationIntegration.config.tenantId`
5. **App Key** — Sent as `ST-App-Key` header on every request
6. **Job Type mapping** — Which jobTypeId = "assessment/estimate visit"
7. **Business Unit ID** — Required for booking jobs (from `GET /settings/v2/tenant/{t}/business-units`)
8. **Cancel Reason IDs** — From `GET /jpm/v2/tenant/{t}/job-cancel-reasons`
9. **Task metadata** — From `GET /taskmanagement/v2/tenant/{t}/data` (task types, sources, employees)
