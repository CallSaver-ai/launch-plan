# Service Fusion Integration Plan

> **Date:** 2026-02-24
> **Status:** Planning
> **API Docs:** `servicefusion-specs/servicefusion-api-docs.md`

## 1. Resource Mapping: Service Fusion vs Jobber vs HCP

### How the three platforms differ

| Our Concept | Jobber | HCP | Service Fusion | Notes |
|---|---|---|---|---|
| **Customer** | Client (GraphQL) | Customer (REST) | Customer (REST) | SF has contacts + locations nested inside customer — very similar to HCP |
| **Property / Address** | Property (GraphQL, separate entity) | Address (nested on customer) | Location (nested array on customer) | SF locations are embedded in customer JSON, not a separate CRUD endpoint. Created inline with `POST /customers` via `locations[]` |
| **Service Request** | Request (GraphQL) | Lead (REST) | **Job** (REST, status-based) | SF has no "lead" or "request" entity. The equivalent is creating a Job in an initial status (e.g. "Pending"). SF uses `sources` for attribution. |
| **Assessment** | Assessment (auto-created per Request) | Estimate (converted from Lead) | **N/A — no distinct assessment** | SF Jobs go directly to scheduling. No pre-sale visit concept. Use the Job itself + a "pending" status. |
| **Estimate / Quote** | Quote (GraphQL) | Estimate (REST, with options) | Estimate (REST) | SF has `POST /estimates` and `GET /estimates`. Very similar to our model. |
| **Job** | Job (GraphQL, parent of Visits) | Job (REST, parent of Appointments) | Job (REST, has `visits` expand) | SF Jobs contain embedded visits. `expand=visits` to get them. |
| **Appointment / Visit** | Visit (child of Job) | Appointment (child of Job) | Visit (embedded in Job via expand) | SF visits are embedded — no separate CRUD for visits. Created as part of Job or via `techs_assigned` + scheduling. |
| **Invoice** | Invoice (GraphQL) | Invoice (REST) | Invoice (REST) | SF has `GET /invoices`, `GET /invoices/{id}`. Read-only, same as our pattern. |
| **Services / Catalog** | ProductOrService (GraphQL) | Price Book Services (REST) | **Job Categories** (REST) | SF has no "services" or "price book" — `job-categories` is the closest analog (e.g. "HVAC", "Plumbing", "Electrical"). See analysis below. |
| **Technician** | N/A (assignedUsers on Visit) | Employees (assigned to Job) | Techs (REST) | SF has full `GET /techs` endpoint with departments, bios, dispatch nicknames. |
| **Source / Attribution** | Source set via requestDetails | Lead Source (REST) | Sources (REST) | SF has `GET /sources` — we create/find a "CallSaver" source for attribution on jobs. |
| **Service Area** | N/A (uses Location.serviceAreas) | Service Zones (REST, zip code) | **N/A** | SF has no service zone API. Use `Location.serviceAreas` fallback (same as Jobber). |
| **Company Info** | N/A (uses Location.googlePlaceDetails) | `GET /company` | `GET /me` (limited) | SF `/me` only returns user info (name, email), not company info. Use Location.googlePlaceDetails fallback. |
| **Calendar Tasks** | N/A | N/A | CalendarTasks (REST) | Unique to SF — could map to our `createTask` extended method. |
| **Equipment** | N/A | N/A | Equipment (nested under customer) | SF tracks customer equipment. Nice-to-have, not MVP. |
| **Memberships** | N/A | N/A | **N/A** | Not in SF API. Return null. |
| **Payment Types** | N/A | N/A | Payment Types (REST) | SF has a read-only payment types endpoint. |

### Key architectural differences

1. **No Lead/Request entity.** SF creates a Job directly (like Jobber's Job, not Jobber's Request). Our `createServiceRequest` will map to `POST /v1/jobs` with an initial status. The "request" and "assessment" concepts collapse into a single Job.

2. **Locations are embedded in Customer.** SF doesn't have separate property CRUD. `POST /customers` accepts `locations[]` in the body. `listProperties` will parse `customer.locations`. `createProperty` will need to re-POST the customer with the updated locations array (or use the first available location).

3. **No availability/scheduling endpoint.** SF has no `booking_windows` or `scheduledItems` equivalent. `checkAvailability` will need to fall back to the same business-hours-based approach we use for Jobber (query existing items, compute gaps against business hours).

4. **Visits are embedded in Jobs.** SF uses `expand=visits` on the jobs endpoint. No separate `POST /jobs/{id}/appointments`. Visits contain `techs_assigned`. Creating an appointment means creating a Job with visit data.

