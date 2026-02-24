# CallSaver CRM — Thin Field Service Platform API Design

> **Date:** 2026-02-24
> **Status:** Planning
> **Goal:** Built-in FSM for businesses that don't use Jobber/HCP/ServiceFusion/ServiceTitan — our own "platform" adapter that stores data in our Postgres DB instead of calling external APIs.

## 1. Design Philosophy

### Why build this

Most small field service businesses (plumbers, electricians, HVAC, locksmiths, etc.) don't have an FSM platform at all. They use pen-and-paper, spreadsheets, or nothing. Right now our voice agent's most powerful features (customer lookup, service request creation, scheduling, estimates) only work if the business connects Jobber or HCP. That's a huge drop-off in our onboarding funnel.

A built-in thin CRM means:
- **Every CallSaver customer gets the full voice agent experience** from day one, no integration required
- **Upsell path**: businesses outgrow our CRM → we help them migrate to Jobber/HCP/ServiceTitan
- **Data ownership**: we control the schema, the query patterns, and the performance
- **Zero-config onboarding**: voice agent starts creating customers and service requests on the first call

### What we include (and why)

| Include | Rationale |
|---|---|
| Customers + Contacts | Core CRM. Phone-first (voice agent lookup). |
| Properties (separate entity) | Service businesses need multi-property support. Jobber gets this right. |
| Service Requests | Intake pipeline. What the voice agent creates on every new-caller call. |
| Jobs | Work units. The thing that gets scheduled and dispatched. |
| Appointments / Visits | Scheduled time blocks on jobs. Calendar-visible events. |
| Estimates / Quotes | Pre-sale pricing. Voice agent can read back estimates to callers. |
| Services (catalog) | Already exists as `Service` model. Powers service matching. |
| Team / Technicians | Who gets dispatched. Needed for availability + assignment. |
| Notes | Append-only audit trail on any entity. |
| Tags | Flexible categorization. |
| Sources | Attribution tracking (CallSaver, website, referral, etc.) |

### What we exclude

| Exclude | Rationale |
|---|---|
| Invoicing | Complex (tax calc, payment terms, line items, partial payments). Businesses that need this should use QuickBooks/Stripe/real FSM. |
| Payment processing | PCI compliance burden. Out of scope. |
| Payroll / time tracking | HR domain, not CRM. |
| Inventory / parts | Too deep into ERP territory. |
| Complex dispatching | Route optimization, GPS tracking, etc. — that's Jobber/ServiceTitan's moat. |
| Document management | Photos, contracts, signed work orders. Nice-to-have later. |

### Design principles

1. **Jobber-inspired entity model** — separate Properties, Request→Job pipeline, first-class Appointments
2. **REST API** — simple, standard, tooling-friendly. No GraphQL overhead for a thin CRM.
3. **Tenant-scoped** — everything is scoped to `organizationId`. Multi-location via `locationId`.
4. **Phone-first** — customer lookup by phone is the #1 query (voice agent hot path).
5. **FieldServiceAdapter-native** — the CRM adapter implements the same 34-method interface as Jobber/HCP/SF adapters, but reads/writes Postgres instead of external APIs.
6. **Soft deletes** — `deletedAt` timestamp on mutable entities. Never hard-delete customer data.
7. **Optimistic timestamps** — `createdAt`, `updatedAt` on everything. Prisma handles this.
8. **CUID primary keys** — consistent with existing schema. URL-safe, sortable-ish.

---

## 2. Entity Relationship Diagram

```
Organization (tenant)
  ├── Location (business location / branch)
  │     ├── Agent (voice agent config — already exists)
  │     └── TeamMember (technician / dispatcher)
  │
  ├── Customer ◄── 1:N ──► Contact (phone, email per person)
  │     │
  │     ├── Property (service address, separate entity)
  │     │
  │     ├── ServiceRequest (intake from voice agent)
  │     │     └── links to: Property, Service, Job (if converted)
  │     │
  │     ├── Job (work unit, parent of appointments)
  │     │     ├── Appointment (scheduled visit)
  │     │     └── Note
  │     │
  │     ├── Estimate (quote with line items)
  │     │     └── EstimateLineItem
  │     │
  │     └── Tag (M:N via CustomerTag join)
  │
  ├── Service (catalog — already exists)
  ├── Source (attribution — "CallSaver", "Google", "Referral")
  └── Tag (org-level tag definitions)
```

