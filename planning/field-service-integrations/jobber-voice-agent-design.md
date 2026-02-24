# Jobber Voice Agent — Comprehensive Design

> How the CallSaver voice agent interacts with Jobber's data model across all customer scenarios.
> This replaces the earlier `jobber-voice-agent-intents.md` with a more complete design.

---

## 1. Jobber Data Model & Lifecycle

```
Client ←——→ Property (1:many)
  │              │
  ▼              ▼
Request ←——→ Property (request.property)
  │
  ├──→ Assessment (site visit / consultation, scheduled on Request)
  │       └── assignedUsers, startAt, endAt
  │
  ├──→ Quote (pricing estimate sent to client)
  │       └── quoteStatus: DRAFT | AWAITING_RESPONSE | APPROVED | ...
  │
  └──→ Job (approved scope of work — created from Quote or directly)
        │
        ├──→ Visit (scheduled calendar event to do the work)
        │       └── visitStatus, startAt, endAt, assignedUsers
        │
        └──→ Invoice (billing after work)
                └── invoiceStatus: DRAFT | AWAITING_PAYMENT | PAID | ...
```

### Key relationships:
- **Client** has many Properties, Requests, Jobs, Quotes, Invoices
- **Property** has many Requests, Jobs, Quotes — it's the service address
- **Request** is the entry point (lead). It can have an **Assessment** (consultation visit), then gets **Quotes**, then converts to **Jobs**
- **Job** has **Visits** (scheduled work events) and **Invoices**
- **Assessment** is a special scheduled event tied to a Request (pre-sale site visit)

### What the voice agent creates vs what the contractor handles:

| Entity | Voice Agent Creates? | Notes |
|--------|---------------------|-------|
| Client | ✅ Yes | New callers → create Client |
| Property | ✅ Yes | Collect address → create Property |
| Request | ✅ Yes | Core lead capture |
| Assessment | ⚠️ Conditionally | Auto-schedule if toggle enabled, otherwise contractor schedules |
| Quote | ❌ No | Contractor creates in Jobber |
| Job | ❌ No | Created when Quote approved or contractor converts Request |
| Visit | ❌ No | Contractor schedules |
| Invoice | ❌ No | Contractor creates |

---

## 2. The `source` Field

Every Request in Jobber has a `source: String!` field. When we create Requests via the API, we should tag them:

```
source: "CallSaver AI"
```

This lets contractors filter/identify which requests came through the voice agent vs their website form vs walk-ins. The `source` is likely set via the `requestDetails` field in `RequestCreateInput`:

```graphql
input RequestCreateInput {
  clientId: EncodedId!
  propertyId: EncodedId
  assessment: AssessmentAttributes  # Schedule a consultation
  referringClientId: EncodedId
  requestDetails: RequestDetailsInput  # Contains source, contactName, email, phone, companyName
  title: String
}
```

If `requestDetails` doesn't support `source` (it may be auto-set by Jobber based on API origin), we need to test this. Worst case, Jobber may auto-tag API-created requests as "API" or "Other". We should verify during testing.

**Action item:** Test whether `requestDetails.source` or similar field lets us set the source string. If not, we'll prepend "[CallSaver]" to the request title as a fallback identifier.

---

## 3. Scenario 1: New Unknown Caller Requests Service

**The most common call.** A new person calls, wants to get work done.

### Voice agent collects:
1. **Name** (first + last) — required for Client creation
2. **Phone** — already have from incoming call
3. **Email** — optional but encouraged ("for the quote")
4. **Service address** (street, city, state, zip) — required for Property
5. **Service description** — what work they need ("backyard landscaping", "AC repair")
6. **Urgency** — normal or emergency

### API flow:
```
1. jobber-get-customer-by-phone → NOT FOUND
2. jobber-create-customer(firstName, lastName, email, phone)
3. jobber-create-property(customerId, address)
4. jobber-create-service-request(customerId, propertyId, title, requestDetails, assessment?)
```

### The Assessment question:

`RequestCreateInput` accepts an `assessment` field (type `AssessmentAttributes`) which can schedule a consultation visit as part of request creation. This is the site visit where the contractor goes to look at the property and scope the work before quoting.

**Two modes:**

#### Mode A: Auto-schedule Assessment (toggle ON in CallSaver settings)
The voice agent checks the contractor's calendar for available slots and schedules the assessment automatically:

