# ServiceTitan Voice Agent: Exhaustive Customer Intent Analysis

> Created: Feb 17, 2026
> Status: Complete analysis of all caller intents mapped to ServiceTitan endpoints
> Platform: Azure API Management (APIM) developer portal
> Docs: https://developer.servicetitan.io
> API Base: https://api.servicetitan.io
> Auth: OAuth2 (app key + bearer token), tenant-scoped
> OpenAPI Specs: 17 modules, 230 endpoints, 480 schemas (sourced from github.com/compwright/servicetitan/spec/)

---

## ServiceTitan Entity Model

| Entity | Description | Lifecycle |
|--------|-------------|-----------|
| **Customer** | Person responsible for paying (name, type, contacts, address) | Created on first call, updated as needed |
| **Location** | Service address where work is performed | Created per address, linked to Customer (1 customer → many locations) |
| **Booking** | Incoming inquiry funneled to Calls screen for CSR follow-up | Created by voice agent → CSR accepts/dismisses |
| **Lead** | Opportunity to book a job (from inquiry that didn't convert) | Created after inquiry, follow-up tracked, converted to Won or dismissed |
| **Job** | Record of work to be done at a location | Created when booking converts, has appointments |
| **Appointment** | Schedule entry for a job (who goes, when) | Child of Job, auto-created on job booking |
| **Estimate** | Price quote built from pricebook items | Created on job, sold/dismissed/followed-up |
| **Invoice** | Billing document (many types: job, membership, POS, project, financing) | Generated from completed work |
| **Payment** | Payment record applied to invoice(s) | Created on collection |
| **Membership** | Recurring service agreement (discounts, recurring services, billing) | Sold via pricebook task, billed on schedule |
| **Project** | Folder grouping related jobs at same location | Created for multi-day/multi-visit work |
| **Technician** | Field employee using mobile app | Managed via Settings API |
| **Employee** | Office staff (CSR, dispatcher, bookkeeper) | Managed via Settings API |
| **Campaign** | Marketing attribution (tracked by phone number) | Created/managed in Marketing API |

### Entity Flow (typical)
```
Caller → Booking (CSR accepts) → Job + Appointment → Estimate → Invoice → Payment
         └─ or → Lead (follow-up) → Job
```

### Key Differences from Jobber
- **Booking** = Jobber's Request (incoming inquiry for CSR review)
- **Lead** = separate entity for inquiries that don't immediately convert
- **Appointment** = Jobber's Visit (schedule entry on a job)
- **Location** = Jobber's Property (service address)
- **Customer** = Jobber's Client
- ServiceTitan has **Capacity API** for real-time availability (Jobber uses schedule gap analysis)
- ServiceTitan has **Booking Provider** concept — each integration gets its own booking provider tag
- ServiceTitan has **Business Units** — divisions within a company (e.g., HVAC, Plumbing, Electrical)
- ServiceTitan has **Call Reasons** — categorization for why a customer is calling
- All endpoints are tenant-scoped: `/crm/v2/tenant/{tenant}/...`

---

## API Modules Overview (17 modules, 230 endpoints)

| Module | Endpoints | Key Resources | Voice Agent Relevance |
|--------|-----------|---------------|----------------------|
| **CRM v2** | 43 | Customers, Locations, Bookings, Leads, Contacts, Notes, Tags | 🔴 Critical |
| **Job Planning (JPM) v2** | 28 | Jobs, Appointments, Projects, Job Types, Cancel/Hold Reasons | 🔴 Critical |
| **Dispatch v2** | 13 | Capacity, Technician Shifts, Appointment Assignments, Non-Job Events, Zones, GPS | 🔴 Critical |
| **Sales/Estimates v2** | 10 | Estimates, Estimate Items | 🟡 Important |
| **Accounting v2** | 18 | Invoices, Payments, Payment Terms, Payment Types, Tax Zones, Bills | 🟡 Important |
| **Memberships v2** | 21 | Membership Types, Customer Memberships, Recurring Services, Recurring Service Events | 🟡 Important |
| **Telecom v2** | 5 | Calls (inbound/outbound records, recordings) | 🟡 Important |
| **Settings v2** | 8 | Employees, Technicians, Business Units, Tag Types, User Roles | 🟢 Setup |
| **Pricebook v2** | 27 | Services, Materials, Equipment, Categories, Discounts/Fees | 🟢 Reference |
| **Marketing v2** | 12 | Campaigns, Campaign Categories, Campaign Costs | 🟢 Reference |
| **Task Management v2** | 3 | Tasks, Subtasks, Client-Side Data | 🟢 Supplementary |
| **Inventory v2** | 19 | Purchase Orders, Vendors, Warehouses, Trucks, Adjustments | ⚪ Not needed |
| **Payroll v2** | 16 | Timesheets, Gross Pay, Payroll Adjustments, Activity Codes | ⚪ Not needed |
| **Equipment Systems v2** | 4 | Installed Equipment | ⚪ Not needed |
| **Scheduling Pro** | — | Schedulers, Sessions, Performance (Pro product, separate) | ⚪ Not needed |
| **Forms v2** | 1 | Job Attachments | ⚪ Not needed |
| **JBCE v2** | 1 | Call Reasons | 🟢 Reference |
| **Marketing Ads v2** | 1 | Web Booking Attributions | ⚪ Not needed |

---

## Voice-Agent-Relevant Endpoints (Detailed)

### CRM v2 — Customers, Locations, Bookings, Leads (43 endpoints)

#### Customers
| Method | Path | Description |
|--------|------|-------------|
| GET | `/crm/v2/tenant/{tenant}/customers` | List customers (filter by name, phone, email, modifiedOn, active) |
| POST | `/crm/v2/tenant/{tenant}/customers` | Create new customer (name, type, address, contacts, locations, customFields) |
| GET | `/crm/v2/tenant/{tenant}/customers/{id}` | Get customer by ID |
| PATCH | `/crm/v2/tenant/{tenant}/customers/{id}` | Update customer (name, type, address, customFields, doNotMail, doNotService, active) |
| GET | `/crm/v2/tenant/{tenant}/customers/{id}/contacts` | List customer contacts |
| POST | `/crm/v2/tenant/{tenant}/customers/{id}/contacts` | Add contact to customer (Phone, Email, Fax, MobilePhone) |
| PATCH | `/crm/v2/tenant/{tenant}/customers/{id}/contacts/{contactId}` | Update customer contact |
| DELETE | `/crm/v2/tenant/{tenant}/customers/{id}/contacts/{contactId}` | Remove customer contact |
| GET | `/crm/v2/tenant/{tenant}/customers/contacts` | List all customer contacts by modifiedOn range |
| GET | `/crm/v2/tenant/{tenant}/customers/{id}/notes` | List customer notes |
| POST | `/crm/v2/tenant/{tenant}/customers/{id}/notes` | Create customer note (text, pinToTop, addToLocations) |

**Customer Model Fields**: id, active, name, type (Residential/Commercial), address (street/unit/city/state/zip/country/lat/lng), customFields, balance, doNotMail, doNotService, createdOn, modifiedOn, mergedToId

#### Locations
| Method | Path | Description |
|--------|------|-------------|
| GET | `/crm/v2/tenant/{tenant}/locations` | List locations (filter by customer, address, active, modifiedOn) |
| POST | `/crm/v2/tenant/{tenant}/locations` | Create location (name, address, contacts, customFields, customerId) |
| GET | `/crm/v2/tenant/{tenant}/locations/{id}` | Get location by ID |
| PATCH | `/crm/v2/tenant/{tenant}/locations/{id}` | Update location (name, address, active, taxZoneId, customFields) |
| GET | `/crm/v2/tenant/{tenant}/locations/{id}/contacts` | List location contacts |
| POST | `/crm/v2/tenant/{tenant}/locations/{id}/contacts` | Add contact to location |
| PATCH | `/crm/v2/tenant/{tenant}/locations/{id}/contacts/{contactId}` | Update location contact |
| DELETE | `/crm/v2/tenant/{tenant}/locations/{id}/contacts/{contactId}` | Remove location contact |
| GET | `/crm/v2/tenant/{tenant}/locations/contacts` | List all location contacts by modifiedOn range |
| GET | `/crm/v2/tenant/{tenant}/locations/{id}/notes` | List location notes |
| POST | `/crm/v2/tenant/{tenant}/locations/{id}/notes` | Create location note |

**Location Model Fields**: id, customerId, active, name, address, customFields, taxZoneId, createdOn, modifiedOn, mergedToId

#### Bookings (via Booking Provider)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/crm/v2/tenant/{tenant}/booking-provider/{bp}/bookings` | List bookings for provider |
| POST | `/crm/v2/tenant/{tenant}/booking-provider/{bp}/bookings` | **Create booking** (name, address, contacts, summary, jobTypeId, businessUnitId, campaignId, priority, start, isSendConfirmationEmail) |
| GET | `/crm/v2/tenant/{tenant}/booking-provider/{bp}/bookings/{id}` | Get booking by ID |
| PATCH | `/crm/v2/tenant/{tenant}/booking-provider/{bp}/bookings/{id}` | Update booking |
| POST | `/crm/v2/tenant/{tenant}/booking-provider/{bp}/bookings/{id}/contacts` | Add contact to booking |
| GET | `/crm/v2/tenant/{tenant}/booking-provider/{bp}/bookings/{id}/contacts` | List booking contacts |
| PATCH | `/crm/v2/tenant/{tenant}/booking-provider/{bp}/bookings/{id}/contacts/{cid}` | Update booking contact |
| DELETE | `/crm/v2/tenant/{tenant}/booking-provider/{bp}/bookings/{id}/contacts/{cid}` | Remove booking contact |

**Tenant-level Bookings (read-only)**:
| GET | `/crm/v2/tenant/{tenant}/bookings` | List all bookings |
| GET | `/crm/v2/tenant/{tenant}/bookings/{id}` | Get booking by ID |
| GET | `/crm/v2/tenant/{tenant}/bookings/{id}/contacts` | List booking contacts |

**Booking Model Fields**: id, source, createdOn, name, address, customerType (Residential/Commercial), start, summary, campaignId, businessUnitId, isFirstTimeClient, status (New/Converted/Dismissed/Accepted), dismissingReasonId
**Booking Statuses**: New → Accepted (CSR books job) or Dismissed

#### Leads
| Method | Path | Description |
|--------|------|-------------|
| GET | `/crm/v2/tenant/{tenant}/leads` | List leads (filter by status, customer, location, modifiedOn) |
| POST | `/crm/v2/tenant/{tenant}/leads` | Create lead (customerId, locationId, summary, jobTypeId, businessUnitId, campaignId, priority, callReasonId, followUpDate) |
| GET | `/crm/v2/tenant/{tenant}/leads/{id}` | Get lead by ID |
| PATCH | `/crm/v2/tenant/{tenant}/leads/{id}` | Update lead (campaignId, priority, businessUnitId, jobTypeId) |
| POST | `/crm/v2/tenant/{tenant}/leads/{id}/dismiss` | Dismiss lead (dismissingReasonId) |
| POST | `/crm/v2/tenant/{tenant}/leads/{id}/follow-up` | Create follow-up (followUpDate, text, pinToTop) |
| GET | `/crm/v2/tenant/{tenant}/leads/{id}/notes` | List lead notes |
| POST | `/crm/v2/tenant/{tenant}/leads/{id}/notes` | Create lead note |

**Lead Model Fields**: id, status (Open/Dismissed/Converted), customerId, locationId, businessUnitId, jobTypeId, priority (Low/Normal/High/Urgent), campaignId, summary, callReasonId, followUpDate, tagTypeIds

#### Bulk Tags
| PUT | `/crm/v2/tenant/{tenant}/tags` | Add tags to multiple customers |
| DELETE | `/crm/v2/tenant/{tenant}/tags` | Remove tags from multiple customers |

---

### Job Planning & Management (JPM) v2 — Jobs, Appointments, Projects (28 endpoints)

#### Jobs
| Method | Path | Description |
|--------|------|-------------|
| GET | `/jpm/v2/tenant/{tenant}/jobs` | List jobs (filter by customer, location, status, jobNumber, completedOn, modifiedOn, appointmentStartsOn) |
| POST | `/jpm/v2/tenant/{tenant}/jobs` | **Create job** (customerId, locationId, businessUnitId, jobTypeId, priority, campaignId, appointments[], summary, customFields, tagTypeIds) |
| GET | `/jpm/v2/tenant/{tenant}/jobs/{id}` | Get job by ID |
| PATCH | `/jpm/v2/tenant/{tenant}/jobs/{id}` | Update job (customerId, locationId, summary, priority, businessUnitId, jobTypeId, customFields, tagTypeIds) |
| PUT | `/jpm/v2/tenant/{tenant}/jobs/{id}/cancel` | Cancel job (reasonId, memo) |
| PUT | `/jpm/v2/tenant/{tenant}/jobs/{id}/complete` | Complete job (completedOn) |
| PUT | `/jpm/v2/tenant/{tenant}/jobs/{id}/hold` | Put job on hold (reasonId, memo) |
| PUT | `/jpm/v2/tenant/{tenant}/jobs/{id}/remove-cancellation` | Remove job cancellation |
| GET | `/jpm/v2/tenant/{tenant}/jobs/{id}/history` | Get job history |
| GET | `/jpm/v2/tenant/{tenant}/jobs/{id}/notes` | List job notes |
| POST | `/jpm/v2/tenant/{tenant}/jobs/{id}/notes` | Create job note (text, pinToTop) |
| GET | `/jpm/v2/tenant/{tenant}/jobs/cancel-reasons` | List cancel reasons |

**Job Model Fields**: id, jobNumber, customerId, locationId, jobStatus, completedOn, businessUnitId, jobTypeId, priority, campaignId, summary, customFields, appointmentCount, firstAppointmentId, lastAppointmentId

#### Appointments
| Method | Path | Description |
|--------|------|-------------|
| GET | `/jpm/v2/tenant/{tenant}/appointments` | List appointments (filter by job, status, start/end dates) |
| POST | `/jpm/v2/tenant/{tenant}/appointments` | **Create appointment** (jobId, start, end, arrivalWindowStart, arrivalWindowEnd, technicianIds, specialInstructions) |
| GET | `/jpm/v2/tenant/{tenant}/appointments/{id}` | Get appointment by ID |
| DELETE | `/jpm/v2/tenant/{tenant}/appointments/{id}` | Delete appointment |
| PATCH | `/jpm/v2/tenant/{tenant}/appointments/{id}/reschedule` | **Reschedule** (start, end, arrivalWindowStart, arrivalWindowEnd) |
| PUT | `/jpm/v2/tenant/{tenant}/appointments/{id}/hold` | Put appointment on hold (reasonId, memo) |
| DELETE | `/jpm/v2/tenant/{tenant}/appointments/{id}/hold` | Remove appointment hold |
| PUT | `/jpm/v2/tenant/{tenant}/appointments/{id}/special-instructions` | Update special instructions |

**Appointment Model Fields**: id, jobId, appointmentNumber, start, end, arrivalWindowStart, arrivalWindowEnd, status (Scheduled/Dispatched/Working/Hold/Done/Canceled), specialInstructions, createdOn, modifiedOn

#### Job Types & Reasons
| GET | `/jpm/v2/tenant/{tenant}/job-types` | List job types |
| POST | `/jpm/v2/tenant/{tenant}/job-types` | Create job type |
| GET | `/jpm/v2/tenant/{tenant}/job-types/{id}` | Get job type |
| PATCH | `/jpm/v2/tenant/{tenant}/job-types/{id}` | Update job type |
| GET | `/jpm/v2/tenant/{tenant}/job-cancel-reasons` | List cancel reasons |
| GET | `/jpm/v2/tenant/{tenant}/job-hold-reasons` | List hold reasons |

#### Projects
| GET | `/jpm/v2/tenant/{tenant}/projects` | List projects (filter by customer, location, status, dates) |
| GET | `/jpm/v2/tenant/{tenant}/projects/{id}` | Get project by ID |

---

### Dispatch v2 — Capacity, Technicians, Assignments (13 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/dispatch/v2/tenant/{tenant}/capacity` | **Get real-time capacity/availability** (startsOnOrAfter, endsOnOrBefore, businessUnitIds) |
| GET | `/dispatch/v2/tenant/{tenant}/appointment-assignments` | List technician assignments |
| POST | `/dispatch/v2/tenant/{tenant}/appointment-assignments/assign-technicians` | Assign technicians to appointment |
| POST | `/dispatch/v2/tenant/{tenant}/appointment-assignments/unassign-technicians` | Unassign technicians |
| GET | `/dispatch/v2/tenant/{tenant}/technician-shifts` | List technician shifts |
| GET | `/dispatch/v2/tenant/{tenant}/technician-shifts/{id}` | Get specific shift |
| GET | `/dispatch/v2/tenant/{tenant}/non-job-appointments` | List non-job appointments |
| POST | `/dispatch/v2/tenant/{tenant}/non-job-appointments` | Create non-job appointment |
| GET | `/dispatch/v2/tenant/{tenant}/non-job-appointments/{id}` | Get non-job appointment |
| PUT | `/dispatch/v2/tenant/{tenant}/non-job-appointments/{id}` | Update non-job appointment |
| GET | `/dispatch/v2/tenant/{tenant}/zones` | List dispatch zones |
| GET | `/dispatch/v2/tenant/{tenant}/zones/{id}` | Get specific zone |
| POST | `/dispatch/v2/tenant/{tenant}/gps-provider/{gps}/gps-pings` | Create GPS ping |

---

### Sales & Estimates v2 (10 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/sales/v2/tenant/{tenant}/estimates` | List estimates (filter by jobId, soldBy, status, soldOnRange, totalRange) |
| POST | `/sales/v2/tenant/{tenant}/estimates` | Create estimate on a job |
| GET | `/sales/v2/tenant/{tenant}/estimates/{id}` | Get estimate by ID |
| PUT | `/sales/v2/tenant/{tenant}/estimates/{id}` | Update estimate |
| PUT | `/sales/v2/tenant/{tenant}/estimates/{id}/sell` | **Mark estimate as sold** (requires managed technician soldBy) |
| PUT | `/sales/v2/tenant/{tenant}/estimates/{id}/unsell` | Unsell estimate (only if no signature and not booked out) |
| PUT | `/sales/v2/tenant/{tenant}/estimates/{id}/dismiss` | Dismiss estimate |
| GET | `/sales/v2/tenant/{tenant}/estimates/items` | List estimate items |
| PUT | `/sales/v2/tenant/{tenant}/estimates/{id}/items` | Add/update items on estimate |
| DELETE | `/sales/v2/tenant/{tenant}/estimates/{id}/items/{itemId}` | Delete estimate item |

---

### Accounting v2 — Invoices, Payments (18 endpoints)

#### Invoices
| Method | Path | Description |
|--------|------|-------------|
| GET | `/accounting/v2/tenant/{tenant}/invoices` | List invoices (filter by job, customer, number, status, dates) |
| POST | `/accounting/v2/tenant/{tenant}/invoices` | Create adjustment invoice |
| PATCH | `/accounting/v2/tenant/{tenant}/invoices/{id}` | Update invoice |
| PATCH | `/accounting/v2/tenant/{tenant}/invoices/{invoiceId}/items` | Update invoice items |
| DELETE | `/accounting/v2/tenant/{tenant}/invoices/{invoiceId}/items/{itemId}` | Delete invoice item |
| PATCH | `/accounting/v2/tenant/{tenant}/invoices/custom-fields` | Update invoice custom fields |
| POST | `/accounting/v2/tenant/{tenant}/invoices/markasexported` | Mark invoice as exported |

#### Payments
| GET | `/accounting/v2/tenant/{tenant}/payments` | List payments (filter by invoice, customer, dates) |
| POST | `/accounting/v2/tenant/{tenant}/payments` | Create payment |
| PATCH | `/accounting/v2/tenant/{tenant}/payments/{id}` | Update payment |
| POST | `/accounting/v2/tenant/{tenant}/payments/status` | Update payment status |
| PATCH | `/accounting/v2/tenant/{tenant}/payments/custom-fields` | Update payment custom fields |

#### Reference
| GET | `/accounting/v2/tenant/{tenant}/payment-terms/{customerId}` | Get customer's default payment term |
| GET | `/accounting/v2/tenant/{tenant}/payment-types` | List payment types |
| GET | `/accounting/v2/tenant/{tenant}/payment-types/{id}` | Get payment type |
| GET | `/accounting/v2/tenant/{tenant}/tax-zones` | List tax zones and rates |
| GET | `/accounting/v2/tenant/{tenant}/inventory-bills` | List inventory bills |

---

### Memberships v2 (21 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/memberships/v2/tenant/{tenant}/membership-types` | List membership types (templates) |
| GET | `/memberships/v2/tenant/{tenant}/membership-types/{id}` | Get membership type |
| GET | `/memberships/v2/tenant/{tenant}/memberships` | List customer memberships (filter by status, customer, dates) |
| POST | `/memberships/v2/tenant/{tenant}/memberships` | Create/sell membership |
| GET | `/memberships/v2/tenant/{tenant}/memberships/{id}` | Get customer membership |
| PATCH | `/memberships/v2/tenant/{tenant}/memberships/{id}` | Update customer membership |
| GET | `/memberships/v2/tenant/{tenant}/recurring-service-types` | List recurring service types |
| GET | `/memberships/v2/tenant/{tenant}/recurring-service-types/{id}` | Get recurring service type |
| GET | `/memberships/v2/tenant/{tenant}/recurring-services` | List location recurring services |
| POST | `/memberships/v2/tenant/{tenant}/recurring-services` | Create recurring service |
| GET | `/memberships/v2/tenant/{tenant}/recurring-services/{id}` | Get recurring service |
| PATCH | `/memberships/v2/tenant/{tenant}/recurring-services/{id}` | Update recurring service |
| GET | `/memberships/v2/tenant/{tenant}/recurring-service-events` | List recurring service events |
| GET | `/memberships/v2/tenant/{tenant}/recurring-service-events/{id}` | Get recurring service event |
| + billing template and invoice template endpoints | | |

---

### Telecom v2 — Call Records (5 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/telecom/v2/tenant/{tenant}/calls` | List calls (filter by dates, direction, customer) |
| GET | `/telecom/v2/tenant/{tenant}/calls/{id}` | Get call details |
| PATCH | `/telecom/v2/tenant/{tenant}/calls/{id}` | Update call record |
| GET | `/telecom/v2/tenant/{tenant}/calls/{id}/recording` | Get call recording |
| GET | `/telecom/v2/tenant/{tenant}/calls/{id}/voicemail` | Get voicemail |

---

### Settings v2 — Employees, Technicians, Business Units (8 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/settings/v2/tenant/{tenant}/employees` | List employees (office staff) |
| GET | `/settings/v2/tenant/{tenant}/employees/{id}` | Get employee |
| GET | `/settings/v2/tenant/{tenant}/technicians` | List technicians (field staff) |
| GET | `/settings/v2/tenant/{tenant}/technicians/{id}` | Get technician |
| GET | `/settings/v2/tenant/{tenant}/business-units` | List business units |
| GET | `/settings/v2/tenant/{tenant}/business-units/{id}` | Get business unit (includes tenant info) |
| GET | `/settings/v2/tenant/{tenant}/tag-types` | List tag types |
| GET | `/settings/v2/tenant/{tenant}/user-roles` | List user roles |

---

### Reference APIs

#### Pricebook v2 (27 endpoints) — Services, Materials, Equipment catalog
- Full CRUD on Services, Materials, Equipment, Categories, Discounts/Fees
- Bulk create/update via `/pricebook/v2/tenant/{tenant}/pricebook`

#### JBCE v2 (1 endpoint)
| GET | `/jbce/v2/tenant/{tenant}/call-reasons` | List call reasons (categorization for inquiries) |

---

## Exhaustive Customer Intent Map

### Category 1: Identity & Account Management

| # | Caller Intent (what they say) | Endpoint(s) Used | Coverage |
|---|-------------------------------|------------------|----------|
| 1 | "Hi, I'm calling about..." (identify caller) | `GET /customers` (filter by phone/name) | ✅ Full |
| 2 | "I'm a new customer" | `POST /customers` (creates customer + location) | ✅ Full |
| 3 | "I need to update my email" | `PATCH /customers/{id}/contacts/{cid}` | ✅ Full |
| 4 | "My phone number changed" | `PATCH /customers/{id}/contacts/{cid}` | ✅ Full |
| 5 | "I changed my name" | `PATCH /customers/{id}` | ✅ Full |
| 6 | "What info do you have for me?" | `GET /customers/{id}` + `GET /customers/{id}/contacts` | ✅ Full |
| 7 | "I'm a commercial customer" | `POST /customers` (type: Commercial) or `PATCH /customers/{id}` | ✅ Full |

### Category 2: Location / Service Address Management

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 8 | "I have a new address / I moved" | `PATCH /locations/{id}` | ✅ Full |
| 9 | "I have a second location that needs service" | `POST /locations` (customerId) | ✅ Full |
| 10 | "Which addresses do you have for me?" | `GET /locations` (filter by customerId) | ✅ Full |
| 11 | "The address on file is wrong" | `PATCH /locations/{id}` (address fields) | ✅ Full |
| 12 | "Remove my old location" | `PATCH /locations/{id}` (active: false) | ✅ Full (deactivate) |
| 13 | "What's the gate code / access instructions?" | `GET /locations/{id}/notes` | ✅ Full |

### Category 3: Service Inquiry

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 14 | "What services do you offer?" | `GET /pricebook/services` | ✅ Full |
| 15 | "Do you do [specific service]?" | `GET /pricebook/services` (LLM matches) | ✅ Full |
| 16 | "How much does [service] cost?" | `GET /pricebook/services` (price fields) | ⚠️ Partial: Only if pricing configured in pricebook |
| 17 | "Do you service my area?" | `GET /dispatch/zones` | ⚠️ Partial: Zones available but no address-to-zone matching API |
| 18 | "What are your business units / departments?" | `GET /settings/business-units` | ✅ Full |

### Category 4: New Booking / Service Request

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 19 | "I need [service] done" | `POST /booking-provider/{bp}/bookings` | ✅ Full |
| 20 | "I have a leak / emergency" | `POST /booking-provider/{bp}/bookings` (priority: Urgent) | ✅ Full |
| 21 | "Can someone come look at [problem]?" | `POST /booking-provider/{bp}/bookings` | ✅ Full |
| 22 | "I'd like a quote/estimate" | `POST /booking-provider/{bp}/bookings` (summary mentions estimate) | ✅ Full |
| 23 | "My neighbor recommended you" (referral) | `POST /booking-provider/{bp}/bookings` (campaignId for referral) | ✅ Full |
| 24 | "Send me a confirmation" | `POST /booking-provider/{bp}/bookings` (isSendConfirmationEmail: true) | ✅ Full |
| 25 | "I'm a first-time customer" | `POST /booking-provider/{bp}/bookings` (isFirstTimeClient: true) | ✅ Full |

### Category 5: Lead Management

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 26 | "I called before about getting work done" | `GET /leads` (filter by customerId, status: Open) | ✅ Full |
| 27 | "What's happening with my inquiry?" | `GET /leads/{id}` | ✅ Full |
| 28 | "I'm no longer interested" | `POST /leads/{id}/dismiss` | ✅ Full |
| 29 | "Can you follow up with me next week?" | `POST /leads/{id}/follow-up` (followUpDate, text) | ✅ Full |
| 30 | "I want to add a note to my inquiry" | `POST /leads/{id}/notes` | ✅ Full |

### Category 6: Scheduling & Availability

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 31 | "When are you available?" | `POST /dispatch/capacity` (date range, businessUnitIds) | ✅ Full |
| 32 | "Can you come [specific date]?" | `POST /dispatch/capacity` (specific date range) | ✅ Full |
| 33 | "I need to schedule an appointment" | `POST /dispatch/capacity` → `POST /jobs` (with appointments[]) | ✅ Full |
| 34 | "What's my next appointment?" | `GET /appointments` (filter by jobId or date range) | ✅ Full |
| 35 | "What appointments do I have?" | `GET /appointments` (filter by customer's jobs) | ✅ Full |
| 36 | "I'm available mornings only" | `POST /dispatch/capacity` (LLM filters AM slots) | ✅ Full |
| 37 | "Who's coming to my appointment?" | `GET /dispatch/appointment-assignments` | ✅ Full |

### Category 7: Reschedule & Cancel

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 38 | "I need to reschedule" | `GET /appointments` → `PATCH /appointments/{id}/reschedule` | ✅ Full |
| 39 | "Can I move my appointment?" | `POST /dispatch/capacity` → `PATCH /appointments/{id}/reschedule` | ✅ Full |
| 40 | "I need to cancel my appointment" | `DELETE /appointments/{id}` | ✅ Full |
| 41 | "Something came up, I can't make it" | `DELETE /appointments/{id}` or `PATCH /appointments/{id}/reschedule` | ✅ Full |
| 42 | "Cancel the whole job" | `PUT /jobs/{id}/cancel` (reasonId, memo) | ✅ Full |
| 43 | "Put my job on hold" | `PUT /jobs/{id}/hold` (reasonId, memo) | ✅ Full |
| 44 | "Take my job off hold" | `PUT /jobs/{id}/remove-cancellation` | ✅ Full |
| 45 | "Put my appointment on hold" | `PUT /appointments/{id}/hold` (reasonId, memo) | ✅ Full |

### Category 8: Job / Work Status

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 46 | "What's the status of my job?" | `GET /jobs` (filter by customerId) / `GET /jobs/{id}` | ✅ Full |
| 47 | "What's my job number?" | `GET /jobs` (filter by customerId) | ✅ Full |
| 48 | "When will the work be done?" | `GET /jobs/{id}` (completedOn) + `GET /appointments` | ✅ Full |
| 49 | "Who's assigned to my job?" | `GET /dispatch/appointment-assignments` (appointmentId) | ✅ Full |
| 50 | "I have a note about my job / special instructions" | `POST /jobs/{id}/notes` or `PUT /appointments/{id}/special-instructions` | ✅ Full |
| 51 | "The gate code is [X]" | `PUT /appointments/{id}/special-instructions` | ✅ Full |
| 52 | "What's the history on my job?" | `GET /jobs/{id}/history` | ✅ Full |
| 53 | "Is this part of a project?" | `GET /projects` (filter by customerId/locationId) | ✅ Full |

### Category 9: Estimates & Quotes

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 54 | "What's the estimate for my job?" | `GET /estimates` (filter by jobId) | ✅ Full |
| 55 | "How much will it cost?" | `GET /estimates/{id}` + `GET /estimates/items` | ✅ Full |
| 56 | "I want to approve the estimate" | `PUT /estimates/{id}/sell` | ✅ Full |
| 57 | "I don't want the estimate" | `PUT /estimates/{id}/dismiss` | ✅ Full |
| 58 | "I changed my mind, undo the approval" | `PUT /estimates/{id}/unsell` (if no signature/not booked) | ⚠️ Partial: Only works if not yet booked out |
| 59 | "The estimate is too high / I want to negotiate" | `POST /jobs/{id}/notes` | ⚠️ Workaround: Agent notes concern, suggests follow-up |

### Category 10: Billing & Payments

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 60 | "How much do I owe?" | `GET /customers/{id}` (balance field) | ✅ Full |
| 61 | "What's my balance?" | `GET /customers/{id}` (balance) | ✅ Full |
| 62 | "Can I see my invoices?" | `GET /invoices` (filter by customerId) | ✅ Full |
| 63 | "I got an invoice, can you explain it?" | `GET /invoices` + invoice items (LLM reads line items) | ✅ Full |
| 64 | "When is my payment due?" | `GET /payment-terms/{customerId}` + `GET /invoices` | ✅ Full |
| 65 | "I want to pay my bill" | `POST /payments` | ✅ Full (can create payment record) |
| 66 | "What payment methods do you accept?" | `GET /payment-types` | ✅ Full |
| 67 | "I already paid, but it's showing a balance" | `GET /payments` (filter by customerId) + `POST /jobs/{id}/notes` | ⚠️ Partial: Can check payments, note discrepancy |
| 68 | "Can I set up a payment plan?" | — | ❌ GAP: Not available in API. Transfer to human. |

### Category 11: Memberships

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 69 | "What membership plans do you offer?" | `GET /membership-types` | ✅ Full |
| 70 | "Am I a member?" | `GET /memberships` (filter by customerId, status: Active) | ✅ Full |
| 71 | "When does my membership expire?" | `GET /memberships/{id}` | ✅ Full |
| 72 | "I want to sign up for a membership" | `POST /memberships` | ✅ Full |
| 73 | "What's included in my membership?" | `GET /memberships/{id}` + `GET /recurring-services` | ✅ Full |
| 74 | "When is my next recurring service?" | `GET /recurring-service-events` (filter by status) | ✅ Full |
| 75 | "I want to cancel my membership" | — | ❌ GAP: No cancel membership endpoint. Transfer to human. |
| 76 | "Update my membership billing" | `PATCH /memberships/{id}` | ⚠️ Partial: Can update some fields, not payment method |

### Category 12: Complaints & Follow-up

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 77 | "I'm not happy with the work" | `POST /jobs/{id}/notes` + `POST /tasks` + transfer | ⚠️ Workaround: Document complaint, create task, transfer |
| 78 | "The technician didn't show up" | `POST /jobs/{id}/notes` + `POST /tasks` + transfer | ⚠️ Workaround: Same pattern |
| 79 | "My repair broke again" (warranty/callback) | `POST /booking-provider/{bp}/bookings` (reference original job in summary) | ✅ Full |
| 80 | "I need to speak to a manager" | Transfer call (LiveKit) | ✅ Full (not an API endpoint) |
| 81 | "Is this covered under warranty?" | `GET /installed-equipment` (location) | ⚠️ Partial: Can check equipment, but no warranty data in API |
| 82 | "I want to file a complaint" | `POST /tasks` (type: Customer Complaint) | ✅ Full |

### Category 13: Equipment & Systems

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 83 | "What equipment is at my location?" | `GET /equipmentsystems/installed-equipment` (filter by locationId) | ✅ Full |
| 84 | "When was my [unit] installed?" | `GET /equipmentsystems/installed-equipment/{id}` | ✅ Full |
| 85 | "I need to update equipment info" | `PATCH /equipmentsystems/installed-equipment/{id}` | ✅ Full |

### Category 14: General / Meta

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 86 | "What are your hours?" | — | ⚠️ System prompt: Configured in business settings |
| 87 | "Where are you located?" | `GET /settings/business-units` (address) | ✅ Full |
| 88 | "How do I leave a review?" | — | ⚠️ System prompt: Configured with review link |
| 89 | "I need to talk to a real person" | Transfer call (LiveKit) | ✅ Full |
| 90 | "What's the call reason for this?" | `GET /jbce/call-reasons` | ✅ Full |

---

## Coverage Summary

| Status | Count | Percentage |
|--------|-------|------------|
| ✅ **Full coverage** | 73 | 81.1% |
| ⚠️ **Partial / workaround** | 14 | 15.6% |
| ❌ **Gap (no endpoint)** | 3 | 3.3% |
| **Total intents** | **90** | 100% |

---

## Gaps Analysis & Recommendations

### Critical Gaps

| Gap | Impact | Recommendation | Effort |
|-----|--------|----------------|--------|
| **Payment plans** (#68) | Medium — callers can't set up payment plans | Transfer to human; not available in API | N/A |
| **Membership cancellation** (#75) | Medium — callers can't cancel memberships by phone | Transfer to human; membership cancel must be done in ST UI | N/A |

### Nice-to-Have Gaps

| Gap | Impact | Recommendation | Effort |
|-----|--------|----------------|--------|
| **Service area matching** (#17) | Low — zones exist but no address-to-zone matching | Configure service area in system prompt or implement zone lookup logic | Config |
| **Warranty info** (#81) | Low — equipment tracked but no warranty field | Transfer to human | N/A |

### Workarounds That Are Acceptable

These intents use `POST /jobs/{id}/notes` or `POST /tasks` as a catch-all + transfer to human. This is the correct pattern:

- Estimate negotiations (#59)
- Payment disputes (#67)
- Work quality complaints (#77, #78)
- Membership billing updates (#76)

---

## Voice Agent Call Flow Decision Tree

```
Inbound Call
│
├─ GET /customers (filter by phone)
│  ├─ FOUND → "Hi [name], how can I help you?"
│  │  ├─ Scheduling → POST /dispatch/capacity → POST /jobs (with appointments)
│  │  │              → GET /appointments → PATCH reschedule / DELETE
│  │  ├─ Status check → GET /jobs / GET /leads / GET /estimates
│  │  ├─ Billing → GET /customers/{id} (balance) → GET /invoices → GET /payments
│  │  ├─ Membership → GET /memberships → GET /recurring-service-events
│  │  ├─ New service → POST /booking-provider/{bp}/bookings
│  │  ├─ Update info → PATCH /customers/{id} / PATCH /locations/{id}
│  │  ├─ Complaint → POST /tasks (Customer Complaint) + POST /jobs/{id}/notes + transfer
│  │  ├─ Equipment → GET /equipmentsystems/installed-equipment
│  │  └─ Transfer → LiveKit warm/cold transfer
│  │
│  └─ NOT FOUND → "I don't see an account. Let me help you get started."
│     ├─ Collect name, address, phone, service need
│     ├─ POST /customers (creates customer + location)
│     └─ POST /booking-provider/{bp}/bookings (creates booking for CSR)
```

---

## Entity CRUD Coverage Matrix

| Entity | Create | Read | Update | Delete | List |
|--------|--------|------|--------|--------|------|
| **Customer** | ✅ | ✅ | ✅ | — (deactivate) | ✅ |
| **Location** | ✅ | ✅ | ✅ | ✅ (deactivate) | ✅ |
| **Booking** | ✅ | ✅ | ✅ | — | ✅ |
| **Lead** | ✅ | ✅ | ✅ | ✅ (dismiss) | ✅ |
| **Job** | ✅ | ✅ | ✅ | ✅ (cancel) | ✅ |
| **Appointment** | ✅ | ✅ | ✅ (reschedule) | ✅ | ✅ |
| **Estimate** | ✅ | ✅ | ✅ (sell/dismiss) | — | ✅ |
| **Invoice** | ✅ (adjustment) | ✅ | ✅ | — | ✅ |
| **Payment** | ✅ | ✅ | ✅ | — | ✅ |
| **Membership** | ✅ | ✅ | ✅ | ❌ gap | ✅ |
| **Project** | — | ✅ | — | — | ✅ |
| **Task** | ✅ | — | — | — | — |
| **Customer Contact** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Location Contact** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Note** (Customer/Location/Job/Lead) | ✅ | — | — | — | ✅ |

---

## ServiceTitan vs Jobber: Key Comparison for Voice Agent

| Feature | ServiceTitan | Jobber |
|---------|-------------|--------|
| **Customer lookup** | GET /customers (phone/name filter) | GraphQL getClientByPhone |
| **New inquiry** | POST /bookings (Booking Provider) | POST submit-new-lead (Client+Property+Request) |
| **Lead tracking** | Separate Lead entity with follow-up/dismiss | Request entity with status tracking |
| **Availability** | POST /dispatch/capacity (real-time) | Schedule gap analysis |
| **Book appointment** | POST /jobs (with appointments[]) | POST create-visit (creates Job+Visit) |
| **Reschedule** | PATCH /appointments/{id}/reschedule | POST reschedule-visit |
| **Cancel** | DELETE /appointments/{id} or PUT /jobs/{id}/cancel | POST cancel-visit |
| **Estimates** | Full CRUD + sell/unsell/dismiss | create-estimate only |
| **Quote approval** | PUT /estimates/{id}/sell ✅ | ❌ GAP (no quote-approve) |
| **Invoices** | Full CRUD | Read-only (list) |
| **Payments** | Full CRUD | ❌ GAP (no payment API) |
| **Memberships** | Full API (types, customer memberships, recurring services) | Not available |
| **Equipment tracking** | Full CRUD on installed equipment | Not available |
| **Task management** | Create tasks + subtasks | Not available |
| **Business units** | Multi-department support | Not available |
| **Campaigns** | Marketing attribution | Not available |
| **Call records** | Telecom API (calls, recordings) | Not available |
| **Auth model** | OAuth2 + tenant-scoped + booking provider | OAuth2 + GraphQL |
| **API style** | REST (OpenAPI) | GraphQL |
| **Total endpoints** | 230 | ~24 (implemented) |

### ServiceTitan Advantages for Voice Agent
1. **Estimate approval by phone** — `PUT /estimates/{id}/sell` (Jobber gap)
2. **Payment creation** — `POST /payments` (Jobber gap)
3. **Real-time capacity** — `POST /dispatch/capacity` (more robust than Jobber gap analysis)
4. **Membership management** — full lifecycle (Jobber has none)
5. **Task creation for complaints** — `POST /tasks` (structured, not just notes)
6. **Equipment tracking** — can answer "what's installed at my location?"
7. **Booking Provider isolation** — our bookings are tagged and isolated from other integrations

### ServiceTitan Limitations vs Jobber
1. **REST vs GraphQL** — more endpoints to implement, but simpler per-endpoint
2. **No service area matching** — zones exist but no address-to-zone API
3. **No membership cancel** — must be done in UI
4. **Booking → Job is async** — CSR must accept booking before it becomes a job (Jobber's submit-new-lead is similar)

---

## Implementation Priority for Voice Agent Adapter

### Phase 1: Core (MVP)
1. `GET /customers` — lookup by phone/name
2. `POST /customers` — create new customer + location
3. `PATCH /customers/{id}` — update customer info
4. `POST /booking-provider/{bp}/bookings` — create booking (primary intake)
5. `GET /bookings` — check booking status
6. `POST /dispatch/capacity` — check availability
7. `POST /jobs` — book job with appointment
8. `GET /jobs` — list customer jobs
9. `GET /appointments` — list appointments
10. `PATCH /appointments/{id}/reschedule` — reschedule
11. `DELETE /appointments/{id}` — cancel appointment
12. `PUT /jobs/{id}/cancel` — cancel job
13. `POST /jobs/{id}/notes` — add notes/special instructions

### Phase 2: Enhanced
14. `GET /estimates` — check estimates
15. `PUT /estimates/{id}/sell` — approve estimate
16. `PUT /estimates/{id}/dismiss` — decline estimate
17. `GET /invoices` — list invoices
18. `GET /customers/{id}` (balance) — check balance
19. `GET /memberships` — check membership status
20. `GET /membership-types` — list available memberships
21. `GET /pricebook/services` — list services offered
22. `POST /tasks` — create complaint/follow-up task

### Phase 3: Full Coverage
23. `GET /installed-equipment` — equipment lookup
24. `GET /recurring-service-events` — next service date
25. `GET /payment-types` — payment methods
26. `POST /payments` — record payment
27. `GET /locations` — list locations
28. `PATCH /locations/{id}` — update location
29. `PUT /appointments/{id}/special-instructions` — gate codes etc.
30. `GET /jbce/call-reasons` — call reason categorization