---

## 3. Database Schema (Prisma)

### 3.1 CrmCustomer

Replaces/extends the existing `Caller` model for businesses using our CRM. The `Caller` model stays for call-tracking-only customers; `CrmCustomer` is the full CRM entity.

```prisma
model CrmCustomer {
  id               String           @id @default(cuid())
  organizationId   String           @map("organization_id")
  locationId       String?          @map("location_id")
  
  // Core fields
  firstName        String?          @map("first_name")
  lastName         String?          @map("last_name")
  companyName      String?          @map("company_name")
  isCompany        Boolean          @default(false) @map("is_company")
  status           String           @default("active") // active, inactive, lead
  
  // Convenience (denormalized from contacts)
  primaryPhone     String?          @map("primary_phone")
  primaryEmail     String?          @map("primary_email")
  
  // Business fields
  accountNumber    String?          @map("account_number")
  notes            String?          // Private notes (internal)
  publicNotes      String?          @map("public_notes") // Shown to techs
  creditRating     String?          @map("credit_rating")
  referralSourceId String?          @map("referral_source_id")
  
  // Linking
  callerId         String?          @unique @map("caller_id") // Link to existing Caller record
  
  // Timestamps
  createdAt        DateTime         @default(now()) @map("created_at")
  updatedAt        DateTime         @updatedAt @map("updated_at")
  deletedAt        DateTime?        @map("deleted_at")
  
  // Relations
  organization     Organization     @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  location         Location?        @relation(fields: [locationId], references: [id])
  caller           Caller?          @relation(fields: [callerId], references: [id])
  referralSource   CrmSource?       @relation(fields: [referralSourceId], references: [id])
  contacts         CrmContact[]
  properties       CrmProperty[]
  serviceRequests  CrmServiceRequest[]
  jobs             CrmJob[]
  estimates        CrmEstimate[]
  tags             CrmCustomerTag[]
  
  @@unique([primaryPhone, organizationId])
  @@index([organizationId])
  @@index([primaryPhone])
  @@index([lastName, organizationId])
  @@index([accountNumber, organizationId])
  @@map("crm_customers")
}
```

### 3.2 CrmContact

Multi-contact per customer (billing contact, site contact, spouse, etc.).

```prisma
model CrmContact {
  id            String       @id @default(cuid())
  customerId    String       @map("customer_id")
  
  firstName     String?      @map("first_name")
  lastName      String?      @map("last_name")
  contactType   String?      @map("contact_type") // primary, billing, site, emergency
  isPrimary     Boolean      @default(false) @map("is_primary")
  
  createdAt     DateTime     @default(now()) @map("created_at")
  updatedAt     DateTime     @updatedAt @map("updated_at")
  
  customer      CrmCustomer  @relation(fields: [customerId], references: [id], onDelete: Cascade)
  phones        CrmPhone[]
  emails        CrmEmail[]
  
  @@index([customerId])
  @@map("crm_contacts")
}

model CrmPhone {
  id          String     @id @default(cuid())
  contactId   String     @map("contact_id")
  number      String     // Stored in E.164 format
  type        String?    // mobile, home, work, fax
  isPrimary   Boolean    @default(false) @map("is_primary")
  
  contact     CrmContact @relation(fields: [contactId], references: [id], onDelete: Cascade)
  
  @@index([number])
  @@index([contactId])
  @@map("crm_phones")
}

model CrmEmail {
  id          String     @id @default(cuid())
  contactId   String     @map("contact_id")
  address     String
  type        String?    // personal, work
  isPrimary   Boolean    @default(false) @map("is_primary")
  
  contact     CrmContact @relation(fields: [contactId], references: [id], onDelete: Cascade)
  
  @@index([contactId])
  @@map("crm_emails")
}
```

### 3.3 CrmProperty

Separate entity (Jobber-style). A customer can have multiple service addresses.

