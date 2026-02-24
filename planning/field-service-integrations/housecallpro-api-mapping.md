# Housecall Pro API Mapping to FieldServiceAdapter

> Created: Feb 17, 2026
> Status: Grounded in official OpenAPI spec (83 endpoints, 77 schemas)
> Source: `housecall-pro-openapi.json` + `housecall-pro-customer-intents-analysis.md`

---

## Housecall Pro Domain Model

| Our Term | HCP Term | API Resource | Notes |
|----------|----------|-------------|-------|
| **Customer** | Customer | `GET/POST/PUT /customers` | Has `mobile_number`, `home_number`, `work_number` (not an array). Addresses are a sub-resource. |
| **Property** | Address | `GET/POST /customers/{id}/addresses` | Dedicated sub-resource endpoints. Each address has its own `id`. |
| **ServiceRequest** | Lead | `POST /leads`, `GET /leads` | HCP Lead = prospective work. Can be converted to Job or Estimate via `POST /leads/{id}/convert`. |
| **Assessment** | Estimate (scheduled) | `POST /estimates` + schedule | HCP Estimate is scheduled & dispatched. Has options with line items. |
| **Estimate** | Estimate | `GET/POST /estimates` | Price quote with options. Approve via `POST /estimates/options/approve`. |
| **Job** | Job | `GET/POST /jobs` | Work order. Has schedule, line items, notes, tags, attachments. |
| **Appointment** | Appointment (child of Job) | `GET/POST/PUT/DELETE /jobs/{id}/appointments` | Full CRUD. Equivalent to Jobber Visits. |
| **Invoice** | Invoice | `GET /invoices`, `GET /api/invoices/{uuid}` | Read-only. Has preview HTML endpoint. |
| **Service** | Price Book Service | `GET /api/price_book/services` | Service catalog with pricing, materials, labor rates. |

### Entity Flow (typical)
```
Caller → Lead ──convert──→ Estimate ──approve──→ Job → Appointment(s) → Invoice
                    └──convert──→ Job (direct, skip estimate)
```

### Key Architectural Differences from Jobber

1. **REST API** (not GraphQL) — simpler HTTP calls, paginated with `page` and `page_size`
2. **Appointments are real entities** — Jobs have child Appointments with full CRUD (`GET/POST/PUT/DELETE /jobs/{id}/appointments`)
3. **Addresses are sub-resources** — Dedicated `POST /customers/{id}/addresses` endpoint (not embedded-only)
4. **Lead conversion** — `POST /leads/{id}/convert` creates Job or Estimate from Lead
5. **Estimate approve/decline** — `POST /estimates/options/approve` and `/decline` (Jobber has no quote-approve!)
6. **Booking Windows** — `GET /company/schedule_availability/booking_windows` = dedicated availability API
7. **Price Book** — `GET /api/price_book/services` = service catalog with pricing
8. **Service Zones** — `GET /service_zones?zip_code=X` = service area check (Jobber has no equivalent)
9. **Job schedule CRUD** — `PUT /jobs/{id}/schedule` and `DELETE /jobs/{id}/schedule`
10. **Auth**: `Token <api_key>` header or OAuth 2.0 Bearer token

### Key Schema Facts (from OpenAPI spec)

- **Customer phone fields**: `mobile_number`, `home_number`, `work_number` (separate string fields, NOT an array)
- **CustomerCreate required**: only `first_name` is required
- **JobCreate required**: `customer_id` + `address_id`
- **LeadCreate**: supports inline `customer` object OR `customer_id` — can create customer+address+lead in one call
- **Job work_status enum**: `needs scheduling`, `scheduled`, `in progress`, `complete rated`, `complete unrated`, `user canceled`, `pro canceled`
- **Appointment schema**: `{ id, start_date, start_time, end_time, anytime, arrival_window_minutes, dispatched_employees_ids }`
- **CreateAppointment required**: `start_time`, `end_time`, `dispatched_employees_ids`
- **Invoice query params**: `status`, `customer_uuid`, `created_at_min/max`, `due_at_min/max`, `amount_due_min/max`
- **Booking Windows params**: `show_for_days`, `start_date`, `service_id`, `price_form_id`, `employee_ids`

---

## API Authentication

- **API Key**: `Authorization: Token <api_key>` header
- **OAuth 2.0**: Bearer token (via Nango `housecallpro` provider)
- **Base URL**: `https://api.housecallpro.com`
- **Pagination**: `page` and `page_size` query params

---

## Adapter Method → HCP API Mapping (22 methods)

### Customer Operations (3)

