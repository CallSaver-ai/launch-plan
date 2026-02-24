# Housecall Pro Voice Agent: Exhaustive Customer Intent Analysis

> Created: Feb 17, 2026
> Status: Complete analysis of all caller intents mapped to Housecall Pro API endpoints
> Source: OpenAPI spec extracted from `housecall.v1.yaml` via Stoplight API
> Spec: `https://housecallpro.stoplight.io/api/v1/projects/housecallpro/housecall-public-api/nodes/reference/housecall.v1.yaml?branch=master&deref=optimizedBundle`

---

## Housecall Pro vs Jobber: Entity Model Comparison

| HCP Entity | Jobber Equivalent | Key Differences |
|------------|-------------------|-----------------|
| **Customer** | Client | HCP uses "Customer". Addresses are a sub-resource (`POST /customers/{id}/addresses`). |
| **Address** | Property | HCP addresses are sub-resources of Customer, not fully independent. Created via dedicated endpoint. |
| **Lead** | Request | HCP Lead = prospective work. Can be converted to Job or Estimate via `POST /leads/{id}/convert`. |
| **Estimate** | Quote + Assessment | HCP Estimate is scheduled & dispatched. Has options with line items. Approve/decline via API. |
| **Job** | Job | HCP Job is the work order. Has schedule, line items, notes, tags, attachments. |
| **Appointment** | Visit | HCP Appointments are children of Jobs — the actual scheduled time slots. Full CRUD. |
| **Invoice** | Invoice | Similar. HCP has `GET /invoices` list + `GET /api/invoices/{uuid}` single + preview. |
| **Employee** | — (assignedUsers) | HCP exposes full Employee entity with permissions. Jobs dispatched to employees. |
| **Company** | — | The HCP business account. Has schedule availability and booking windows. |
| **Event** | — | Calendar events (non-job). Has schedule, assigned employees, recurrence. |
| **Tag** | — | Tagging system for jobs, customers, leads. Full CRUD. |
| **Lead Source** | — | Tracks where leads come from. Full CRUD. |
| **Job Type** | — | Categorizes jobs. Full CRUD. |
| **Price Book Service** | ProductOrService | Service catalog with pricing, materials, labor rates. |
| **Service Zone** | — | Geographic service areas with zip codes. Filterable by zip/address. |

### Entity Flow (typical)
```
Caller → Lead ──convert──→ Estimate ──approve──→ Job → Appointment(s) → Invoice
                    └──convert──→ Job (direct, skip estimate)
```

### Key Architectural Differences from Jobber