```prisma
model CrmProperty {
  id               String       @id @default(cuid())
  customerId       String       @map("customer_id")
  
  // Address
  street           String
  street2          String?
  city             String
  state            String
  zipCode          String       @map("zip_code")
  country          String       @default("US")
  
  // Metadata
  label            String?      // "Home", "Office", "Rental Property"
  isPrimary        Boolean      @default(false) @map("is_primary")
  gateCode         String?      @map("gate_code")
  accessNotes      String?      @map("access_notes") // "Use side gate", "Ring doorbell twice"
  latitude         Decimal?     @db.Decimal(10, 7)
  longitude        Decimal?     @db.Decimal(10, 7)
  
  createdAt        DateTime     @default(now()) @map("created_at")
  updatedAt        DateTime     @updatedAt @map("updated_at")
  deletedAt        DateTime?    @map("deleted_at")
  
  customer         CrmCustomer  @relation(fields: [customerId], references: [id], onDelete: Cascade)
  serviceRequests  CrmServiceRequest[]
  jobs             CrmJob[]
  
  @@index([customerId])
  @@map("crm_properties")
}
```

### 3.4 CrmServiceRequest

The intake record. Voice agent creates this on every new-caller call. Think of it as Jobber's "Request" or HCP's "Lead".

```prisma
model CrmServiceRequest {
  id               String           @id @default(cuid())
  organizationId   String           @map("organization_id")
  customerId       String           @map("customer_id")
  propertyId       String?          @map("property_id")
  
  // Request details
  number           String?          // Auto-generated human-readable number (SR-001)
  title            String?
  description      String
  serviceType      String?          @map("service_type") // Matched service name
  serviceId        String?          @map("service_id")   // FK to Service catalog
  priority         String           @default("normal")   // low, normal, high, emergency
  status           String           @default("new")      // new, reviewed, converted, closed, cancelled
  
  // Intake data
  desiredTime      String?          @map("desired_time")     // "Tuesday morning", "ASAP"
  summary          String?                                     // AI-generated summary
  intakeAnswers    Json?            @map("intake_answers")    // Custom Q&A from voice agent
  callerReportedIssue String?       @map("caller_reported_issue")
  
  // Attribution
  sourceId         String?          @map("source_id")
  callRecordId     String?          @map("call_record_id")
  
  // Conversion
  convertedToJobId String?          @unique @map("converted_to_job_id")
  convertedAt      DateTime?        @map("converted_at")
  
  createdAt        DateTime         @default(now()) @map("created_at")
  updatedAt        DateTime         @updatedAt @map("updated_at")
  
  organization     Organization     @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  customer         CrmCustomer      @relation(fields: [customerId], references: [id])
  property         CrmProperty?     @relation(fields: [propertyId], references: [id])
  source           CrmSource?       @relation(fields: [sourceId], references: [id])
  convertedToJob   CrmJob?          @relation(fields: [convertedToJobId], references: [id])
  notes            CrmNote[]
  
  @@index([organizationId, status])
  @@index([customerId])
  @@index([createdAt])
  @@map("crm_service_requests")
}
```

### 3.5 CrmJob

The work unit. Created when a service request is accepted/converted, or directly for returning customers.

```prisma
model CrmJob {
  id               String           @id @default(cuid())
  organizationId   String           @map("organization_id")
  customerId       String           @map("customer_id")
  propertyId       String?          @map("property_id")
  
  // Job identity
  number           String?          // Auto-generated (J-001, J-002)
  title            String
  description      String?
  
  // Status
  status           String           @default("pending")
  // pending → scheduled → in_progress → completed → closed
  // also: cancelled, on_hold
  priority         String           @default("normal")
  
  // Scheduling
  scheduledStart   DateTime?        @map("scheduled_start")
  scheduledEnd     DateTime?        @map("scheduled_end")
  actualStart      DateTime?        @map("actual_start")
  actualEnd        DateTime?        @map("actual_end")
  duration         Int?             // Estimated duration in minutes
  
  // Service
  serviceId        String?          @map("service_id")
  serviceType      String?          @map("service_type")
  
  // Source
  serviceRequestId String?          @map("service_request_id")
  estimateId       String?          @map("estimate_id")
  sourceId         String?          @map("source_id")
  
  // Completion
  completionNotes  String?          @map("completion_notes")
  
  createdAt        DateTime         @default(now()) @map("created_at")
  updatedAt        DateTime         @updatedAt @map("updated_at")
  deletedAt        DateTime?        @map("deleted_at")
  
  organization     Organization     @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  customer         CrmCustomer      @relation(fields: [customerId], references: [id])
  property         CrmProperty?     @relation(fields: [propertyId], references: [id])
  source           CrmSource?       @relation(fields: [sourceId], references: [id])
  appointments     CrmAppointment[]
  assignments      CrmJobAssignment[]
  notes            CrmNote[]
  tags             CrmJobTag[]
  
  // Reverse relation from ServiceRequest
  sourceRequest    CrmServiceRequest?
  
  @@index([organizationId, status])
  @@index([customerId])
  @@index([number, organizationId])
  @@index([scheduledStart])
  @@map("crm_jobs")
}
```