5. **Services → Job Categories.** SF's `job-categories` (e.g. "HVAC Repair", "Plumbing") is the service catalog equivalent. However, these are **categories**, not individual services with prices. If the SF account has very generic categories, we may need to supplement with `Location.services` for granular service listings. The adapter should try `GET /job-categories` first; if the results are too few/generic, fall back to `Location.services`.

6. **OAuth 2.0 with Client Credentials.** SF supports both Authorization Code Grant and Client Credentials Grant. For our integration, we'll support both:
   - **Client Credentials** (simpler): user enters Client ID + Secret from their SF account → we exchange for token. This is like HCP's API key flow but with a token exchange step.
   - **Authorization Code** (via Pipedream): full OAuth redirect flow.
   - **MVP recommendation**: Client Credentials (API key-like UX, stored as encrypted credentials in OrganizationIntegration).

## 2. Adapter Method Implementation Plan (34 methods)

### Full support (straightforward mapping)

| Method | SF API Call | Notes |
|---|---|---|
| `findCustomerByPhone` | `GET /customers?filters[phone]=X` | SF supports filtering by any field. Contact phones are nested — may need to filter in code. |
| `createCustomer` | `POST /customers` | Include contacts[] with phone, locations[] with address |
| `updateCustomer` | N/A — SF has no `PUT /customers` | Throw UNSUPPORTED_OPERATION or implement as notes |
| `listProperties` | `GET /customers/{id}?expand=locations` | Parse customer.locations array |
| `createProperty` | N/A — locations are inline on customer | See workaround below |
| `updateProperty` | N/A | Throw UNSUPPORTED_OPERATION |
| `deleteProperty` | N/A | Throw UNSUPPORTED_OPERATION |
| `createServiceRequest` | `POST /jobs` (with initial status) | Set `source` to "CallSaver", include customer_name, description, service address |
| `getRequest` | `GET /jobs/{id}?expand=visits,techs_assigned,custom_fields` | Map Job to ServiceRequest shape |
| `getRequests` | `GET /jobs?filters[customer_id]=X&sort=-created_at` | Filter by customer, map to ServiceRequest[] |
| `submitLead` | Orchestrate: findCustomer → createCustomer → POST /jobs | Same pattern as Jobber/HCP |
| `getJobs` | `GET /jobs?filters[customer_id]=X` | With expand=visits,techs_assigned |
| `getJobByNumber` | `GET /jobs?filters[number]=X` | SF jobs have a `number` field |
| `addNoteToJob` | N/A — no `POST /jobs/{id}/notes` | SF has `tech_notes` and `completion_notes` fields but no append API. Best effort: use `description` field or throw UNSUPPORTED. |
| `cancelJob` | N/A — no status update endpoint | SF has no `PUT /jobs/{id}`. Throw UNSUPPORTED_OPERATION. |
| `getEstimates` | `GET /estimates?filters[customer_id]=X` | Direct mapping |
| `createEstimate` | `POST /estimates` | Direct mapping |
| `acceptEstimate` | N/A — no approve endpoint | Throw UNSUPPORTED_OPERATION |
| `declineEstimate` | N/A — no decline endpoint | Throw UNSUPPORTED_OPERATION |
| `getInvoices` | `GET /invoices?filters[customer_id]=X` | Direct mapping (use customer_id filter if supported, else fetch and filter) |
| `getAccountBalance` | `GET /customers/{id}` → `account_balance` | SF Customer has `account_balance` field! |
| `getServices` | `GET /job-categories` | Map categories to Service[]. Fallback to Location.services if too generic. |
| `getCompanyInfo` | Return null | No company info endpoint. Tool layer uses Location.googlePlaceDetails. |
| `checkServiceArea` | Return null | No service zones. Tool layer uses Location.serviceAreas. |
| `getMemberships` | Return null | Not in SF API. |
| `getMembershipTypes` | Return null | Not in SF API. |
| `createTask` | `POST /calendar-tasks` (if supported) or return null | SF has calendar-tasks but only GET endpoints. Return null. |

### Methods requiring workarounds

| Method | Approach |
|---|---|
| `createProperty` | Since SF locations are embedded in customer, we'd need to GET the customer, append to locations[], then... there's no PUT customer. **Workaround**: Create the location inline when creating the customer (in `createCustomer`). For existing customers, this is UNSUPPORTED — store the address in the Job instead. |
| `createAssessment` | SF has no assessment concept. `createServiceRequest` creates the Job directly. Return a synthetic assessment object from the Job data. If autoScheduleAssessment is on, the "assessment" IS the Job's first visit. |
| `cancelAssessment` | Map to cancelJob (which itself may be unsupported via API). Best effort. |
| `rescheduleAssessment` | SF has no visit update API. Throw UNSUPPORTED_OPERATION or return synthetic data. |
| `checkAvailability` | No scheduling API. Use business-hours-based computation like Jobber: query existing jobs with visits in date range, compute gaps. Or fall back to "always available during business hours" if visits aren't queryable. |
| `createAppointment` | Since visits are embedded in Jobs, this maps to creating a Job with visit data (techs_assigned, start_date, end_date). |
| `getAppointments` | `GET /jobs?expand=visits` → extract visits from each job |
| `rescheduleAppointment` | No visit update API. Throw UNSUPPORTED_OPERATION. |
| `cancelAppointment` | No visit/appointment delete. Throw UNSUPPORTED_OPERATION. |
| `getClientSchedule` | Combine: `GET /jobs?expand=visits` + `GET /estimates` + `GET /calendar-tasks` |