| # | Adapter Method | HCP Endpoint | HTTP | Notes |
|---|----------------|-------------|------|-------|
| 1 | `findCustomerByPhone` | `GET /customers?phone={phone}` | GET | Direct phone filter. Returns paginated list. |
| 2 | `createCustomer` | `POST /customers` | POST | Body: `{ first_name, last_name, email, mobile_number, home_number, work_number, notifications_enabled, tags, lead_source, addresses: [AddressCreate] }`. Only `first_name` required. |
| 3 | `updateCustomer` | `PUT /customers/{id}` | PUT | Full replacement update (not PATCH). |

**Implementation notes:**
- Phone search uses `?phone=` query param — simplest of all 3 platforms
- Phone fields are `mobile_number`, `home_number`, `work_number` (separate strings, not array)
- Can create addresses inline with customer creation

### Property / Address Operations (4)

| # | Adapter Method | HCP Endpoint | HTTP | Notes |
|---|----------------|-------------|------|-------|
| 4 | `listProperties` | `GET /customers/{customer_id}/addresses` | GET | Dedicated endpoint! Returns array of Address objects with `id`. |
| 5 | `createProperty` | `POST /customers/{customer_id}/addresses` | POST | Body: `{ street, street_line_2, city, state, zip, country }`. Returns Address with `id`. |
| 6 | `updateProperty` | `PUT /customers/{customer_id}` | PUT | No dedicated address-update endpoint. Must update via customer update. |
| 7 | `deleteProperty` | — | — | ❌ **GAP**: No delete-address endpoint in OpenAPI spec. |

**Implementation notes:**
- `listProperties` and `createProperty` have dedicated endpoints (better than initially assumed!)
- `updateProperty` requires full customer update (read → modify address → write back)
- `deleteProperty` is a gap — no API support. Adapter should throw `UNSUPPORTED_OPERATION`.

### Service Request / Lead Operations (4)

| # | Adapter Method | HCP Endpoint | HTTP | Notes |
|---|----------------|-------------|------|-------|
| 8 | `createServiceRequest` | `POST /leads` | POST | Body: `{ customer_id, address_id, note, lead_source, line_items, tags }`. Maps to HCP Lead. |
| 9 | `getRequest` | `GET /leads/{id}` | GET | Returns Lead with customer, address, line_items, status, assigned_employee. |
| 10 | `getRequests` | `GET /leads?customer_id={id}` | GET | Filter by customer, status (`lost`/`open`/`won`), tag_ids, lead_source. |
| 11 | `submitLead` | `POST /leads` (with inline customer) | POST | LeadCreate supports inline `customer` object with addresses — creates Customer + Address + Lead in ONE call. Simplest of all 3 platforms. |

**Implementation notes:**
- HCP Leads map to our ServiceRequest type
- `POST /leads` with inline `customer` object = single-call lead submission (no orchestration needed!)
- Lead status: `lost`, `open`, `won`
- Lead conversion: `POST /leads/{id}/convert` creates Job or Estimate
- `lead_source` field for tracking origin ("CallSaver AI")

### Assessment Operations (2)

| # | Adapter Method | HCP Endpoint | HTTP | Notes |
|---|----------------|-------------|------|-------|
| 12 | `createAssessment` | `POST /estimates` + `PUT /estimates/{id}/options/{opt_id}/schedule` | POST+PUT | Create estimate, then schedule it. HCP Estimates are schedulable and dispatchable — they serve as assessments. |
| 13 | `cancelAssessment` | `DELETE /jobs/{id}/schedule` or estimate decline | DELETE | Delete the estimate's schedule. Or `POST /estimates/options/decline`. |

**Implementation notes:**
- HCP Estimate = our Assessment + Estimate combined
- Estimates have their own schedule, assigned employees, and work_status
- `POST /estimates/options/decline` can decline an estimate option
- For canceling a scheduled estimate visit: `DELETE /jobs/{id}/schedule` on the associated job

### Job Operations (3)

| # | Adapter Method | HCP Endpoint | HTTP | Notes |
|---|----------------|-------------|------|-------|
| 14 | `getJobs` | `GET /jobs` | GET | Filter: `customer_id`, `work_status` (array), `scheduled_start_min/max`, `employee_ids`, `sort_by`, `sort_direction`. |
| 15 | `getJobByNumber` | `GET /jobs/{id}` | GET | Job has `invoice_number` field. May need to search by it. |
| 16 | `addNoteToJob` | `POST /jobs/{job_id}/notes` | POST | Dedicated notes endpoint! Also `DELETE /jobs/{job_id}/notes/{note_id}`. |

**Implementation notes:**
- `work_status` enum: `needs scheduling`, `scheduled`, `in progress`, `complete rated`, `complete unrated`, `user canceled`, `pro canceled`
- Jobs have `line_items`, `assigned_employees`, `tags`, `attachments`
- Job has `outstanding_balance` field (in cents) — useful for balance calculation
- `GET /jobs/{id}` supports `?expand=appointments` to include appointment data

### Appointment Operations (5)