### 3.6 CrmAppointment

Individual scheduled visit on a Job. A Job can have multiple appointments (e.g., initial visit + follow-up).

```prisma
model CrmAppointment {
  id               String             @id @default(cuid())
  jobId            String             @map("job_id")
  
  // Schedule
  startTime        DateTime           @map("start_time")
  endTime          DateTime           @map("end_time")
  allDay           Boolean            @default(false) @map("all_day")
  
  // Status
  status           String             @default("scheduled")
  // scheduled, confirmed, in_progress, completed, cancelled, no_show
  
  // Details
  instructions     String?            // "Use back entrance", "Call when arriving"
  cancellationReason String?          @map("cancellation_reason")
  
  createdAt        DateTime           @default(now()) @map("created_at")
  updatedAt        DateTime           @updatedAt @map("updated_at")
  
  job              CrmJob             @relation(fields: [jobId], references: [id], onDelete: Cascade)
  assignments      CrmAppointmentAssignment[]
  
  @@index([jobId])
  @@index([startTime])
  @@index([status])
  @@map("crm_appointments")
}
```

### 3.7 CrmEstimate

Quotes / estimates. Voice agent can create and read these back to callers.

```prisma
model CrmEstimate {
  id               String              @id @default(cuid())
  organizationId   String              @map("organization_id")
  customerId       String              @map("customer_id")
  propertyId       String?             @map("property_id")
  
  // Identity
  number           String?             // EST-001
  title            String?
  
  // Status
  status           String              @default("draft")
  // draft, sent, accepted, rejected, expired
  
  // Totals (calculated from line items)
  subtotal         Decimal             @default(0) @db.Decimal(10, 2)
  taxAmount        Decimal             @default(0) @map("tax_amount") @db.Decimal(10, 2)
  total            Decimal             @default(0) @db.Decimal(10, 2)
  
  // Validity
  validUntil       DateTime?           @map("valid_until")
  
  // Notes
  notes            String?             // Internal notes
  messageToCustomer String?            @map("message_to_customer")
  
  // Conversion
  acceptedAt       DateTime?           @map("accepted_at")
  convertedToJobId String?             @map("converted_to_job_id")
  
  createdAt        DateTime            @default(now()) @map("created_at")
  updatedAt        DateTime            @updatedAt @map("updated_at")
  
  organization     Organization        @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  customer         CrmCustomer         @relation(fields: [customerId], references: [id])
  lineItems        CrmEstimateLineItem[]
  
  @@index([organizationId])
  @@index([customerId])
  @@index([status])
  @@map("crm_estimates")
}

model CrmEstimateLineItem {
  id            String      @id @default(cuid())
  estimateId    String      @map("estimate_id")
  
  description   String
  quantity      Decimal     @default(1) @db.Decimal(10, 2)
  unitPrice     Decimal     @map("unit_price") @db.Decimal(10, 2)
  total         Decimal     @db.Decimal(10, 2) // quantity * unitPrice
  
  serviceId     String?     @map("service_id") // Optional link to Service catalog
  sortOrder     Int         @default(0) @map("sort_order")
  
  estimate      CrmEstimate @relation(fields: [estimateId], references: [id], onDelete: Cascade)
  
  @@index([estimateId])
  @@map("crm_estimate_line_items")
}
```

### 3.8 Supporting Entities

