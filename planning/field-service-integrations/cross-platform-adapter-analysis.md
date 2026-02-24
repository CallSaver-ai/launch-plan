# Cross-Platform Adapter Analysis: Unified Intent Coverage

> Created: Feb 17, 2026
> Status: Definitive cross-platform reference for FieldServiceAdapter redesign
> Platforms: Jobber (GraphQL), ServiceTitan (REST v2), Housecall Pro (REST v1)
> Sources: Official OpenAPI specs + customer intent analyses for all 3 platforms

---

## 1. Platform Summary

| Metric | Jobber | ServiceTitan | Housecall Pro |
|--------|--------|-------------|---------------|
| **API Style** | GraphQL | REST (OpenAPI, tenant-scoped) | REST (OpenAPI) |
| **Auth** | OAuth 2.0 (Nango) | OAuth 2.0 + App Key + Tenant ID | API Key or OAuth 2.0 (Nango) |
| **Endpoints** | ~24 (mutations/queries) | 230 across 17 modules | 83 endpoints |
| **Schemas** | N/A (GraphQL introspection) | 480 | 77 |
| **Customer Intents Mapped** | 65 | 90 | 65 |
| **Full Coverage** | 48 (73.8%) | 73 (81.1%) | 52 (80.0%) |
| **Gaps** | 8 (12.3%) | 3 (3.3%) | 6 (9.2%) |
| **Unique Features** | Assessment entity, Request→Quote flow | Capacity API, Memberships, Payments, Tasks, Equipment, Business Units, Booking Provider | Lead conversion, Booking Windows, Service Zones, Estimate approve/decline |

---

## 2. Unified Entity Terminology

| Our Adapter Term | Jobber | ServiceTitan | HCP | Notes |
|-----------------|--------|-------------|-----|-------|
| **Customer** | Client | Customer | Customer | All platforms: full CRUD |
| **Property** | Property | Location | Address (sub-resource) | ST locations are first-class. HCP addresses are customer sub-resources. |
| **ServiceRequest** | Request | Booking (via Booking Provider) | Lead | The initial intake from a caller. ST Bookings go to CSR calls screen. |
| **Assessment** | Assessment | Booking (type=Estimate) | Estimate appointment | Pre-sale site visit. HCP's "Estimate" is schedulable like an assessment. |
| **Estimate** | Quote | Estimate | Estimate (with options) | Price quote. HCP has options with line items. |
| **Job** | Job | Job | Job | The work order / contract. |
| **Appointment** | Visit | Appointment | Appointment (child of Job) | Scheduled calendar event. All 3 have this as child of Job. |
| **Invoice** | Invoice | Invoice | Invoice | Billing document. |
| **Membership** | ❌ N/A | Membership | ❌ N/A | ST-exclusive. Recurring service agreements. |
| **Task** | ❌ N/A | Task | ❌ N/A | ST-exclusive. For complaints/follow-ups. |
| **BusinessUnit** | ❌ N/A | Business Unit | ❌ N/A | ST-exclusive. Departments (HVAC, Plumbing, etc.) |

### Entity Flow per Platform

```
Jobber:    Caller → Request → Assessment → Quote → Job → Visit(s) → Invoice
ST:        Caller → Booking (CSR accepts) → Job + Appointment → Estimate → Invoice → Payment
                    └─ or → Lead (follow-up) → Job
HCP:       Caller → Lead ──convert──→ Estimate ──approve──→ Job → Appointment(s) → Invoice
                         └──convert──→ Job (direct, skip estimate)
```

---

## 3. Exhaustive Customer Intent Matrix

Every intent a caller may express, mapped across all 3 platforms.
Coverage: ✅ Full | ⚠️ Partial/workaround | ❌ Gap | 🔄 Fallback (Location model)