| # | Adapter Method | HCP Endpoint | HTTP | Notes |
|---|----------------|-------------|------|-------|
| 17 | `checkAvailability` | `GET /company/schedule_availability/booking_windows` | GET | **Dedicated availability API!** Params: `show_for_days`, `start_date`, `service_id`, `employee_ids`. Returns available booking windows. |
| 18 | `createAppointment` | `POST /jobs/{job_id}/appointments` | POST | Body: `{ start_time, end_time, dispatched_employees_ids, arrival_window_minutes }`. All 3 fields required. |
| 19 | `getAppointments` | `GET /jobs/{job_id}/appointments` | GET | Returns appointments for a specific job. For all customer appointments: `GET /jobs?customer_id={id}&expand=appointments`. |
| 20 | `rescheduleAppointment` | `PUT /jobs/{job_id}/appointments/{appointment_id}` | PUT | Update `start_time`, `end_time`, `dispatched_employees_ids`. |
| 21 | `cancelAppointment` | `DELETE /jobs/{job_id}/appointments/{appointment_id}` | DELETE | Deletes the appointment. |

**Implementation notes:**
- **Booking Windows API** is a huge advantage over Jobber (no gap analysis needed!)
- Appointments are real child entities of Jobs with full CRUD
- `CreateAppointment` requires `dispatched_employees_ids` — need employee lookup
- Appointment schema: `{ id, start_date, start_time, end_time, anytime, arrival_window_minutes, dispatched_employees_ids }`
- Can also manage job-level schedule: `PUT /jobs/{id}/schedule`, `DELETE /jobs/{id}/schedule`

### Estimate Operations (2)

| # | Adapter Method | HCP Endpoint | HTTP | Notes |
|---|----------------|-------------|------|-------|
| 22 | `createEstimate` | `POST /estimates` | POST | Creates estimate with options and line items. |
| 23 | `acceptEstimate` | `POST /estimates/options/approve` | POST | Approves estimate option(s). Also: `POST /estimates/options/decline`. |

**Implementation notes:**
- Estimates have `options` — each option has its own line items, schedule, notes
- Approve/decline operates on option IDs, not estimate ID
- Estimate `work_status` uses same enum as Jobs

### Invoice & Billing Operations (2)

| # | Adapter Method | HCP Endpoint | HTTP | Notes |
|---|----------------|-------------|------|-------|
| 24 | `getInvoices` | `GET /invoices?customer_uuid={id}` | GET | Filter by `customer_uuid`, `status`, `due_at_min/max`, `amount_due_min/max`. Also: `GET /api/invoices/{uuid}` for single + `GET /api/invoices/{uuid}/preview` for HTML. |
| 25 | `getAccountBalance` | `GET /jobs?customer_id={id}` → sum `outstanding_balance` | GET | Each Job has `outstanding_balance` (cents). Sum across active jobs. |

**Implementation notes:**
- Invoice query uses `customer_uuid` (not `customer_id`)
- Job `outstanding_balance` is in cents — divide by 100 for dollars
- Invoice has `status` field for filtering paid/unpaid

### Service Catalog Operations (1)

| # | Adapter Method | HCP Endpoint | HTTP | Notes |
|---|----------------|-------------|------|-------|
| 26 | `getServices` | `GET /api/price_book/services` | GET | Returns services with pricing, materials, labor rates. Also: `GET /api/price_book/materials` for materials. |

---

## Coverage Matrix

| Adapter Method | HCP Support | Difficulty | Notes |
|----------------|-----------|------------|-------|
| findCustomerByPhone | ✅ Full | Easy | Direct `?phone=` filter |
| createCustomer | ✅ Full | Easy | Only `first_name` required |
| updateCustomer | ✅ Full | Easy | PUT full replacement |
| listProperties | ✅ Full | Easy | Dedicated `GET /customers/{id}/addresses` |
| createProperty | ✅ Full | Easy | Dedicated `POST /customers/{id}/addresses` |
| updateProperty | ⚠️ Partial | Medium | Via customer update (no dedicated endpoint) |
| deleteProperty | ❌ Gap | — | No delete-address endpoint in spec |
| createServiceRequest | ✅ Full | Easy | `POST /leads` |
| getRequest | ✅ Full | Easy | `GET /leads/{id}` |
| getRequests | ✅ Full | Easy | `GET /leads?customer_id={id}` |
| submitLead | ✅ Full | **Very Easy** | Single `POST /leads` with inline customer+address |
| createAssessment | ✅ Full | Medium | Create estimate + schedule |
| cancelAssessment | ✅ Full | Easy | Decline estimate or delete schedule |
| getJobs | ✅ Full | Easy | Rich filtering |
| getJobByNumber | ✅ Full | Easy | `GET /jobs/{id}` |
| addNoteToJob | ✅ Full | Easy | Dedicated `POST /jobs/{id}/notes` |
| checkAvailability | ✅ Full | Easy | **Dedicated Booking Windows API!** |
| createAppointment | ✅ Full | Easy | `POST /jobs/{id}/appointments` |
| getAppointments | ✅ Full | Easy | `GET /jobs/{id}/appointments` |
| rescheduleAppointment | ✅ Full | Easy | `PUT /jobs/{id}/appointments/{id}` |
| cancelAppointment | ✅ Full | Easy | `DELETE /jobs/{id}/appointments/{id}` |
| createEstimate | ✅ Full | Easy | `POST /estimates` |
| acceptEstimate | ✅ Full | Easy | `POST /estimates/options/approve` |
| getInvoices | ✅ Full | Easy | `GET /invoices?customer_uuid={id}` |
| getAccountBalance | ✅ Full | Easy | Sum job `outstanding_balance` fields |
| getServices | ✅ Full | Easy | `GET /api/price_book/services` |