### Assessment terminology for SF

Since SF has no assessment/consultation pre-sale concept, the system prompt should use **"job"** as the assessment entity:
- `assessmentEntity = 'job'`
- `assessmentEntityCap = 'Job'`
- autoScheduleAssessment flow: check availability → create a Job with visit timing

## 3. Implementation Phases

### Phase 1: Core Adapter + Client (MVP) — ~6-8 hours

**Files to create:**
- `src/adapters/field-service/platforms/servicefusion/ServiceFusionClient.ts` — REST client with OAuth token management (client_credentials grant, token refresh)
- `src/adapters/field-service/platforms/servicefusion/ServiceFusionAdapter.ts` — implements all 34 FieldServiceAdapter methods

**Files to modify:**
- `FieldServiceAdapterFactory.ts` — uncomment SF import, wire up the case
- `FieldServiceAdapterRegistry.ts` — add `'servicefusion'` to `API_KEY_PLATFORMS` (client credentials stored as apiKey-like flow in OrganizationIntegration)
- `field-service-tools.ts` line 39-52 — add `servicefusion` case to `buildExternalRequestUrl()`

**MVP method implementations:**
1. **findCustomerByPhone** — `GET /customers?filters[contacts.phones.phone]=X` or fetch + filter in code
2. **createCustomer** — `POST /customers` with contacts[{phones}] and locations[]
3. **createServiceRequest** → `POST /jobs` with source, description, customer_name, address fields
4. **getRequest** → `GET /jobs/{id}?expand=visits,techs_assigned`
5. **getRequests** → `GET /jobs?filters[customer_id]=X`
6. **submitLead** — orchestrated flow (same pattern as Jobber/HCP)
7. **getJobs** → `GET /jobs?filters[customer_id]=X&expand=visits`
8. **getEstimates** → `GET /estimates?filters[customer_id]=X`
9. **createEstimate** → `POST /estimates`
10. **getInvoices** → `GET /invoices` (filter by customer)
11. **getAccountBalance** → customer.account_balance
12. **getServices** → `GET /job-categories` (map to Service[])
13. Return null for: getCompanyInfo, checkServiceArea, getMemberships, getMembershipTypes, createTask
14. Throw UNSUPPORTED_OPERATION for: updateCustomer, updateProperty, deleteProperty, cancelJob, addNoteToJob, acceptEstimate, declineEstimate, rescheduleAppointment, cancelAppointment

### Phase 2: System Prompt + Frontend — ~3-4 hours

**Backend:**
- `server.ts` (~line 9171): Add `servicefusion` detection in fsInstructions generation
  - Platform detection: check OrganizationIntegration where platform='servicefusion'
  - `platformName = 'Service Fusion'`
  - `assessmentEntity = 'job'` (SF has no assessment concept)
  - `isServiceFusion = true` → skip service area step (uses Location.serviceAreas)
  - `idNote` → "Service Fusion uses plain integer IDs."
- `utils.ts`: Add `'servicefusion'` to the fs platform switch for prompt generation
  - Services: try `getServices()` (job-categories), fall back to Location.services if empty/too generic

**Frontend:**
- `integrations-config.ts` — add `service-fusion` entry with `authType: 'oauth_credentials'` (client ID + secret)
- `app-sidebar.tsx` — add SF nomenclature (same as HCP basically — "Jobs", Briefcase icon)
- `IntegrationsPage.tsx` / `OnboardingPage.tsx` — add SF connection flow (enter Client ID + Client Secret)

### Phase 3: Scheduling + Availability — ~3-4 hours (post-launch)

- Implement `checkAvailability` using business-hours computation (similar to Jobber approach)
- Query `GET /jobs?expand=visits` for the date range, extract booked slots
- Compute gaps against Location.businessHours
- `createAppointment` → `POST /jobs` with `techs_assigned`, `start_date`, `end_date`
- `getAppointments` → extract visits from jobs
- `getClientSchedule` → aggregate jobs + estimates + calendar-tasks

### Phase 4: Polish + Edge Cases — ~2-3 hours (post-launch)