### Category 1: Identity & Account Management

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 1 | "Hi, I'm calling about..." (identify caller) | `findCustomerByPhone` | ✅ GraphQL query | ✅ `GET /customers?phone=` | ✅ `GET /customers?phone=` |
| 2 | "I'm a new customer" | `submitLead` | ✅ Creates Client+Property+Request | ✅ `POST /customers` + `POST /bookings` | ✅ `POST /leads` with inline customer |
| 3 | "I need to update my email" | `updateCustomer` | ✅ clientEdit mutation | ✅ `PATCH /customers/{id}` (contacts) | ✅ `PUT /customers/{id}` |
| 4 | "My phone number changed" | `updateCustomer` | ✅ | ✅ `PATCH /customers/{id}/contacts/{cid}` | ✅ |
| 5 | "I changed my name" | `updateCustomer` | ✅ | ✅ `PATCH /customers/{id}` | ✅ |
| 6 | "What info do you have for me?" | `findCustomerByPhone` | ✅ | ✅ `GET /customers/{id}` + contacts | ✅ |
| 7 | "I'm a commercial customer" | `createCustomer` / `updateCustomer` | ⚠️ Jobber has no customer type | ✅ type: Commercial | ⚠️ HCP has `company` field |

### Category 2: Property / Service Location Management

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 8 | "I have a new address / I moved" | `updateProperty` | ✅ propertyEdit mutation | ✅ `PATCH /locations/{id}` | ✅ `PUT /customers/{id}` |
| 9 | "I have a second location" | `createProperty` | ✅ propertyCreate mutation | ✅ `POST /locations` | ✅ `POST /customers/{id}/addresses` |
| 10 | "Which addresses do you have?" | `listProperties` | ✅ client.properties query | ✅ `GET /locations?customerId=` | ✅ `GET /customers/{id}/addresses` |
| 11 | "The address on file is wrong" | `updateProperty` | ✅ | ✅ | ✅ |
| 12 | "Remove my old property" | `deleteProperty` | ❌ No delete mutation | ✅ `PATCH /locations/{id}` (active: false) | ❌ No delete endpoint |
| 13 | "What's the gate code / access info?" | `addNoteToJob` / property notes | ⚠️ Job notes only | ✅ `GET /locations/{id}/notes` | ⚠️ Job notes only |

### Category 3: Service Inquiry

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 14 | "What services do you offer?" | `getServices` | ✅ ProductOrService query | ✅ `GET /pricebook/services` | ✅ `GET /api/price_book/services` |
| 15 | "Do you do [specific service]?" | `getServices` (LLM matches) | ✅ | ✅ | ✅ |
| 16 | "How much does [service] cost?" | `getServices` (price field) | ⚠️ Only if pricing configured | ⚠️ Only if pricebook configured | ✅ Has unit_price |
| 17 | "Do you service my area?" | **`checkServiceArea`** ★NEW | 🔄 Location.serviceAreas | ⚠️ `GET /dispatch/zones` (no address match) | ✅ `GET /service_zones?zip_code=` |
| 18 | "What departments do you have?" | **`getCompanyInfo`** ★NEW | 🔄 N/A | ✅ `GET /settings/business-units` | 🔄 N/A |

### Category 4: New Service Request / Lead Intake

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 19 | "I need [service] done" | `submitLead` | ✅ Client+Property+Request | ✅ `POST /bookings` | ✅ `POST /leads` |
| 20 | "I have a leak / emergency" | `submitLead` (priority: emergency) | ✅ | ✅ priority: Urgent | ✅ urgency in note |
| 21 | "Can someone come look at it?" | `submitLead` | ✅ | ✅ | ✅ |
| 22 | "I'd like a quote/estimate" | `submitLead` | ✅ Creates Request | ✅ summary mentions estimate | ✅ |
| 23 | "My neighbor recommended you" | `submitLead` (referral) | ✅ captured in description | ✅ campaignId for referral | ✅ lead_source field |
| 24 | "Send me a confirmation" | N/A (platform auto-sends) | ⚠️ Manual | ✅ isSendConfirmationEmail | ⚠️ Manual |
| 25 | "I'm a first-time customer" | `submitLead` | ✅ customerCreated flag | ✅ isFirstTimeClient | ✅ |