```
1. Check calendar for available assessment slots (need: get existing assessments + visits)
2. Offer the caller 2-3 available time slots
3. Caller picks one
4. Create Request with assessment: { startAt, endAt, title, instructions }
```

This requires:
- A way to read the contractor's schedule (assessments + visits) to find gaps
- Business hours configuration (what hours are assessments allowed?)
- Assessment duration default (e.g., 30 min, 1 hour)
- Possibly: assigned user/crew for the assessment

**Complexity:** Medium-high. Requires calendar gap-finding logic. Could be a Phase 2 feature.

#### Mode B: No auto-schedule (toggle OFF — default for MVP)
The voice agent creates the Request without an Assessment. The contractor sees it in their Jobber dashboard and schedules the assessment themselves (or from our web UI).

```
1. Create Request (no assessment field)
2. Tell caller: "I've submitted your request. Our team will contact you to schedule a consultation."
```

**Complexity:** Low. This is the MVP path.

#### Recommended approach:
- **MVP (Phase 1):** Mode B — create Request without Assessment. Contractor schedules.
- **Phase 2:** Mode A — auto-schedule with calendar checking. Toggleable per location.
- **Future:** Our web UI shows a "Schedule Assessment" button on unscheduled Requests.

### Submit-new-lead endpoint (single orchestrated call):

```
POST /internal/tools/jobber-submit-new-lead
{
  locationId, callerPhoneNumber,
  firstName, lastName, email,
  address: { street, city, state, zipCode },
  serviceDescription,
  priority: "normal" | "emergency"
}

Response: {
  customer: { id, name, ... },
  property: { id, address, ... },
  serviceRequest: { id, title, status, ... },
  customerCreated: true,
  message: "Request submitted for 'backyard landscaping' at 742 Evergreen Terrace. Our team will review and follow up."
}
```

---

## 4. Scenario 2: Existing Client Checks Status

**Second most common call.** The client from Scenario 1 calls back.