```prisma
// ─── Team Members ───

model CrmTeamMember {
  id               String               @id @default(cuid())
  organizationId   String               @map("organization_id")
  
  firstName        String               @map("first_name")
  lastName         String               @map("last_name")
  email            String?
  phone            String?
  role             String               @default("technician") // technician, dispatcher, manager
  department       String?              // "HVAC", "Plumbing", "Electrical"
  color            String?              // Hex color for calendar display
  isActive         Boolean              @default(true) @map("is_active")
  
  createdAt        DateTime             @default(now()) @map("created_at")
  updatedAt        DateTime             @updatedAt @map("updated_at")
  
  organization     Organization         @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  jobAssignments   CrmJobAssignment[]
  apptAssignments  CrmAppointmentAssignment[]
  
  @@index([organizationId])
  @@map("crm_team_members")
}

model CrmJobAssignment {
  jobId        String        @map("job_id")
  memberId     String        @map("member_id")
  role         String        @default("assigned") // assigned, lead
  
  job          CrmJob        @relation(fields: [jobId], references: [id], onDelete: Cascade)
  member       CrmTeamMember @relation(fields: [memberId], references: [id], onDelete: Cascade)
  
  @@id([jobId, memberId])
  @@map("crm_job_assignments")
}

model CrmAppointmentAssignment {
  appointmentId String          @map("appointment_id")
  memberId      String          @map("member_id")
  
  appointment   CrmAppointment  @relation(fields: [appointmentId], references: [id], onDelete: Cascade)
  member        CrmTeamMember   @relation(fields: [memberId], references: [id], onDelete: Cascade)
  
  @@id([appointmentId, memberId])
  @@map("crm_appointment_assignments")
}

// ─── Notes (polymorphic, append-only) ───

model CrmNote {
  id               String            @id @default(cuid())
  organizationId   String            @map("organization_id")
  
  // Polymorphic parent
  entityType       String            @map("entity_type") // customer, job, service_request, appointment
  entityId         String            @map("entity_id")
  
  content          String
  authorType       String            @default("system") @map("author_type") // system, user, voice_agent
  authorId         String?           @map("author_id") // userId or "voice-agent"
  
  // Optional job/request links for note queries
  jobId            String?           @map("job_id")
  serviceRequestId String?           @map("service_request_id")
  
  createdAt        DateTime          @default(now()) @map("created_at")
  
  // Relations (optional, for query convenience)
  job              CrmJob?           @relation(fields: [jobId], references: [id], onDelete: Cascade)
  serviceRequest   CrmServiceRequest? @relation(fields: [serviceRequestId], references: [id], onDelete: Cascade)
  
  @@index([entityType, entityId])
  @@index([organizationId, createdAt])
  @@map("crm_notes")
}

// ─── Tags ───

model CrmTag {
  id               String           @id @default(cuid())
  organizationId   String           @map("organization_id")
  name             String
  color            String?          // Hex color
  
  organization     Organization     @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  customers        CrmCustomerTag[]
  jobs             CrmJobTag[]
  
  @@unique([organizationId, name])
  @@map("crm_tags")
}

model CrmCustomerTag {
  customerId String      @map("customer_id")
  tagId      String      @map("tag_id")
  
  customer   CrmCustomer @relation(fields: [customerId], references: [id], onDelete: Cascade)
  tag        CrmTag      @relation(fields: [tagId], references: [id], onDelete: Cascade)
  
  @@id([customerId, tagId])
  @@map("crm_customer_tags")
}

model CrmJobTag {
  jobId  String @map("job_id")
  tagId  String @map("tag_id")
  
  job    CrmJob @relation(fields: [jobId], references: [id], onDelete: Cascade)
  tag    CrmTag @relation(fields: [tagId], references: [id], onDelete: Cascade)
  
  @@id([jobId, tagId])
  @@map("crm_job_tags")
}

// ─── Sources (attribution) ───

model CrmSource {
  id               String              @id @default(cuid())
  organizationId   String              @map("organization_id")
  name             String              // "CallSaver", "Google", "Referral", "Walk-in"
  
  organization     Organization        @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  customers        CrmCustomer[]
  serviceRequests  CrmServiceRequest[]
  jobs             CrmJob[]
  
  @@unique([organizationId, name])
  @@map("crm_sources")
}
```

---

## 4. REST API Design

Base path: `/api/crm` (or `/internal/crm` for voice agent tools)

### 4.1 Customers

```
GET    /crm/customers                    List customers (paginated, filterable)
GET    /crm/customers/:id                Get customer by ID (expand: contacts, properties, tags)
GET    /crm/customers/search?phone=X     Find by phone (voice agent hot path)
POST   /crm/customers                    Create customer
PUT    /crm/customers/:id                Update customer
DELETE /crm/customers/:id                Soft delete
```

**Query parameters (list):**
- `page`, `perPage` (default 10, max 50)
- `sort` (e.g., `-created_at`, `last_name`)
- `status` (active, inactive, lead)
- `q` (search: name, phone, email, account_number)
- `tag` (filter by tag name)
- `expand` (comma-separated: `contacts`, `contacts.phones`, `contacts.emails`, `properties`, `tags`, `recentJobs`)

### 4.2 Properties