### Category 5: Request / Lead / Estimate Status

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 26 | "What's happening with my request?" | `getRequest` / `getRequests` | ✅ Enriched with assessment/quotes/jobs | ✅ `GET /bookings/{id}` or `GET /leads` | ✅ `GET /leads/{id}` |
| 27 | "Did you get my request?" | `getRequests` | ✅ | ✅ | ✅ |
| 28 | "When is my consultation?" | `getRequest` (assessment metadata) | ✅ | ✅ | ✅ (estimate schedule) |
| 29 | "Has my quote been sent?" | **`getEstimates`** ★NEW | ✅ via getRequest metadata.quotes | ✅ `GET /estimates?jobId=` | ✅ `GET /estimates?customer_id=` |
| 30 | "What's the quote amount?" | **`getEstimates`** ★NEW | ✅ | ✅ `GET /estimates/{id}` + items | ✅ estimate total + options |
| 31 | "I want to approve the estimate" | `acceptEstimate` | ❌ GAP (no quoteApprove in GraphQL API) | ✅ `PUT /estimates/{id}/sell` | ✅ `POST /estimates/options/approve` |
| 32 | "I don't want the estimate" | **`declineEstimate`** ★NEW | ❌ GAP | ✅ `PUT /estimates/{id}/dismiss` | ✅ `POST /estimates/options/decline` |
| 33 | "The quote is too high / negotiate" | `addNoteToJob` (workaround) | ⚠️ | ⚠️ | ⚠️ |

### Category 6: Scheduling & Availability

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 34 | "When are you available?" | `checkAvailability` | ✅ Schedule gap analysis | ✅ `POST /dispatch/capacity` | ✅ `GET /company/schedule_availability/booking_windows` |
| 35 | "Can you come [specific date]?" | `checkAvailability` (date range) | ✅ | ✅ | ✅ |
| 36 | "I need to schedule an appointment" | `createAppointment` | ✅ creates Job+Visit | ✅ `POST /jobs` with appointments[] | ✅ via lead convert or direct job |
| 37 | "What's my next appointment?" | `getAppointments` | ✅ client.visits query | ✅ `GET /appointments` | ✅ `GET /jobs/{id}/appointments` |
| 38 | "What appointments do I have?" | `getAppointments` | ✅ | ✅ | ✅ |
| 39 | "Schedule a consultation" | `createAssessment` | ✅ assessmentCreate mutation | ✅ Booking with type=Estimate | ✅ Estimate with schedule |
| 40 | "I'm available mornings only" | `checkAvailability` (LLM filters) | ✅ | ✅ | ✅ |
| 41 | "Who's coming to my appointment?" | `getAppointments` (technician field) | ✅ assignedUsers on visit | ✅ `GET /dispatch/appointment-assignments` | ✅ dispatched_employees on job |

### Category 7: Reschedule & Cancel

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 42 | "I need to reschedule" | `rescheduleAppointment` | ✅ visitReschedule mutation | ✅ `PATCH /appointments/{id}/reschedule` | ✅ `PUT /jobs/{id}/appointments/{appt_id}` |
| 43 | "Can I move my appointment?" | `checkAvailability` → `rescheduleAppointment` | ✅ | ✅ | ✅ |
| 44 | "I need to cancel my appointment" | `cancelAppointment` | ✅ visitCancel mutation | ✅ `DELETE /appointments/{id}` | ✅ `DELETE /jobs/{id}/appointments/{appt_id}` |
| 45 | "Something came up, I can't make it" | `cancelAppointment` or `rescheduleAppointment` | ✅ | ✅ | ✅ |
| 46 | "Cancel the whole job" | **`cancelJob`** ★NEW | ⚠️ Job status mutation | ✅ `PUT /jobs/{id}/cancel` (reasonId) | ⚠️ No explicit cancel endpoint |
| 47 | "Put my job on hold" | **`holdJob`** ★NEW (Extended) | ❌ GAP | ✅ `PUT /jobs/{id}/hold` (reasonId) | ❌ GAP |
| 48 | "Cancel my assessment" | `cancelAssessment` | ✅ assessmentDelete mutation | ⚠️ Cancel booking | ⚠️ Delete estimate schedule |

### Category 8: Job / Work Status

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 49 | "What's the status of my job?" | `getJobs` / `getJobByNumber` | ✅ | ✅ `GET /jobs` | ✅ `GET /jobs` |
| 50 | "What's my job number?" | `getJobs` (jobNumber field) | ✅ | ✅ | ✅ (invoice_number) |
| 51 | "When will the work be done?" | `getJobs` (scheduledEnd / completedAt) | ✅ | ✅ | ✅ |
| 52 | "Who's assigned to my job?" | `getJobs` (assignedTechnicians) | ✅ assignedUsers | ✅ `GET /dispatch/appointment-assignments` | ✅ assigned_employees |
| 53 | "I have a note about my job" | `addNoteToJob` | ✅ | ✅ `POST /jobs/{id}/notes` | ✅ `POST /jobs/{id}/notes` |
| 54 | "The gate code is [X]" | `addNoteToJob` | ✅ | ✅ `PUT /appointments/{id}/special-instructions` | ✅ `POST /jobs/{id}/notes` |
| 55 | "What's the history on my job?" | `getJobs` (metadata) | ⚠️ Limited | ✅ `GET /jobs/{id}/history` | ⚠️ Limited |