- `createProperty` workaround: store address on the Job when customer already exists
- Equipment tracking (SF unique feature)
- Calendar tasks integration
- `GET /sources` — auto-create "CallSaver" source on first use
- Test script: `testing/test-servicefusion-integration.sh`

## 4. Auth Flow Design

Service Fusion supports OAuth 2.0 with two grant types. For MVP, **Client Credentials** is simplest:

```
User enters Client ID + Client Secret (from SF admin panel)
  → Backend exchanges for access_token via POST /oauth/access_token
  → Token stored in OrganizationIntegration (encrypted)
  → Token auto-refreshed via refresh_token when expired (1 hour TTL)
```

**ServiceFusionClient.ts** needs:
- `clientId` + `clientSecret` stored in OrganizationIntegration.config
- `accessToken` + `refreshToken` + `expiresAt` managed internally
- Auto-refresh on 401 or pre-emptive refresh when `expiresAt` is within 5 minutes
- Base URL: `https://api.servicefusion.com/v1`
- Rate limit: 60 req/min (respect `X-Rate-Limit-*` headers)

**Registry changes:**
- Add `'servicefusion'` to `API_KEY_PLATFORMS` in FieldServiceAdapterRegistry.ts
- `buildApiKeyConfig` will read `config.clientId` + `config.clientSecret` from OrganizationIntegration
- ServiceFusionAdapter constructor accepts `{ clientId, clientSecret }` instead of `{ apiKey }`

## 5. Key Limitations vs Jobber/HCP

| Feature | Jobber | HCP | Service Fusion |
|---|---|---|---|
| Customer phone search | searchTerm query | `?phone=X` filter | `?filters[field]=X` (may need code filter) |
| Update customer | ✅ clientEdit mutation | ✅ `PUT /customers/{id}` | ❌ No PUT endpoint |
| Service request / Lead | ✅ Request entity | ✅ Lead entity | ❌ → Maps to Job |
| Assessment / Consultation | ✅ Auto-created | ✅ Via lead convert | ❌ → Job IS the assessment |
| Check availability | ✅ scheduledItems query | ✅ booking_windows API | ❌ → Compute from business hours |
| Create appointment | ✅ assessmentEdit / visitCreate | ✅ `POST /jobs/{id}/appointments` | ❌ → Embedded in Job creation |
| Reschedule appointment | ✅ assessmentEdit | ✅ `PUT /jobs/{id}/appointments/{id}` | ❌ No visit update |
| Cancel appointment | ✅ | ✅ `DELETE /jobs/{id}/appointments/{id}` | ❌ No visit delete |
| Accept/decline estimate | ✅ quoteApprove | ✅ options/approve, options/decline | ❌ No approve/decline |
| Add note to job | ✅ | ✅ `POST /jobs/{id}/notes` | ❌ No notes endpoint |
| Service catalog | ✅ ProductOrService | ✅ Price Book | ⚠️ Job Categories only (no pricing) |
| Service zones | ❌ (Location.serviceAreas) | ✅ `GET /service_zones` | ❌ (Location.serviceAreas) |
| Company info | ❌ (Location fallback) | ✅ `GET /company` | ❌ (Location fallback) |
| Calendar tasks | ❌ | ❌ | ✅ Read-only |
| Equipment tracking | ❌ | ❌ | ✅ Per-customer |
| Technicians list | ❌ (embedded) | ❌ (embedded) | ✅ `GET /techs` |

## 6. Estimated Total Effort

| Phase | Hours | Priority |
|---|---|---|
| Phase 1: Core adapter + client | 6-8 | P0 (launch) |
| Phase 2: System prompt + frontend | 3-4 | P0 (launch) |
| Phase 3: Scheduling + availability | 3-4 | P1 (post-launch) |
| Phase 4: Polish + edge cases | 2-3 | P2 (post-launch) |
| **Total** | **14-19 hours** | |

## 7. File Inventory

### New files (Phase 1)
- `src/adapters/field-service/platforms/servicefusion/ServiceFusionClient.ts`
- `src/adapters/field-service/platforms/servicefusion/ServiceFusionAdapter.ts`

### Modified files (Phase 1-2)
- `src/adapters/field-service/FieldServiceAdapterFactory.ts` — wire up SF
- `src/adapters/field-service/FieldServiceAdapterRegistry.ts` — add to API_KEY_PLATFORMS
- `src/routes/field-service-tools.ts` — add SF external URL builder
- `src/server.ts` — add SF platform detection + fsInstructions
- `src/utils.ts` — add SF to prompt switch

### Frontend (Phase 2)
- `integrations-config.ts` — add service-fusion config
- `app-sidebar.tsx` — add SF nomenclature
- `IntegrationsPage.tsx` — add SF connection UI
- `OnboardingPage.tsx` — add SF onboarding flow

### Test files
- `testing/test-servicefusion-integration.sh`