**Summary: 21/22 methods fully supported, 1 partial (updateProperty), 1 gap (deleteProperty)**

---

## HCP Advantages Over Jobber

| Feature | Jobber | HCP | Winner |
|---------|--------|-----|--------|
| Availability check | Gap analysis (complex) | Dedicated Booking Windows API | **HCP** |
| Quote/Estimate approval | ❌ No endpoint | ✅ `POST /estimates/options/approve` | **HCP** |
| Service area check | ❌ No endpoint | ✅ `GET /service_zones?zip_code=X` | **HCP** |
| Lead submission | 3 API calls (orchestrated) | 1 API call (inline customer) | **HCP** |
| Appointment CRUD | Visit CRUD (GraphQL) | Appointment CRUD (REST) | **Tie** |
| Notes endpoint | Inline on Job | Dedicated `POST /jobs/{id}/notes` | **HCP** |
| Price book | ProductOrService | Price Book Services with pricing | **HCP** |
| Overall intent coverage | 48/65 (73.8%) | 52/65 (80.0%) | **HCP** |

---

## Implementation Complexity Comparison (updated)

| Aspect | Jobber | ServiceTitan | Housecall Pro |
|--------|--------|-------------|---------------|
| **API Style** | GraphQL | REST V2 | REST V1 |
| **Auth** | OAuth (Nango) | OAuth + App Key + Tenant ID | API Key or OAuth |
| **Customer by Phone** | GraphQL query | Contact search (complex) | Direct `?phone=` filter |
| **Property Model** | Separate entity | Separate entity (Location) | Sub-resource with dedicated endpoints |
| **Service Request** | Request entity | Booking entity | Lead entity (with inline create!) |
| **Assessment** | Assessment entity | Job (estimate type) | Estimate (schedulable) |
| **Appointment** | Visit (child of Job) | Appointment (child of Job) | Appointment (child of Job) |
| **Availability** | Gap analysis | Dispatch capacity API | **Booking Windows API** |
| **Estimate Approval** | ❌ Gap | ✅ Approve endpoint | ✅ Approve endpoint |
| **Overall Complexity** | High (GraphQL) | High (many entities) | **Low (simple REST)** |

**Recommendation: Implement HCP adapter first** — simplest API, best coverage, dedicated availability endpoint, single-call lead submission.

---

## Required Setup (per HCP account)

1. **API Key** from HCP Settings → API (or OAuth via Nango)
2. **Nango connection** configured for `housecallpro` provider
3. **Lead Source** created: "CallSaver AI" via `POST /lead_sources`
4. **Tags** created: "callsaver-ai" via `POST /tags`
5. **Price Book** populated with services (source of truth for getServices)
6. **Service Zones** configured (for service area checking)
7. **Schedule Availability** configured in HCP (for Booking Windows API)

---

## Bonus: HCP-Only Endpoints (not in adapter interface but available)

These HCP endpoints could be added to the adapter later if needed:

| Endpoint | Use Case |
|----------|----------|
| `POST /leads/{id}/convert` | Convert lead to Job or Estimate |
| `GET /service_zones?zip_code=X` | Service area check |
| `PUT /jobs/{id}/dispatch` | Dispatch job to employees |
| `GET /employees` | List available technicians |
| `GET /company` | Business hours, location, timezone |
| `POST /jobs/{id}/tags` | Tag jobs for categorization |
| `GET /api/invoices/{uuid}/preview` | Invoice HTML preview |

---

## OpenAPI Spec Reference

- **Spec file**: `/home/alex/production-launch-plan/housecall-pro-openapi.json`
- **Total endpoints**: 83
- **Total schemas**: 77
- **Base URL**: `https://api.housecallpro.com`
- **Full intent analysis**: `/home/alex/production-launch-plan/planning/housecall-pro-customer-intents-analysis.md`