### Category 9: Billing & Payments

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 56 | "How much do I owe?" | `getAccountBalance` | ✅ client.billingAddress.balance | ✅ `GET /customers/{id}` (balance) | ✅ Sum outstanding_balance from jobs |
| 57 | "What's my balance?" | `getAccountBalance` | ✅ | ✅ | ✅ |
| 58 | "Can I see my invoices?" | `getInvoices` | ✅ invoices query | ✅ `GET /invoices?customerId=` | ✅ `GET /invoices?customer_uuid=` |
| 59 | "I got an invoice, explain it?" | `getInvoices` (LLM reads line items) | ✅ | ✅ | ✅ |
| 60 | "When is my payment due?" | `getInvoices` (dueDate) | ✅ | ✅ `GET /payment-terms/{customerId}` | ✅ due_at field |
| 61 | "I want to pay my bill" | N/A (PCI) | ❌ No payment API | ✅ `POST /payments` (ST-only) | ❌ No payment API |
| 62 | "What payment methods accepted?" | **`getCompanyInfo`** ★NEW | 🔄 Location.googlePlaceDetails.paymentOptions | ✅ `GET /payment-types` | 🔄 `GET /company` or Location fallback |
| 63 | "Can I set up a payment plan?" | Transfer to human | ❌ | ❌ | ❌ |
| 64 | "I already paid but balance shows" | `getInvoices` + `addNoteToJob` | ⚠️ | ⚠️ Can check payments | ⚠️ |

### Category 10: Complaints & Follow-up

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 65 | "I'm not happy with the work" | `addNoteToJob` + transfer | ⚠️ | ⚠️ `POST /tasks` + notes | ⚠️ |
| 66 | "Technician didn't show up" | `addNoteToJob` + transfer | ⚠️ | ⚠️ | ⚠️ |
| 67 | "My repair broke again" (callback) | `submitLead` (new request) | ✅ | ✅ New booking ref original | ✅ New lead |
| 68 | "I need to speak to a manager" | Transfer (LiveKit) | ✅ | ✅ | ✅ |
| 69 | "I want to file a complaint" | **`createTask`** ★NEW (Extended) | ⚠️ Notes only | ✅ `POST /tasks` (type: Complaint) | ⚠️ Notes only |
| 70 | "Is this covered under warranty?" | Transfer to human | ❌ | ⚠️ Equipment API (no warranty data) | ❌ |

### Category 11: Memberships (ST-exclusive)

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 71 | "What membership plans do you offer?" | **`getMembershipTypes`** ★NEW | ❌ N/A | ✅ `GET /membership-types` | ❌ N/A |
| 72 | "Am I a member?" | **`getMemberships`** ★NEW | ❌ N/A | ✅ `GET /memberships?customerId=` | ❌ N/A |
| 73 | "When does my membership expire?" | **`getMemberships`** ★NEW | ❌ N/A | ✅ `GET /memberships/{id}` | ❌ N/A |
| 74 | "I want to sign up for a membership" | **`createMembership`** ★NEW | ❌ N/A | ✅ `POST /memberships` | ❌ N/A |
| 75 | "What's included in my membership?" | **`getMemberships`** ★NEW | ❌ N/A | ✅ + `GET /recurring-services` | ❌ N/A |
| 76 | "When is my next recurring service?" | **`getMemberships`** ★NEW | ❌ N/A | ✅ `GET /recurring-service-events` | ❌ N/A |
| 77 | "I want to cancel my membership" | Transfer to human | ❌ | ❌ No cancel endpoint | ❌ |

### Category 12: General / Meta