### What they want to know:
1. "What's happening with my request?" → Request status
2. "Is there an assessment scheduled?" → Assessment details (date, time, who's coming)
3. "Did you send me a quote?" → Quotes linked to the Request
4. "Who is assigned to come out?" → Assessment.assignedUsers

### Voice agent flow:
```
1. jobber-get-customer-by-phone → FOUND (customerId)
2. jobber-get-requests(customerId) → list of requests with status
3. For each relevant request:
   a. Check request.assessment → is there a scheduled assessment?
   b. Check request.quotes → are there quotes?
   c. Check request.jobs → has it been converted to a job?
```

### What the agent tells the caller:

**Request pending, no assessment:**
> "Your request for backyard landscaping is currently awaiting review. No consultation has been scheduled yet — our team will reach out to set that up."

**Request with scheduled assessment:**
> "Your request for backyard landscaping has a consultation scheduled for Thursday, March 5th at 10 AM. [John Smith] will be coming out to assess the property."

**Request with quote sent:**
> "A quote has been sent for your backyard landscaping request. Please check your email for the details. The quoted amount is $2,500."

**Request converted to job:**
> "Your backyard landscaping has been approved and scheduled. You have a visit on March 15th from 8 AM to 12 PM."

### Required tools:
| Tool | Purpose |
|------|---------|
| `jobber-get-customer-by-phone` | Identify caller |
| `jobber-get-requests` | List their requests (includes assessment, quotes, jobs) |
| `jobber-get-request` | Detailed single request (with quotes, assessment, jobs) |

### Data we need from the Request query:
```graphql
request {
  id, title, requestStatus, source, createdAt
  assessment {
    id, startAt, endAt, isComplete, title, instructions
    assignedUsers { nodes { id, name { full } } }
  }
  quotes(first: 5) {
    nodes { id, quoteNumber, quoteStatus, amounts { total }, title }
  }
  jobs(first: 5) {
    nodes {
      id, jobNumber, title, jobStatus
      visits(first: 3) {
        nodes { id, startAt, endAt, visitStatus, assignedUsers { nodes { name { full } } } }
      }
    }
  }
  property {
    id, address { street1, city, province, postalCode }
  }
}
```

**Action item:** Update `getRequest` and `getRequests` adapter methods to include `assessment` and richer `quotes`/`jobs` data in the GraphQL query.

---

## 5. Assessment Management

### Cancel Assessment
Client calls to cancel their scheduled consultation.

```
1. jobber-get-customer-by-phone → identify
2. jobber-get-requests → find request with assessment
3. Confirm: "Cancel your consultation on Thursday at 10 AM?"
4. jobber-cancel-assessment(assessmentId) → cancel/delete
5. "Your consultation has been cancelled. Would you like to reschedule?"
```

**Jobber API:** Need to check if there's an `assessmentDelete` or `assessmentUpdate(isComplete: true)` mutation. If Jobber doesn't have a direct cancel mutation, we may need to update the assessment to mark it or add a note.

### Reschedule Assessment
Client calls to move their consultation.

```
1. jobber-get-customer-by-phone → identify
2. jobber-get-requests → find request with assessment
3. Ask for new preferred time
4. Check calendar for availability (Phase 2)
5. jobber-reschedule-assessment(assessmentId, newStartAt, newEndAt)
6. "Your consultation has been moved to Friday at 2 PM."
```

**Jobber API:** Likely `assessmentUpdate` mutation with new `startAt`/`endAt`.

### Tools needed:
| Tool | Mutation | Priority |
|------|----------|----------|
| `jobber-get-assessment` | query | Phase 1 |
| `jobber-reschedule-assessment` | assessmentUpdate | Phase 2 |
| `jobber-cancel-assessment` | assessmentDelete or update | Phase 2 |

---

## 6. Scenario 3: Existing Client — Jobs, Visits, Invoices

### Intent 3A: "When is my next appointment?" / "When are you coming?"
Client has an active Job with scheduled Visits.

```
1. jobber-get-customer-by-phone → identify
2. jobber-get-client-work-objects(customerId) → get all work items sorted by date
   OR
   jobber-get-appointments(callerPhoneNumber) → get upcoming visits
3. Read back: "You have a visit scheduled for March 15th from 8 AM to 12 PM for your backyard landscaping job."
```

If no visits but has a Job:
> "You have an active job for backyard landscaping but no visit has been scheduled yet. Would you like me to note that you'd like to get scheduled?"

### Intent 3B: "I need to reschedule my visit"
```
1. Identify caller → find their visits
2. Show which visit: "You have a visit on March 15th. Is that the one?"
3. "When would you prefer instead?"
4. jobber-reschedule-appointment(visitId, newStartAt, newEndAt)
5. Confirm new time
```

### Intent 3C: "I need to cancel"
```
1. Identify → find visits
2. Confirm: "Cancel your visit on March 15th?"
3. jobber-cancel-appointment(visitId)
4. "Your visit has been cancelled. Would you like to reschedule?"
```

### Intent 3D: "How much do I owe?" / Invoice questions
```
1. Identify caller
2. jobber-get-account-balance(customerId) → total balance
3. "Your current balance is $1,250."
4. If they want details: jobber-get-invoices(customerId)
5. "You have an invoice #1042 for $1,250, issued March 20th, due April 3rd."
```

### Intent 3E: "I have a question about my job" / General job inquiry
```
1. Identify caller
2. jobber-get-jobs(customerId) → list active jobs
3. Read back job status, what's included, scheduled visits
4. If they have a concern: jobber-add-note-to-job(jobId, note) → flag for contractor
```

### Intent 3F: "I want to request additional work"
Existing client wants MORE work done (new service, different property, etc.)

```
1. Identify caller (already a Client)
2. Collect: what service, which property (or new address)
3. If new address → jobber-create-property
4. jobber-create-service-request → new Request
5. "I've submitted a new request for [service]. Our team will follow up with a quote."
```

---

## 7. Emergency Handling

**"My pipe burst" / "There's a leak" / urgent**

```
1. Identify caller (create Client if new)
2. Collect address if new
3. jobber-create-service-request(priority: "emergency")
   - Title: "[EMERGENCY] Pipe burst at 742 Evergreen Terrace"
   - Source: "CallSaver AI"
4. "I've flagged this as an emergency. Let me try to connect you with someone directly."
5. Attempt warm transfer to contractor's phone
6. If no answer: "I wasn't able to reach anyone, but your emergency request has been submitted with highest priority. Someone will call you back as soon as possible."
```

---

## 8. Services: Jobber as Source of Truth

### Current state (Google Calendar mode):
- Services defined on the `Location` model in our DB
- User sets them up during onboarding
- Voice agent uses `location.services` to know what the business offers
- Used for: service catalog, booking categorization

### With Jobber connected:
Jobber has `ProductOrService` entities with:
- `name`, `description`, `category` (SERVICE or PRODUCT)
- `defaultUnitCost` (price)
- `durationMinutes` (for scheduling)
- `onlineBookingEnabled` (which services are publicly bookable)
- `visible` (active/inactive)

**When Jobber is connected, `ProductOrService` should be the source of truth for services.**

### The onboarding problem:

Current onboarding flow:
```
1. Create account
2. Set up business info
3. Define services ← here, user manually types services
4. Configure voice agent
5. Connect integrations (Jobber, etc.) ← currently at the END
6. Done
```

If they connect Jobber at step 5, the manually-entered services from step 3 are now redundant — Jobber already has the real service list.

### Proposed adaptation:

#### Option A: Move integration connection to step 2 (recommended)
```
1. Create account
2. "Do you use field service software?" → Connect Jobber (if yes)
3. If Jobber connected:
   - Auto-import services from Jobber ProductOrService
   - Skip manual service entry
   - Pre-fill business info from Jobber account
4. If no integration:
   - Manual service entry (current flow)
5. Configure voice agent
6. Done
```

**Pros:** Cleanest UX. No duplicate data entry.
**Cons:** Requires Nango OAuth flow early in onboarding. User might not be ready to connect yet.

#### Option B: Detect and reconcile
```
1-3. Current flow (manual service entry)
4. Connect Jobber
5. "We found X services in your Jobber account. Would you like to use those instead?"
   - Yes → replace Location.services with Jobber services
   - No → keep manual services (unusual but possible)
6. Done
```

**Pros:** Non-breaking change. Works with current flow.
**Cons:** User enters services twice if they choose to sync.

#### Option C: Hybrid — services always from integration when connected
- `Location.services` is the default source
- When `location.fieldServicePlatform === 'jobber'`, voice agent fetches services from Jobber API at runtime
- Onboarding still has manual service entry as fallback
- A sync function periodically updates `Location.services` from Jobber (cache)

**Pros:** Most flexible. Doesn't require onboarding changes.
**Cons:** Runtime API call adds latency. Need cache/sync logic.

### Recommendation:
**Phase 1 (now):** Option C — keep onboarding as-is, but when Jobber is connected, the voice agent calls `jobber-get-services` to get the real service list. Cache the result on the Location model periodically.

**Phase 2 (later):** Option A — restructure onboarding to connect integration first when available.

### Implementation for Phase 1:
```typescript
// In the voice agent tool resolution:
async function getAvailableServices(locationId: string): Promise<Service[]> {
  const location = await getLocation(locationId);
  
  if (location.fieldServicePlatform === 'jobber') {
    // Fetch from Jobber (cached)
    return await jobberAdapter.getServices(context);
  }
  
  // Fallback to Location.services
  return location.services;
}
```

---

## 9. Tool Inventory — Complete

### Phase 1: Lead Capture (MVP)
These are needed for the core new-caller flow:

| # | Tool | Purpose | Status |
|---|------|---------|--------|
| 1 | `jobber-get-customer-by-phone` | Identify caller | ✅ Done |
| 2 | `jobber-create-customer` | Create new Client | ✅ Done |
| 3 | `jobber-create-property` | Create Property (service address) | ✅ Done |
| 4 | `jobber-create-service-request` | Create Request (with source, propertyId) | ✅ Done (needs source update) |
| 5 | `jobber-submit-new-lead` | Orchestrated: Client+Property+Request | ⚠️ In progress |
| 6 | `jobber-get-requests` | List customer's requests | ✅ Done |
| 7 | `jobber-get-request` | Get request detail (needs assessment+quotes) | ✅ Done (needs query update) |
| 8 | `jobber-get-services` | Get service catalog from Jobber | ✅ Done |

### Phase 2: Status Checking & Assessment Management
For returning callers:

| # | Tool | Purpose | Status |
|---|------|---------|--------|
| 9 | `jobber-get-assessment` | Get assessment details for a request | ❌ New |
| 10 | `jobber-reschedule-assessment` | Move assessment to new time | ❌ New |
| 11 | `jobber-cancel-assessment` | Cancel a scheduled assessment | ❌ New |
| 12 | `jobber-get-appointments` | Get upcoming visits | ✅ Done |
| 13 | `jobber-get-jobs` | Get active jobs | ✅ Done |
| 14 | `jobber-get-schedule` | Get calendar (assessments + visits) for gap-finding | ❌ New |

### Phase 3: Active Work Management
For clients with jobs/visits:

| # | Tool | Purpose | Status |
|---|------|---------|--------|
| 15 | `jobber-reschedule-appointment` | Reschedule a visit | ✅ Done |
| 16 | `jobber-cancel-appointment` | Cancel a visit | ✅ Done |
| 17 | `jobber-add-note-to-job` | Add note/flag to a job | ✅ Done |

### Phase 4: Billing & Account
Lower priority:

| # | Tool | Purpose | Status |
|---|------|---------|--------|
| 18 | `jobber-get-account-balance` | Check what they owe | ✅ Done |
| 19 | `jobber-get-invoices` | Invoice details | ✅ Done |
| 20 | `jobber-update-customer` | Update contact info | ✅ Done |
| 21 | `jobber-update-property` | Update address | ✅ Done |
| 22 | `jobber-list-properties` | List service addresses | ✅ Done |

---

## 10. System Prompt Design

The voice agent system prompt needs to be Jobber-aware:

```
You are a receptionist for [Business Name], a [service type] company.

When a customer calls:

FOR NEW CALLERS:
1. Look up their phone number. If not found, they're a new customer.
2. Collect: first name, last name, email address, and service address.
3. Ask what service they need and any details about the work.
4. Submit a service request. Tell them: "I've submitted your request. Our team will review it and follow up with a quote."
5. Do NOT schedule appointments or give pricing — that's handled by our office.

FOR RETURNING CALLERS:
1. Look up their phone number to identify them. Greet them by name.
2. Ask how you can help.

If they ask about REQUEST STATUS:
- Check their requests. Tell them the status and any scheduled assessment or quotes.

If they ask about APPOINTMENT/VISIT:
- Check their upcoming visits. Read back date, time, and what it's for.
- If they want to reschedule or cancel, handle it.

If they ask about BILLING:
- Check their account balance and invoices.

If they want NEW WORK:
- Collect service details and address (may be a different property).
- Submit a new service request.

If it's an EMERGENCY:
- Flag the request as emergency priority.
- Try to transfer to [contractor phone number].

TERMINOLOGY:
- "Request" = a submitted work request (hasn't been quoted yet)
- "Assessment" = a scheduled consultation/site visit (before quoting)
- "Quote" = a pricing estimate sent to the customer
- "Job" = approved work (quote accepted)
- "Visit" = a scheduled event to do the work
- Never use internal terms like "Client" — say "customer" or use their name.
```

---

## 11. Open Questions

1. **Can we set `source` on RequestCreateInput?** Need to test if `requestDetails.source` is writable or if Jobber auto-sets it. Fallback: prepend "[CallSaver]" to title.

2. **Assessment mutations:** Need to verify exact Jobber API mutations for `assessmentCreate`, `assessmentUpdate`, `assessmentDelete`. These might be part of `requestUpdate` instead.

3. **Calendar gap-finding for auto-scheduling:** This requires reading all assessments + visits for a date range and finding open slots. Complex but doable. Phase 2.

4. **Multi-property callers:** When a returning client has multiple properties, the agent should ask "which property is this for?" Requires listing properties first.

5. **Assessment auto-scheduling toggle:** Where in our UI does this live? Probably `Location.settings.jobber.autoScheduleAssessment: boolean` with a default duration and business hours.

6. **Quote approval by phone?** Could the agent let a customer approve a quote verbally? ("Your quote is $2,500. Would you like to approve it?") Legally tricky — probably better to direct them to the email/Client Hub link. Deferred.

---

## 12. Implementation Priority

### Now (this session):
- [x] `getRequests` and `getRequest` adapter methods
- [ ] Update `createServiceRequest` to pass `requestDetails` (source: "CallSaver AI")  
- [ ] Update `getRequest` GraphQL query to include assessment, richer quotes/jobs
- [ ] `jobber-submit-new-lead` endpoint (Client + Property + Request)
- [ ] Test with curl

### Next session:
- [ ] Assessment adapter methods (get, create via request)
- [ ] Assessment endpoints
- [ ] Update voice agent intents plan with assessment flow
- [ ] Python LiveKit tools for Phase 1

### Later:
- [ ] Calendar gap-finding for auto-scheduling
- [ ] Assessment reschedule/cancel
- [ ] Onboarding flow adaptation for Jobber services
- [ ] Web UI: "Schedule Assessment" button on Requests page