1. **REST API** (not GraphQL) — simpler HTTP calls, paginated with `page` and `page_size` params
2. **Appointments exist** — Jobs have child Appointments (like Jobber's Visits), full CRUD
3. **Lead conversion** — `POST /leads/{id}/convert` creates Job or Estimate from Lead
4. **Estimate approve/decline** — `POST /estimates/options/approve` and `/decline` endpoints exist
5. **Booking Windows** — `GET /company/schedule_availability/booking_windows` = dedicated availability API
6. **Price Book** — `GET /api/price_book/services` = service catalog with pricing (like Jobber's ProductOrService)
7. **Service Zones** — `GET /service_zones?zip_code=X` = service area check
8. **Job schedule CRUD** — `PUT /jobs/{id}/schedule` and `DELETE /jobs/{id}/schedule`
9. **Authentication**: API Key (`Token <key>`) or OAuth 2.0 Bearer token

---

## HCP API: Complete Endpoint Inventory (83 endpoints from OpenAPI spec)

### Application (3)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/application` | Get Application |
| `POST` | `/application/enable` | Enable Application |
| `POST` | `/application/disable` | Disable Application |

### Customers (7)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/customers` | Get Customers |
| `POST` | `/customers` | Create a Customer |
| `GET` | `/customers/{customer_id}` | Get a Customer |
| `PUT` | `/customers/{customer_id}` | Update a Customer |
| `GET` | `/customers/{customer_id}/addresses` | Get a Customer's Addresses |
| `POST` | `/customers/{customer_id}/addresses` | Create an Address on a Customer |
| `GET` | `/customers/{customer_id}/addresses/{address_id}` | Get a Customer's Address |

**Query params for GET /customers**: `q` (search), `phone`, `email`, `page`, `page_size`, `sort_by`, `sort_direction`, `tag_ids`, `location_ids`

### Employees (1)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/employees` | Get Employees |

### Jobs (20)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/jobs` | Get Jobs |
| `POST` | `/jobs` | Create a Job |
| `GET` | `/jobs/{id}` | Get a Job |
| `POST` | `/jobs/{job_id}/attachments` | Add an Attachment to a Job |
| `GET` | `/jobs/{job_id}/line_items` | Lists all line items for a job |
| `POST` | `/jobs/{job_id}/line_items` | Add a line item to a Job |
| `PUT` | `/jobs/{job_id}/line_items/bulk_update` | Bulk update a job's line items |
| `PUT` | `/jobs/{job_id}/line_items/{id}` | Update a single line item |
| `DELETE` | `/jobs/{job_id}/line_items/{id}` | Delete a single line item |
| `GET` | `/jobs/{job_id}/appointments` | Get Appointments |
| `POST` | `/jobs/{job_id}/appointments` | Create appointment |
| `PUT` | `/jobs/{job_id}/appointments/{appointment_id}` | Update Appointment |
| `DELETE` | `/jobs/{job_id}/appointments/{appointment_id}` | Delete appointment |
| `PUT` | `/jobs/{job_id}/schedule` | Update job schedule |
| `DELETE` | `/jobs/{job_id}/schedule` | Delete job schedule |
| `PUT` | `/jobs/{job_id}/dispatch` | Dispatch job to employees |
| `POST` | `/jobs/{job_id}/notes` | Add job note |
| `DELETE` | `/jobs/{job_id}/notes/{note_id}` | Delete job note |
| `POST` | `/jobs/{job_id}/tags` | Add job tag |
| `DELETE` | `/jobs/{job_id}/tags/{tag_id}` | Remove job tag |

**Additional**: `POST /jobs/{job_id}/links` (Create Job Link), `POST /jobs/{job_id}/lock` (Lock Job), `POST /jobs/lock` (Lock Jobs by time range), `GET /jobs/{job_id}/invoices` (Get Job Invoices), `GET /jobs/{job_id}/job_input_materials`, `PUT /jobs/{job_id}/job_input_materials/bulk_update`

**Query params for GET /jobs**: `scheduled_start_min`, `scheduled_start_max`, `scheduled_end_min`, `scheduled_end_max`, `employee_ids`, `customer_id`, `work_status` (array), `page`, `page_size`, `sort_by`, `sort_direction`, `expand` (array), `location_ids`

**Job work_status enum**: `needs scheduling`, `scheduled`, `in progress`, `complete rated`, `complete unrated`, `user canceled`, `pro canceled`

### Estimates (13)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/estimates` | Get Estimates |
| `POST` | `/estimates` | Create an estimate |
| `GET` | `/estimates/{estimate_id}` | Get a single estimate by ID |
| `POST` | `/estimates/{estimate_id}/options/{option_id}/attachments` | Create Estimate option attachment |
| `GET` | `/estimates/{estimate_id}/options/{option_id}/line_items` | List estimate option line items |
| `PUT` | `/estimates/{estimate_id}/options/{option_id}/line_items/bulk_update` | Bulk update line items |
| `POST` | `/estimates/{estimate_id}/options/{option_id}/links` | Create Estimate option link |
| `PUT` | `/estimates/{estimate_id}/options/{option_id}/schedule` | Update estimate option schedule |
| `POST` | `/estimates/{estimate_id}/options/{option_id}/notes` | Create Estimate option note |
| `DELETE` | `/estimates/{estimate_id}/options/{option_id}/notes/{note_id}` | Delete estimate option note |
| `POST` | `/estimates/options/decline` | **Decline estimate options** |
| `POST` | `/estimates/options/approve` | **Approve estimate options** |

### Leads (5)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `POST` | `/leads` | Create Lead |
| `GET` | `/leads` | Get Leads |
| `GET` | `/leads/{id}` | Get Lead |
| `POST` | `/leads/{id}/convert` | **Convert Lead to Estimate or Job** |
| `GET` | `/leads/{lead_id}/line_items` | Lists all line items for a lead |

**Query params for GET /leads**: `employee_ids`, `customer_id`, `status` (`lost`/`open`/`won`), `page`, `page_size`, `sort_by`, `sort_direction`, `tag_ids`, `lead_source`, `location_ids`

### Invoices (3)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/invoices` | Get Invoices |
| `GET` | `/api/invoices/{uuid}` | Get Invoice by UUID |
| `GET` | `/api/invoices/{uuid}/preview` | Preview Invoice by UUID (HTML) |

**Query params for GET /invoices**: `status`, `customer_uuid`, `created_at_min/max`, `due_at_min/max`, `paid_at_min/max`, `amount_due_min/max`, `payment_method`, `page`, `page_size`

### Company & Schedule (4)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/company` | Get Company |
| `GET` | `/company/schedule_availability` | Schedule Windows |
| `PUT` | `/company/schedule_availability` | Update schedule windows |
| `GET` | `/company/schedule_availability/booking_windows` | **Booking Windows (availability)** |

**Booking Windows params**: `show_for_days`, `start_date`, `service_id`, `price_form_id`, `employee_ids`

### Events (2)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/events` | Get Events |
| `GET` | `/events/{event_id}` | Get Event by ID |

### Tags (3)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/tags` | Get tags |
| `POST` | `/tags` | Create a tag |
| `PUT` | `/tags/{tag_id}` | Update a tag |

### Lead Sources (3)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/lead_sources` | Get Lead Sources |
| `POST` | `/lead_sources` | Create lead source |
| `PUT` | `/lead_sources/{lead_source_id}` | Update Lead Source |

### Job Types (3)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/job_fields/job_types` | Get Job Types |
| `POST` | `/job_fields/job_types` | Create Job Type |
| `PUT` | `/job_fields/job_types/{job_type_id}` | Update a Job Type |

### Price Book (10)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/api/price_book/services` | **Get Price Book Services** |
| `GET` | `/api/price_book/materials` | Get Materials |
| `POST` | `/api/price_book/materials` | Create Material |
| `PUT` | `/api/price_book/materials/{uuid}` | Update Material |
| `DELETE` | `/api/price_book/materials/{uuid}` | Delete Material |
| `GET` | `/api/price_book/material_categories` | Get Material Categories |
| `POST` | `/api/price_book/material_categories` | Create Material Category |
| `PUT` | `/api/price_book/material_categories/{uuid}` | Update Material Category |
| `DELETE` | `/api/price_book/material_categories/{uuid}` | Delete Material Category |
| `GET/POST/PUT/DELETE` | `/api/price_book/price_forms[/{uuid}]` | Price Forms CRUD |

### Service Zones (1)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `GET` | `/service_zones` | **Get Service Zones** (filter by `zip_code`, `address`) |

### Webhooks (2)
| Method | Endpoint | Summary |
|--------|----------|---------|
| `POST` | `/webhooks/subscription` | Create a Webhook Subscription |
| `DELETE` | `/webhooks/subscription` | Delete a Webhook Subscription |

---

## Key Schema Definitions (from OpenAPI spec)

### Customer
```yaml
properties:
  id: string
  first_name: string (nullable)
  last_name: string (nullable)
  email: string (nullable)
  mobile_number: string (nullable)
  home_number: string (nullable)
  work_number: string (nullable)
  company: string (nullable)
  notifications_enabled: boolean
  tags: string[]
  addresses: Address[]
  lead_source: string (nullable)
  notes: Note[]
  created_at: string
  updated_at: string
  company_name: string
  company_id: string
```

### CustomerCreate
```yaml
required: [first_name]
properties:
  first_name: string
  last_name: string
  email: string
  mobile_number: string
  home_number: string
  work_number: string
  company: string
  notifications_enabled: boolean
  tags: string[]
  lead_source: string
  addresses: AddressCreate[]  # Can create addresses inline
```

### Address / AddressCreate
```yaml
properties:
  id: string          # (Address only)
  street: string
  street_line_2: string
  city: string
  state: string
  zip: string
  country: string     # (AddressCreate only)
```

### Lead
```yaml
properties:
  id: string
  note: string
  source: string
  line_items: LineItem[]
  customer:
    id, first_name, last_name, email, company, notifications_enabled,
    mobile_number, home_number, work_number, tags, lead_source
  address: { id, city, state, street, street_line_2, zip }
  lead_source: string
  tags: string[]
  assigned_employee: Employee
  status: enum [lost, open, won]
  pipeline_status: string
  company_name: string
  company_id: string
```

### LeadCreate
```yaml
properties:
  customer_id: string           # Either customer_id OR customer object required
  customer:                     # Inline customer creation
    first_name, last_name, email, mobile_number, home_number, work_number,
    company, notifications_enabled, lead_source, notes, tags,
    addresses: [{ street, street_line_2, city, state, zip }]
  assigned_employee_id: string
  address_id: string            # OR inline address
  address: { street, street_line_2, city, state, zip }
  lead_source: string
  line_items: [{ name, description, kind, quantity, unit_cost, unit_price }]
  note: string
  tags: string[]
  tax_name: string
  tax_rate: integer
```

### Job
```yaml
properties:
  id: string
  invoice_number: string
  description: string
  customer: { id, first_name, last_name, email, mobile_number, ... }
  address: Address
  notes: Note[]
  work_status: enum [needs scheduling, scheduled, in progress,
                     complete rated, complete unrated, user canceled, pro canceled]
  work_timestamps: WorkTimestamps
  schedule: Schedule  # { scheduled_start, scheduled_end, arrival_window, appointments[] }
  total_amount: integer (cents)
  outstanding_balance: integer (cents)
  subtotal: integer (cents)
  assigned_employees: Employee[]
  tags: string[]
  original_estimate_id: string (nullable)
  lead_source: string (nullable)
  job_fields: { job_type: JobType, business_unit: JobType }
  attachments: Attachment[]
  created_at: string
  updated_at: string
```

### JobCreate
```yaml
required: [customer_id, address_id]
properties:
  customer_id: string
  address_id: string
  invoice_number: number
  schedule:
    scheduled_start: string (ISO-8601)
    scheduled_end: string (ISO-8601)
    arrival_window: integer (minutes)
    anytime: boolean
    anytime_start_date: string (YYYY-MM-DD, required if anytime=true)
  assigned_employee_ids: string[]
  line_items: LineItemCreate[]
  tags: string[]
  lead_source: string
  notes: string
  job_fields: { job_type_id, business_unit_id }
```

### Appointment (child of Job)
```yaml
properties:
  id: string
  start_date: string (ISO-8601 date)
  start_time: string (ISO-8601 datetime)
  end_time: string (ISO-8601 datetime)
  anytime: boolean
  arrival_window_minutes: integer
  dispatched_employees_ids: string[]
```

### CreateAppointment
```yaml
required: [start_time, end_time, dispatched_employees_ids]
properties:
  start_time: string (ISO-8601)
  end_time: string (ISO-8601)
  arrival_window_minutes: integer
  dispatched_employees_ids: string[]
```

### Estimate
```yaml
properties:
  id: string
  estimate_number: string
  work_status: enum [needs scheduling, scheduled, in progress,
                     complete rated, complete unrated, user canceled, pro canceled]
  customer: { id, first_name, last_name, ... }
  address: Address
  schedule: Schedule
  options: EstimateOption[]
  assigned_employees: Employee[]
  tags: string[]
  lead_source: string
  created_at: string
  updated_at: string
```

### Company
```yaml
properties:
  id: string
  name: string
  support_email: string
  phone_number: string
  logo_url: string
  address: AddressCreate
  website: string
  default_arrival_window: string
  time_zone: string
  service_areas_data: ServiceAreasData
  locations: Company[]
```

---

## Webhook Events Available

| Category | Events |
|----------|--------|
| **Customer** | `customer.created`, `customer.deleted`, `customer.updated` |
| **Estimate** | `estimate.completed`, `estimate.copied_to_job`, `estimate.created`, `estimate.on_my_way`, `estimate.option_approval_status_changed`, `estimate.scheduled`, `estimate.sent` |
| **Job** | `job.canceled`, `job.completed`, `job.created`, `job.deleted`, `job.on_my_way`, `job.paid`, `job.scheduled`, `job.started` |
| **Lead** | `lead.created`, `lead.deleted`, `lead.converted`, `lead.lost`, `lead.updated` |
| **Other** | `pro.created` |

---

## Planned Internal Endpoints (CallSaver voice agent tools)

| # | Internal Endpoint | HCP API Call(s) | Jobber Equivalent |
|---|-------------------|-----------------|-------------------|
| 1 | `hcp-get-customer-by-phone` | `GET /customers?phone={phone}` | `jobber-get-client-by-phone` |
| 2 | `hcp-create-customer` | `POST /customers` | `jobber-create-client` |
| 3 | `hcp-update-customer` | `PUT /customers/{id}` | `jobber-update-client` |
| 4 | `hcp-get-customer-addresses` | `GET /customers/{id}/addresses` | `jobber-list-properties` |
| 5 | `hcp-create-address` | `POST /customers/{id}/addresses` | `jobber-create-property` |
| 6 | `hcp-create-lead` | `POST /leads` | `jobber-create-service-request` |
| 7 | `hcp-get-leads` | `GET /leads?customer_id={id}` | `jobber-get-requests` |
| 8 | `hcp-get-lead` | `GET /leads/{id}` | `jobber-get-request` |
| 9 | `hcp-submit-new-lead` | `POST /leads` with inline customer+address | `jobber-submit-new-lead` |
| 10 | `hcp-get-estimates` | `GET /estimates?customer_id={id}` | `jobber-get-request` (quote data) |
| 11 | `hcp-approve-estimate` | `POST /estimates/options/approve` | `jobber-approve-quote` (was a gap!) |
| 12 | `hcp-get-jobs` | `GET /jobs?customer_id={id}` | `jobber-get-jobs` |
| 13 | `hcp-get-job` | `GET /jobs/{id}?expand=appointments` | `jobber-get-job` |
| 14 | `hcp-add-note-to-job` | `POST /jobs/{id}/notes` | `jobber-add-note-to-job` |
| 15 | `hcp-get-appointments` | `GET /jobs/{id}/appointments` | `jobber-get-visits` |
| 16 | `hcp-reschedule-appointment` | `PUT /jobs/{id}/appointments/{appt_id}` | `jobber-reschedule-visit` |
| 17 | `hcp-cancel-appointment` | `DELETE /jobs/{id}/appointments/{appt_id}` | `jobber-cancel-visit` |
| 18 | `hcp-get-invoices` | `GET /invoices?customer_uuid={id}` | `jobber-get-invoices` |
| 19 | `hcp-get-client-balance` | `GET /jobs?customer_id={id}` → sum `outstanding_balance` | `jobber-get-client-balance` |
| 20 | `hcp-get-availability` | `GET /company/schedule_availability/booking_windows` | `jobber-get-availability` |
| 21 | `hcp-get-services` | `GET /api/price_book/services` | `jobber-get-services` |
| 22 | `hcp-check-service-area` | `GET /service_zones?zip_code={zip}` | — (was a gap in Jobber!) |
| 23 | `hcp-get-employees` | `GET /employees` | — |
| 24 | `hcp-dispatch-job` | `PUT /jobs/{id}/dispatch` | — |
| 25 | `hcp-update-job-schedule` | `PUT /jobs/{id}/schedule` | — |
| 26 | `hcp-delete-job-schedule` | `DELETE /jobs/{id}/schedule` | — |

---

## Exhaustive Customer Intent Map

### Category 1: Identity & Account Management

| # | Caller Intent (what they say) | Endpoint(s) Used | Coverage |
|---|-------------------------------|------------------|----------|
| 1 | "Hi, I'm calling about..." (identify caller) | `hcp-get-customer-by-phone` | ✅ Full |
| 2 | "I'm a new customer" | `hcp-submit-new-lead` / `hcp-create-customer` | ✅ Full |
| 3 | "I need to update my email" | `hcp-update-customer` | ✅ Full |
| 4 | "My phone number changed" | `hcp-update-customer` | ✅ Full |
| 5 | "I changed my name" | `hcp-update-customer` | ✅ Full |
| 6 | "What info do you have for me?" | `hcp-get-customer-by-phone` | ✅ Full |

### Category 2: Address / Service Location Management

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 7 | "I have a new address / I moved" | `hcp-update-customer` | ✅ Full |
| 8 | "I have a second location that needs service" | `hcp-create-address` | ✅ Full |
| 9 | "Which addresses do you have for me?" | `hcp-get-customer-addresses` | ✅ Full |
| 10 | "The address on file is wrong" | `hcp-update-customer` | ✅ Full |
| 11 | "Remove my old property" | — | ❌ **GAP**: No delete-address endpoint in spec |

### Category 3: Service Inquiry

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 12 | "What services do you offer?" | `hcp-get-services` | ✅ Full |
| 13 | "Do you do [specific service]?" | `hcp-get-services` (LLM matches) | ✅ Full |
| 14 | "How much does [service] cost?" | `hcp-get-services` (has unit_price) | ✅ Full |
| 15 | "Do you service my area?" | `hcp-check-service-area` | ✅ Full |

### Category 4: New Service Request (Lead Creation)

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 16 | "I need [service] done" | `hcp-submit-new-lead` | ✅ Full |
| 17 | "I have a leak / emergency" | `hcp-create-lead` (urgency in note) | ✅ Full |
| 18 | "Can someone come look at [problem]?" | `hcp-submit-new-lead` | ✅ Full |
| 19 | "I'd like a quote/estimate" | `hcp-submit-new-lead` → contractor creates Estimate | ✅ Full |
| 20 | "My neighbor recommended you" (referral) | `hcp-submit-new-lead` (lead_source field) | ✅ Full |

### Category 5: Lead / Estimate Status

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 21 | "What's happening with my request?" | `hcp-get-leads` / `hcp-get-lead` | ✅ Full |
| 22 | "Did you get my request?" | `hcp-get-leads` | ✅ Full |
| 23 | "When is my estimate/consultation?" | `hcp-get-estimates` (schedule on estimate) | ✅ Full |
| 24 | "Has my quote been sent?" | `hcp-get-estimates` (work_status field) | ✅ Full |
| 25 | "What's the quote amount?" | `hcp-get-estimates` (line items + total) | ✅ Full |
| 26 | "I want to approve the estimate" | `hcp-approve-estimate` | ✅ Full |
| 27 | "The quote is too high / I want to negotiate" | `hcp-add-note-to-job` | ⚠️ **Workaround**: Agent notes concern, suggests contractor follow-up |

### Category 6: Scheduling & Availability

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 28 | "When are you available?" | `hcp-get-availability` | ✅ Full |
| 29 | "Can you come [specific date]?" | `hcp-get-availability` (start_date param) | ✅ Full |
| 30 | "I need to schedule an appointment" | `hcp-get-availability` → `hcp-create-lead` | ✅ Full |
| 31 | "What's my next appointment?" | `hcp-get-jobs` + `hcp-get-appointments` | ✅ Full |
| 32 | "What appointments do I have?" | `hcp-get-jobs` (filter by customer) | ✅ Full |
| 33 | "Schedule an estimate/consultation" | `hcp-submit-new-lead` → contractor creates Estimate | ✅ Full |
| 34 | "I'm available mornings only" | `hcp-get-availability` (LLM filters AM windows) | ✅ Full |

### Category 7: Reschedule & Cancel

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 35 | "I need to reschedule" | `hcp-get-appointments` → `hcp-reschedule-appointment` | ✅ Full |
| 36 | "Can I move my appointment?" | `hcp-get-availability` → `hcp-reschedule-appointment` | ✅ Full |
| 37 | "I need to cancel my appointment" | `hcp-cancel-appointment` | ✅ Full |
| 38 | "Something came up, I can't make it" | `hcp-cancel-appointment` or `hcp-reschedule-appointment` | ✅ Full |
| 39 | "Cancel my estimate/consultation" | `hcp-delete-job-schedule` (on estimate) | ⚠️ **Partial**: Can delete schedule but not cancel estimate itself |

### Category 8: Job / Work Status

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 40 | "What's the status of my job?" | `hcp-get-jobs` / `hcp-get-job` | ✅ Full |
| 41 | "What's my job number?" | `hcp-get-jobs` (invoice_number field) | ✅ Full |
| 42 | "When will the work be done?" | `hcp-get-job` (schedule.scheduled_end) | ✅ Full |
| 43 | "Who's assigned to my job?" | `hcp-get-job` (assigned_employees) | ✅ Full |
| 44 | "I have a note about my job / special instructions" | `hcp-add-note-to-job` | ✅ Full |
| 45 | "The gate code is [X]" | `hcp-add-note-to-job` | ✅ Full |

### Category 9: Billing & Payments

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 46 | "How much do I owe?" | `hcp-get-client-balance` | ✅ Full |
| 47 | "What's my balance?" | `hcp-get-client-balance` | ✅ Full |
| 48 | "Can I see my invoices?" | `hcp-get-invoices` | ✅ Full |
| 49 | "I got an invoice, can you explain it?" | `hcp-get-invoices` (LLM reads line items) | ✅ Full |
| 50 | "When is my payment due?" | `hcp-get-invoices` (due_at field) | ✅ Full |
| 51 | "I want to pay my bill" | — | ❌ **GAP**: No payment processing via API. Direct to payment portal or transfer. |
| 52 | "Can I set up a payment plan?" | — | ❌ **GAP**: Not available in HCP API. Transfer to human. |
| 53 | "I already paid, but it's showing a balance" | — | ⚠️ **Partial**: Agent reads invoices + notes concern via `hcp-add-note-to-job`. Needs human follow-up. |

### Category 10: Complaints & Follow-up

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 54 | "I'm not happy with the work" | `hcp-add-note-to-job` + transfer | ⚠️ **Workaround**: Agent documents complaint, transfers to human |
| 55 | "The technician didn't show up" | `hcp-add-note-to-job` + transfer | ⚠️ **Workaround**: Same pattern |
| 56 | "My repair broke again" (warranty/callback) | `hcp-create-lead` | ✅ Full (creates new lead referencing original) |
| 57 | "I need to speak to a manager" | Transfer call (LiveKit) | ✅ Full (not an HCP endpoint) |
| 58 | "Is this covered under warranty?" | — | ❌ **GAP**: No warranty info in HCP API. Transfer to human. |

### Category 11: Estimate Operations

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 59 | "I'd like an estimate" | `hcp-submit-new-lead` → contractor creates Estimate | ✅ Full |
| 60 | "Can you email me a quote?" | `hcp-get-estimates` | ⚠️ **Partial**: Agent confirms it will be sent; actual send is in HCP UI |
| 61 | "I want to change my quote / add items" | — | ❌ **GAP**: No estimate-edit endpoint for voice agent. Transfer to human. |

### Category 12: General / Meta

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 62 | "What are your hours?" | `hcp-get-company` or system prompt | ✅ Full |
| 63 | "Where are you located?" | `hcp-get-company` (address field) | ✅ Full |
| 64 | "How do I leave a review?" | — | ⚠️ **System prompt**: Can be configured to provide review link |
| 65 | "I need to talk to a real person" | Transfer call (LiveKit) | ✅ Full |

---

## Coverage Summary

| Status | Count | Percentage |
|--------|-------|------------|
| ✅ **Full coverage** | 52 | 80.0% |
| ⚠️ **Partial / workaround** | 7 | 10.8% |
| ❌ **Gap (no endpoint)** | 6 | 9.2% |
| **Total intents** | **65** | 100% |

### Coverage Comparison: HCP vs Jobber

| Metric | Jobber | Housecall Pro | Delta |
|--------|--------|---------------|-------|
| Full coverage | 48 (73.8%) | 52 (80.0%) | **+4** |
| Partial/workaround | 9 (13.8%) | 7 (10.8%) | -2 |
| Gaps | 8 (12.3%) | 6 (9.2%) | **-2** |

**HCP actually has BETTER coverage than Jobber** thanks to:
1. **Booking Windows API** — dedicated availability endpoint (Jobber needs gap analysis)
2. **Estimate approve/decline** — Jobber has no quote-approve endpoint
3. **Price Book Services** — service catalog with pricing (Jobber has ProductOrService but less structured)
4. **Service Zones** — service area check by zip code (Jobber has no equivalent)
5. **Appointment CRUD** — full reschedule/cancel (Jobber has Visit CRUD too, but HCP's is cleaner REST)
6. **Company endpoint** — business hours/location from API (Jobber needs system prompt)

---

## Gaps Analysis & Recommendations

### Remaining Gaps

| Gap | Impact | Recommendation | Effort |
|-----|--------|----------------|--------|
| **Payment processing** (#51) | Medium — outside API scope | Provide HCP payment link or transfer to human | Config |
| **Payment plans** (#52) | Low — business policy | Transfer to human | N/A |
| **Warranty info** (#58) | Low — business-specific | Transfer to human | N/A |
| **Estimate editing** (#61) | Low — contractor-side | Transfer to human | N/A |
| **Address deletion** (#11) | Low — rare intent | Note: no DELETE address endpoint in spec | N/A |
| **Estimate cancel** (#39) | Low — can delete schedule | `DELETE /jobs/{id}/schedule` works for estimate schedule | Low |

### Workarounds That Are Acceptable

These intents use `hcp-add-note-to-job` as a catch-all + transfer to human:
- Pricing negotiations (#27)
- Payment disputes (#53)
- Work quality complaints (#54, #55)

---

## Voice Agent Call Flow Decision Tree

```
Inbound Call
│
├─ hcp-get-customer-by-phone
│  ├─ FOUND → "Hi [name], how can I help you?"
│  │  ├─ Scheduling → hcp-get-availability / hcp-get-appointments
│  │  ├─ Reschedule → hcp-get-appointments → hcp-reschedule-appointment
│  │  ├─ Cancel → hcp-get-appointments → hcp-cancel-appointment
│  │  ├─ Status check → hcp-get-leads / hcp-get-estimates / hcp-get-jobs
│  │  ├─ Approve estimate → hcp-approve-estimate
│  │  ├─ Billing → hcp-get-client-balance / hcp-get-invoices
│  │  ├─ New service → hcp-create-lead
│  │  ├─ Service inquiry → hcp-get-services / hcp-check-service-area
│  │  ├─ Update info → hcp-update-customer / hcp-create-address
│  │  ├─ Complaint → hcp-add-note-to-job + transfer
│  │  └─ Transfer → LiveKit warm/cold transfer
│  │
│  └─ NOT FOUND → "I don't see an account. Let me help you get started."
│     ├─ Collect name, email, phone, address, service need
│     └─ hcp-submit-new-lead (creates Customer + Address + Lead in one call)
```

---

## Entity CRUD Coverage Matrix

| Entity | Create | Read | Update | Delete | List |
|--------|--------|------|--------|--------|------|
| **Customer** | ✅ | ✅ | ✅ | — | ✅ (by phone/email/search) |
| **Address** | ✅ | ✅ | ✅ (via customer update) | ❌ | ✅ |
| **Lead** | ✅ | ✅ | — | — | ✅ |
| **Lead** (convert) | — | — | ✅ (convert to Job/Estimate) | — | — |
| **Estimate** | ✅ | ✅ | ✅ (schedule, line items, notes) | — | ✅ |
| **Estimate** (approve) | — | — | ✅ (approve/decline) | — | — |
| **Job** | ✅ | ✅ | ✅ (schedule, dispatch, notes, tags, line items) | — | ✅ |
| **Appointment** | ✅ | ✅ | ✅ | ✅ | ✅ (via job) |
| **Invoice** | — (auto) | ✅ (+ preview HTML) | — | — | ✅ |
| **Employee** | — | — | — | — | ✅ |
| **Company** | — | ✅ | — | — | — |
| **Tag** | ✅ | — | ✅ | — | ✅ |
| **Lead Source** | ✅ | — | ✅ | — | ✅ |
| **Job Type** | ✅ | — | ✅ | — | ✅ |
| **Price Book Service** | — | — | — | — | ✅ |
| **Service Zone** | — | — | — | — | ✅ |

---

## Implementation Plan

### Phase 1: Core Voice Agent (MVP) — 14 endpoints

1. **`hcp-get-customer-by-phone`** — `GET /customers?phone={phone}`
2. **`hcp-create-customer`** — `POST /customers`
3. **`hcp-update-customer`** — `PUT /customers/{id}`
4. **`hcp-get-customer-addresses`** — `GET /customers/{id}/addresses`
5. **`hcp-create-address`** — `POST /customers/{id}/addresses`
6. **`hcp-create-lead`** — `POST /leads`
7. **`hcp-submit-new-lead`** — `POST /leads` with inline customer+address
8. **`hcp-get-leads`** — `GET /leads?customer_id={id}`
9. **`hcp-get-lead`** — `GET /leads/{id}`
10. **`hcp-get-jobs`** — `GET /jobs?customer_id={id}`
11. **`hcp-get-job`** — `GET /jobs/{id}?expand=appointments`
12. **`hcp-add-note-to-job`** — `POST /jobs/{id}/notes`
13. **`hcp-get-invoices`** — `GET /invoices?customer_uuid={id}`
14. **`hcp-get-client-balance`** — `GET /jobs?customer_id={id}` → sum outstanding_balance

### Phase 2: Scheduling & Estimates — 8 endpoints

15. **`hcp-get-availability`** — `GET /company/schedule_availability/booking_windows`
16. **`hcp-get-estimates`** — `GET /estimates?customer_id={id}`
17. **`hcp-approve-estimate`** — `POST /estimates/options/approve`
18. **`hcp-get-appointments`** — `GET /jobs/{id}/appointments`
19. **`hcp-reschedule-appointment`** — `PUT /jobs/{id}/appointments/{appt_id}`
20. **`hcp-cancel-appointment`** — `DELETE /jobs/{id}/appointments/{appt_id}`
21. **`hcp-get-services`** — `GET /api/price_book/services`
22. **`hcp-check-service-area`** — `GET /service_zones?zip_code={zip}`

### Phase 3: Advanced — 4 endpoints

23. **`hcp-get-employees`** — `GET /employees`
24. **`hcp-dispatch-job`** — `PUT /jobs/{id}/dispatch`
25. **`hcp-update-job-schedule`** — `PUT /jobs/{id}/schedule`
26. **`hcp-get-company`** — `GET /company`

---

## HousecallProAdapter Architecture

Following the existing `FieldServiceAdapter` pattern in `src/adapters/field-service/`:

```
src/adapters/field-service/platforms/housecallpro/
├── HousecallProAdapter.ts    — implements FieldServiceAdapter interface
├── HousecallProClient.ts     — REST client with Nango OAuth / API key auth
└── types.ts                  — HCP-specific type definitions
```

### Key Design Decisions

1. **REST client** (not GraphQL like Jobber) — simpler HTTP fetch wrapper
2. **Nango integration** for OAuth token management (same pattern as Jobber)
3. **Address handling** — HCP has dedicated address sub-resource endpoints
4. **Lead → Request mapping** — HCP Leads map to our ServiceRequest type. LeadCreate supports inline customer+address.
5. **Estimate → Quote+Assessment mapping** — HCP Estimates map to both concepts. Approve/decline via API.
6. **Job + Appointment mapping** — HCP Jobs map to our Job, Appointments map to our Visit
7. **Booking Windows → Availability** — dedicated API, much cleaner than Jobber's gap analysis
8. **Price Book → Services** — direct mapping to our ProductOrService type

---

## OpenAPI Spec Reference

- **Spec file**: `/home/alex/production-launch-plan/housecall-pro-openapi.json`
- **Export URL**: `https://housecallpro.stoplight.io/api/v1/projects/housecallpro/housecall-public-api/nodes/reference/housecall.v1.yaml?branch=master&deref=optimizedBundle`
- **Project ID**: `cHJqOjEzMzk2MQ`
- **Branch**: `master`
- **Total endpoints**: 83
- **Total schemas**: 77
- **Base URL**: `https://api.housecallpro.com`
- **Auth**: `Token <api_key>` header or OAuth 2.0 Bearer token