| # | Caller Intent | Adapter Method | Jobber | ServiceTitan | HCP |
|---|---------------|----------------|--------|-------------|-----|
| 78 | "What are your hours?" | **`getCompanyInfo`** ★NEW | 🔄 Location.googlePlaceDetails.hours | ✅ `GET /settings/business-units` | ✅ `GET /company` |
| 79 | "Where are you located?" | **`getCompanyInfo`** ★NEW | 🔄 Location.googlePlaceDetails | ✅ `GET /settings/business-units` | ✅ `GET /company` |
| 80 | "How do I leave a review?" | System prompt (review link) | 🔄 | 🔄 | 🔄 |
| 81 | "I need to talk to a real person" | Transfer (LiveKit) | ✅ | ✅ | ✅ |

---

## 4. Adapter Interface Gap Analysis

### Current Interface (26 methods)

| Category | Methods | Count |
|----------|---------|-------|
| Customer | findCustomerByPhone, createCustomer, updateCustomer | 3 |
| Property | listProperties, createProperty, updateProperty, deleteProperty | 4 |
| Service Request | createServiceRequest, getRequest, getRequests, submitLead | 4 |
| Assessment | createAssessment, cancelAssessment | 2 |
| Job | getJobs, getJobByNumber, addNoteToJob | 3 |
| Appointment | checkAvailability, createAppointment, getAppointments, rescheduleAppointment, cancelAppointment | 5 |
| Estimate | createEstimate, acceptEstimate | 2 |
| Invoice/Billing | getInvoices, getAccountBalance | 2 |
| Service Catalog | getServices | 1 |

### Methods to ADD (Core Tier — all platforms should implement)

| Method | Why | Jobber | ST | HCP | Intents |
|--------|-----|--------|-----|-----|---------|
| **`getEstimates(customerId)`** | "What's my quote?" / "Has my estimate been sent?" | via getRequest metadata | `GET /estimates` | `GET /estimates` | #29, #30 |
| **`declineEstimate(estimateId)`** | "I don't want the estimate" | ❌ throw UNSUPPORTED | `PUT /estimates/{id}/dismiss` | `POST /estimates/options/decline` | #32 |
| **`cancelJob(jobId, reason?)`** | "Cancel the whole job" (different from cancel appointment) | jobCancel mutation | `PUT /jobs/{id}/cancel` | ⚠️ status change | #46 |
| **`getCompanyInfo()`** | "What are your hours?" / "Where are you?" / "What payment methods?" | 🔄 Returns null (tool layer uses Location fallback) | `GET /settings/business-units` + `GET /payment-types` | `GET /company` | #18, #62, #78, #79 |
| **`checkServiceArea(zipCode)`** | "Do you service my area?" | 🔄 Returns null (tool layer uses Location.serviceAreas fallback) | `GET /dispatch/zones` (partial) | `GET /service_zones?zip_code=` | #17 |

### Methods to ADD (Extended Tier — implement if platform supports, else return null)

| Method | Why | Jobber | ST | HCP | Intents |
|--------|-----|--------|-----|-----|---------|
| **`getMemberships(customerId)`** | "Am I a member?" / membership status | null | `GET /memberships` | null | #72-76 |
| **`getMembershipTypes()`** | "What plans do you offer?" | null | `GET /membership-types` | null | #71 |
| **`createTask(data)`** | Structured complaints/follow-ups | ⚠️ falls back to addNoteToJob | `POST /tasks` | ⚠️ falls back to addNoteToJob | #69 |

### Revised Interface: 34 methods

| Tier | Category | Methods | Count |
|------|----------|---------|-------|
| Core | Customer | findCustomerByPhone, createCustomer, updateCustomer | 3 |
| Core | Property | listProperties, createProperty, updateProperty, deleteProperty | 4 |
| Core | Service Request | createServiceRequest, getRequest, getRequests, submitLead | 4 |
| Core | Assessment | createAssessment, cancelAssessment | 2 |
| Core | Job | getJobs, getJobByNumber, addNoteToJob, **cancelJob** | 4 |
| Core | Appointment | checkAvailability, createAppointment, getAppointments, rescheduleAppointment, cancelAppointment | 5 |
| Core | Estimate | **getEstimates**, createEstimate, acceptEstimate, **declineEstimate** | 4 |
| Core | Invoice/Billing | getInvoices, getAccountBalance | 2 |
| Core | Service Catalog | getServices | 1 |
| Core | Company/Meta | **getCompanyInfo**, **checkServiceArea** | 2 |
| Extended | Memberships | **getMemberships**, **getMembershipTypes** | 2 |
| Extended | Tasks | **createTask** | 1 |
| **Total** | | | **34** |