```
GET    /crm/customers/:customerId/properties     List properties for customer
POST   /crm/customers/:customerId/properties     Create property
PUT    /crm/properties/:id                        Update property
DELETE /crm/properties/:id                        Soft delete
```

### 4.3 Service Requests

```
GET    /crm/service-requests                      List (paginated, filterable by status/customer/date)
GET    /crm/service-requests/:id                  Get by ID (expand: customer, property, notes, job)
POST   /crm/service-requests                      Create
PUT    /crm/service-requests/:id                  Update (status, assignment, notes)
POST   /crm/service-requests/:id/convert          Convert to Job
```

### 4.4 Jobs

```
GET    /crm/jobs                                  List (paginated, filterable)
GET    /crm/jobs/:id                              Get by ID (expand: appointments, assignments, notes, customer)
GET    /crm/jobs/by-number/:number                Get by human-readable number
POST   /crm/jobs                                  Create
PUT    /crm/jobs/:id                              Update
POST   /crm/jobs/:id/cancel                       Cancel with reason
```

**Query parameters:**
- `customerId`, `status`, `priority`, `assignedTo`
- `scheduledAfter`, `scheduledBefore` (date range)
- `expand` (appointments, assignments, notes, customer, property)

### 4.5 Appointments

```
GET    /crm/appointments                          List (calendar view, date range)
GET    /crm/jobs/:jobId/appointments              List for job
POST   /crm/jobs/:jobId/appointments              Create appointment on job
PUT    /crm/appointments/:id                      Reschedule / update
POST   /crm/appointments/:id/cancel               Cancel with reason
GET    /crm/availability                           Check availability (date range, duration)
```

**Availability endpoint** — computes open slots:
```
GET /crm/availability?date=2026-03-01&days=3&duration=60
→ Returns time slots based on business hours - existing appointments
```

### 4.6 Estimates

```
GET    /crm/estimates                              List (filterable by customer, status)
GET    /crm/estimates/:id                          Get by ID (with line items)
POST   /crm/estimates                              Create (with line items)
PUT    /crm/estimates/:id                          Update
POST   /crm/estimates/:id/accept                   Mark accepted (optionally create Job)
POST   /crm/estimates/:id/reject                   Mark rejected
```

### 4.7 Team Members

```
GET    /crm/team                                   List team members
POST   /crm/team                                   Add team member
PUT    /crm/team/:id                               Update
DELETE /crm/team/:id                               Deactivate
```

### 4.8 Notes, Tags, Sources

```
POST   /crm/notes                                  Create note (entityType + entityId)
GET    /crm/notes?entityType=job&entityId=X         List notes for entity

GET    /crm/tags                                    List org tags
POST   /crm/tags                                    Create tag
POST   /crm/customers/:id/tags                      Add tag to customer
DELETE /crm/customers/:id/tags/:tagId                Remove tag

GET    /crm/sources                                 List sources
POST   /crm/sources                                 Create source
```

---

## 5. FieldServiceAdapter Implementation — `CallSaverCrmAdapter`

The adapter implements the same 34-method `FieldServiceAdapter` interface. Instead of calling external APIs, it reads/writes to the `crm_*` Prisma tables.

### Method mapping (all 34)

| Method | Implementation | Notes |
|---|---|---|
| **findCustomerByPhone** | `crm_phones` JOIN → `crm_contacts` JOIN → `crm_customers` | Index on `crm_phones.number`. Fastest path. |
| **createCustomer** | INSERT `crm_customers` + `crm_contacts` + `crm_phones` | Auto-creates "CallSaver" source if not exists. |
| **updateCustomer** | UPDATE `crm_customers` + upsert contacts | Full support (unlike SF!). |
| **listProperties** | SELECT `crm_properties` WHERE `customer_id` | Separate entity, full CRUD. |
| **createProperty** | INSERT `crm_properties` | With geocoding via validate_address. |
| **updateProperty** | UPDATE `crm_properties` | Full support. |
| **deleteProperty** | SET `deleted_at` | Soft delete. |
| **createServiceRequest** | INSERT `crm_service_requests` + auto-create CrmJob if autoSchedule | Links to property, service, source. |
| **getRequest** | SELECT with JOINs | Includes customer, property, notes, converted job. |
| **getRequests** | SELECT filtered by customer | Sorted by created_at DESC. |
| **submitLead** | Orchestrate: find/create customer → create property → create SR | Same pattern as all adapters. |
| **createAssessment** | Create a CrmJob with status="assessment" + CrmAppointment | We own the schema — we CAN have assessments! |
| **cancelAssessment** | UPDATE job status to cancelled | Full support. |
| **rescheduleAssessment** | UPDATE `crm_appointments` times | Full support. |
| **getClientSchedule** | SELECT `crm_appointments` JOIN `crm_jobs` WHERE customer | Unified schedule view. |
| **getJobs** | SELECT `crm_jobs` filtered | With expand for appointments, assignments. |
| **getJobByNumber** | SELECT WHERE `number` = X | Human-readable job numbers. |
| **addNoteToJob** | INSERT `crm_notes` with entityType='job' | Append-only. |
| **cancelJob** | UPDATE status + INSERT cancellation note | Full support. |
| **checkAvailability** | Query appointments in range, compute gaps vs business hours | Same algorithm as Jobber adapter but querying our DB. |
| **createAppointment** | INSERT `crm_appointments` on job | With optional team member assignment. |
| **getAppointments** | SELECT appointments for customer's jobs in date range | |
| **rescheduleAppointment** | UPDATE appointment times | Full support. |
| **cancelAppointment** | UPDATE status='cancelled' + reason | Full support. |
| **getEstimates** | SELECT `crm_estimates` with line items | |
| **createEstimate** | INSERT estimate + line items | |
| **acceptEstimate** | UPDATE status='accepted', optionally create Job | Full support. |
| **declineEstimate** | UPDATE status='rejected' | Full support. |
| **getInvoices** | Return `[]` | No invoicing in thin CRM. |
| **getAccountBalance** | Return `{ totalBalance: 0, overdueBalance: 0, openInvoices: 0 }` | No billing. |
| **getServices** | SELECT from existing `services` table | Already exists! |
| **getCompanyInfo** | Read from `Location.googlePlaceDetails` | Same as Jobber fallback. |
| **checkServiceArea** | Check against `Location.serviceAreas` | Same as Jobber fallback. |
| **getMemberships** | Return null | Not applicable. |
| **getMembershipTypes** | Return null | Not applicable. |
| **createTask** | INSERT `crm_notes` with special type | Or create a CalendarTask-like entity later. |

### Key advantage: 100% adapter coverage

Unlike Jobber (no company info, no service area check), HCP (no update property, no delete property), and Service Fusion (no updates at all, no appointments CRUD, no notes) — our CRM adapter has **full support for all 34 methods**. Zero UNSUPPORTED_OPERATION throws.

---

## 6. Auto-Number Generation

Human-readable sequential numbers scoped per organization:

```
Service Requests: SR-001, SR-002, ...
Jobs:             J-001, J-002, ...
Estimates:        EST-001, EST-002, ...
```

Implementation: `crm_sequences` table with atomic increment:

```prisma
model CrmSequence {
  id               String       @id @default(cuid())
  organizationId   String       @map("organization_id")
  entityType       String       @map("entity_type") // service_request, job, estimate
  nextNumber       Int          @default(1) @map("next_number")
  prefix           String       // SR, J, EST
  
  @@unique([organizationId, entityType])
  @@map("crm_sequences")
}
```

Generated via: `SELECT next_number FROM crm_sequences WHERE ... FOR UPDATE` + increment in a transaction.

---

## 7. Voice Agent Integration

### System prompt handling

When no external integration is connected AND the CRM is active, the system prompt generator uses `platform = 'callsaver-crm'`:

```typescript
// server.ts fsInstructions
const platformName = 'CallSaver CRM';
const assessmentEntity = 'assessment'; // We support it natively!
const idNote = 'CallSaver CRM uses short IDs (e.g., J-042). Use these when referencing jobs or requests.';
```

The voice agent workflow is identical to Jobber/HCP — the adapter abstraction means the agent doesn't know or care whether it's talking to Jobber's GraphQL API or our own Postgres.

### Auto-activation

When a business completes onboarding WITHOUT connecting an external integration:
1. Auto-create "CallSaver" source in `crm_sources`
2. Set `organizationIntegration.platform = 'callsaver-crm'` (or use a flag on Organization)
3. Voice agent gets the full fs-tools suite from call #1

---

## 8. Migration Path

### From thin CRM → Jobber/HCP/ServiceTitan