---

## 5. Location Model Fallback Strategy

Our Prisma `Location` model stores data that serves as fallback when a platform doesn't support certain features:

### Relevant Location Fields

```prisma
model Location {
  services              String[]   // ["HVAC Repair", "Plumbing", ...]
  serviceAreas          String[]   // ["Phoenix", "Scottsdale", "Mesa", ...]
  googlePlaceDetails    Json?      // { hours, paymentOptions, address, ... }
  brandsServiced        String[]   // ["Carrier", "Lennox", ...]
  estimatePolicyText    String?    // "We offer free estimates..."
  frequentlyAskedQuestions Json?   // [{ question, answer }, ...]
  transferPhoneNumber   String?    // For warm transfer
  externalPlatformId    String?    // ST tenant ID or HCP company ID
}
```

### Fallback Matrix

| Intent | Platform API | Location Fallback | Tool-Layer Logic |
|--------|-------------|-------------------|------------------|
| "What services do you offer?" | `adapter.getServices()` | `location.services` | If adapter returns empty/null, fall back to Location |
| "Do you service my area?" | `adapter.checkServiceArea(zip)` | `location.serviceAreas` | If adapter returns null, check if zip's city is in serviceAreas |
| "What are your hours?" | `adapter.getCompanyInfo()` | `location.googlePlaceDetails.hours` | If adapter returns null, use Google Place hours |
| "Where are you located?" | `adapter.getCompanyInfo()` | `location.googlePlaceDetails` | Address from Google Place Details |
| "What payment methods?" | `adapter.getCompanyInfo()` | `location.googlePlaceDetails.paymentOptions` | From Google Place Details |
| "What brands do you service?" | N/A (no platform has this) | `location.brandsServiced` | Always from Location model |
| "Do you offer free estimates?" | N/A | `location.estimatePolicyText` | Always from Location model |
| FAQ responses | N/A | `location.frequentlyAskedQuestions` | Always from Location model |

### Implementation in Tool Layer

```typescript
// In field-service-tools.ts router:
router.post('/get-company-info', verifyInternalApiKey, async (req, res) => {
  const { locationId, callerPhoneNumber } = req.body;
  const adapter = await getAdapter(locationId);
  const context = buildContext(callerPhoneNumber);

  // Try platform API first
  const platformInfo = await adapter.getCompanyInfo(context);
  if (platformInfo) return res.json({ companyInfo: platformInfo });

  // Fallback to Location model
  const location = await prisma.location.findUnique({ where: { id: locationId } });
  const gp = location?.googlePlaceDetails as any;
  return res.json({
    companyInfo: {
      name: location?.name,
      hours: gp?.hours?.regularOpeningHours,
      address: gp?.business?.formattedAddress,
      paymentMethods: gp?.business?.paymentOptions,
    }
  });
});
```

---

## 6. ServiceTitan Location Management

ServiceTitan has its own Location entity (= service addresses linked to Customers). This is more than a simple "property" — it's a first-class entity with contacts, notes, tax zones, and custom fields.

### How ST Locations Map to Our Models

| ST Concept | Our Prisma Model | Relationship |
|-----------|-----------------|-------------|
| ST Tenant | `Organization` | 1:1 — stored in `OrganizationIntegration.config.tenantId` |
| ST Business Unit | `Location` | N:1 — one of our Locations may map to one or more ST BUs |
| ST Customer Location | `Property` (adapter type) | The service address where work is done |

### `externalPlatformId` Usage

```
Location.externalPlatformId:
  - Jobber: Not needed (Jobber doesn't have multi-location concept)
  - ServiceTitan: The ST Tenant ID (all API calls are tenant-scoped)
  - HCP: The HCP Company ID (if multi-location)
```

### When Platform Provides Location Management

For ServiceTitan, the adapter's `listProperties`, `createProperty`, `updateProperty` methods map directly to the ST Location CRUD API. Our Prisma `Location` record exists for voice agent config (services, prompt, phone number), while ST Locations are the customer's service addresses.

For HCP, addresses are sub-resources of customers — no independent location management needed.

For Jobber, properties are the service addresses — similar to our current setup.

**Key insight**: Our `Location` model is the **business location** (the company's office/branch). The adapter's `Property` type is the **customer's service address**. These are different things and don't conflict.

---

## 7. Containment Rate Impact Analysis

Methods that will INCREASE containment if added (currently force transfer to human):

| New Method | Intents Covered | Estimated Call % | Containment Impact |
|------------|----------------|------------------|-------------------|
| `getEstimates` | #29, #30 (quote status/amount) | ~8% of calls | HIGH — very common follow-up call |
| `declineEstimate` | #32 (reject quote) | ~2% | MEDIUM — prevents human callback |
| `cancelJob` | #46 (cancel whole job) | ~3% | MEDIUM — currently awkward |
| `getCompanyInfo` | #18, #62, #78, #79 (hours/location/payments) | ~12% of calls | HIGH — most common general inquiry |
| `checkServiceArea` | #17 (service area) | ~5% of calls | HIGH — often the very first question |
| `getMemberships` | #72-76 (membership status) | ~4% (ST only) | HIGH for ST customers |
| `getMembershipTypes` | #71 (plan offerings) | ~2% (ST only) | MEDIUM for ST customers |
| `createTask` | #69 (complaints) | ~3% | MEDIUM — better than notes+transfer |

**Estimated containment improvement: +5-10%** across all platforms.

---

## 8. New Types Needed

```typescript
// Company/Business Info (returned by getCompanyInfo)
export interface CompanyInfo {
  name: string;
  phone?: string;
  email?: string;
  address?: Address;
  website?: string;
  hours?: Record<string, { open: string; close: string }>;
  paymentMethods?: string[];
  businessUnits?: { id: string; name: string }[];
  timezone?: string;
}

// Service Area Check Result
export interface ServiceAreaResult {
  isServiced: boolean;
  matchedZone?: string;
  message?: string; // e.g. "We service the 85001 area" or "Outside our service area"
}

// Membership (Extended — ST only)
export interface Membership {
  id: string;
  customerId: string;
  typeName: string;
  status: 'active' | 'expired' | 'cancelled' | 'suspended';
  startDate?: Date;
  endDate?: Date;
  renewalDate?: Date;
  recurringServices?: { name: string; nextDate?: Date }[];
  metadata?: Record<string, any>;
}

// Membership Type (Extended — ST only)
export interface MembershipType {
  id: string;
  name: string;
  description?: string;
  price?: number;
  billingFrequency?: string;
  includedServices?: string[];
  metadata?: Record<string, any>;
}
```

---

## 9. Revised Adapter Interface Summary

```
FieldServiceAdapter (34 methods)
│
├── CORE TIER (all platforms must implement)
│   ├── Customer (3): findCustomerByPhone, createCustomer, updateCustomer
│   ├── Property (4): listProperties, createProperty, updateProperty, deleteProperty
│   ├── Service Request (4): createServiceRequest, getRequest, getRequests, submitLead
│   ├── Assessment (2): createAssessment, cancelAssessment
│   ├── Job (4): getJobs, getJobByNumber, addNoteToJob, cancelJob ★
│   ├── Appointment (5): checkAvailability, createAppointment, getAppointments,
│   │                     rescheduleAppointment, cancelAppointment
│   ├── Estimate (4): getEstimates ★, createEstimate, acceptEstimate, declineEstimate ★
│   ├── Invoice/Billing (2): getInvoices, getAccountBalance
│   ├── Service Catalog (1): getServices
│   └── Company/Meta (2): getCompanyInfo ★, checkServiceArea ★
│
└── EXTENDED TIER (implement if platform supports, else return null/empty)
    ├── Memberships (2): getMemberships ★, getMembershipTypes ★
    └── Tasks (1): createTask ★

★ = NEW method
```

### Platform Implementation Complexity

| Platform | Core Methods | Extended Methods | Total Effort |
|----------|-------------|-----------------|--------------|
| **Jobber** | 29/29 (2 throw UNSUPPORTED: deleteProperty, declineEstimate) | 0/3 (all return null) | Low — existing adapter, ~200 lines new |
| **ServiceTitan** | 29/29 (full coverage) | 3/3 (full coverage) | Medium — new adapter, ~2000 lines |
| **Housecall Pro** | 29/29 (1 throws UNSUPPORTED: deleteProperty) | 0/3 (all return null) | Medium — new adapter, ~1500 lines |