When a customer outgrows the CRM and connects an external platform:
1. Export CRM data as CSV (customers, properties, jobs)
2. Optional: bulk-import into the new platform via API
3. Switch adapter: `callsaver-crm` → `jobber` / `housecallpro`
4. Archive CRM data (don't delete — keep for history)

### From existing Caller records → CRM Customer

For existing CallSaver users who aren't using an FSM:
1. Migration script: create `CrmCustomer` from `Caller` records
2. Create `CrmContact` + `CrmPhone` from Caller.phoneNumber
3. Create `CrmProperty` from `CallerAddress` records
4. Link via `CrmCustomer.callerId`

---

## 9. Implementation Phases

### Phase 1: Schema + Core Adapter (MVP) — 8-10 hours

- Prisma migration with all `crm_*` tables
- `CallSaverCrmAdapter.ts` implementing all 34 methods
- Register in `FieldServiceAdapterFactory` + `FieldServiceAdapterRegistry`
- Auto-number generation
- No new REST endpoints yet — voice agent uses existing `fs-*` tool routes

### Phase 2: System Prompt + Auto-Activation — 3-4 hours

- Platform detection for `callsaver-crm` in server.ts
- System prompt generation with CallSaver CRM terminology
- Auto-create CRM records on onboarding (no integration selected)
- Migrate existing Caller → CrmCustomer for non-integrated orgs

### Phase 3: Dashboard REST API — 6-8 hours

- `src/routes/crm.ts` — full REST API for dashboard consumption
- Frontend pages: Customers, Service Requests, Jobs, Schedule, Estimates
- Reuse existing page patterns (ServiceRequestsPage, CallerDetailPage, etc.)

### Phase 4: Calendar + Availability — 4-5 hours

- `checkAvailability` implementation (business hours - booked slots)
- Calendar view on dashboard (appointment timeline)
- Team member management UI

### Phase 5: Polish — 3-4 hours

- Bulk import (CSV upload for existing customer lists)
- Export to CSV
- CRM → external platform migration tooling
- Email notifications (appointment confirmations, estimate sent)

| Phase | Hours | Priority |
|---|---|---|
| Phase 1: Schema + Core Adapter | 8-10 | P0 |
| Phase 2: System Prompt + Auto-Activation | 3-4 | P0 |
| Phase 3: Dashboard REST API | 6-8 | P1 |
| Phase 4: Calendar + Availability | 4-5 | P1 |
| Phase 5: Polish | 3-4 | P2 |
| **Total** | **24-31 hours** | |

---

## 10. File Inventory

### New files

```
src/adapters/field-service/platforms/callsaver-crm/
  CallSaverCrmAdapter.ts          # 34-method adapter (reads/writes Postgres)
  crm-helpers.ts                  # Auto-number gen, phone normalization, query builders

src/routes/crm.ts                 # REST API for dashboard

prisma/migrations/0XX_callsaver_crm/
  migration.sql                   # All crm_* tables
```

### Modified files

```
prisma/schema.prisma              # Add all crm_* models
FieldServiceAdapterFactory.ts     # Add 'callsaver-crm' case
FieldServiceAdapterRegistry.ts    # Add to platform detection
server.ts                         # Platform detection for system prompt
utils.ts                          # CallSaver CRM prompt generation
integrations-config.ts (frontend) # Add callsaver-crm as "built-in" option
```

---

## 11. Competitive Analysis — Where We Win

| Feature | Jobber | HCP | Service Fusion | **CallSaver CRM** |
|---|---|---|---|---|
| Starting price | $39/mo | $79/mo | $99/mo | **Free** (included) |
| Setup time | Hours | Hours | Hours | **Zero** (auto-activated) |
| Voice agent integration | Via OAuth | Via API key | Via OAuth | **Native** (same DB) |
| Phone-first customer lookup | ~500ms (GraphQL) | ~300ms (REST) | ~400ms (REST) | **<50ms** (indexed Postgres) |
| Full CRUD on all entities | Mostly | Mostly | Read+Create only | **Yes, all 34 methods** |
| Assessment scheduling | ✅ | Via lead convert | ❌ | **✅ Native** |
| Availability check | Via scheduledItems | Via booking_windows | ❌ | **✅ Native** |
| No external dependency | ❌ | ❌ | ❌ | **✅** |
| Data portability | Their data | Their data | Their data | **Your data** (CSV export) |

The key pitch: **"Your AI receptionist includes a free CRM. No setup required. Your first caller's info is automatically saved."**
