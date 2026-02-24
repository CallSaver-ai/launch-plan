# Jobber Voice Agent: Exhaustive Customer Intent Analysis

> Created: Feb 17, 2026
> Status: Complete analysis of all caller intents mapped to Jobber endpoints

---

## Jobber Entity Model

| Entity | Description | Lifecycle |
|--------|-------------|-----------|
| **Client** | Customer record (name, email, phone) | Created on first call, updated as needed |
| **Property** | Service location (address) | Created per address, linked to Client |
| **Request** | Initial service inquiry | Created by voice agent → reviewed by contractor |
| **Assessment** | Pre-sale site visit/consultation | Scheduled on a Request, before quoting |
| **Quote** | Price estimate sent to client | Created by contractor from Request/Assessment |
| **Job** | Contract/scope of work | Created when Quote approved (or directly) |
| **Visit** | Scheduled service appointment | Child of Job, the actual calendar event |
| **Invoice** | Billing document | Generated from completed Job/Visit |

### Entity Flow (typical)
```
Caller → Request → Assessment → Quote → Job → Visit(s) → Invoice
```

---

## Implemented Endpoints (24 total)

| # | Endpoint | Entity | Operation |
|---|----------|--------|-----------|
| 1 | `jobber-get-client-by-phone` | Client | Read |
| 2 | `jobber-create-client` | Client | Create |
| 3 | `jobber-update-client` | Client | Update |
| 4 | `jobber-list-properties` | Property | List |
| 5 | `jobber-create-property` | Property | Create |
| 6 | `jobber-update-property` | Property | Update |
| 7 | `jobber-create-visit` | Visit + Job | Create |
| 8 | `jobber-get-visits` | Visit | List |
| 9 | `jobber-reschedule-visit` | Visit | Update |
| 10 | `jobber-cancel-visit` | Visit | Delete |
| 11 | `jobber-get-jobs` | Job | List |
| 12 | `jobber-get-job` | Job | Read |
| 13 | `jobber-add-note-to-job` | Job | Update |
| 14 | `jobber-get-client-balance` | Client/Invoice | Read |
| 15 | `jobber-get-invoices` | Invoice | List |
| 16 | `jobber-create-service-request` | Request | Create |
| 17 | `jobber-submit-new-lead` | Client+Property+Request | Create (orchestrated) |
| 18 | `jobber-get-request` | Request | Read (enriched with assessment/quotes/jobs) |
| 19 | `jobber-get-requests` | Request | List |
| 20 | `jobber-create-assessment` | Assessment | Create |
| 21 | `jobber-get-services` | ProductOrService | List |
| 22 | `jobber-get-availability` | ScheduledItems | Read (gap analysis) |
| 23 | `jobber-create-estimate` | Quote | Create |
| 24 | `jobber-create-assessment` | Assessment | Create |

---

## Exhaustive Customer Intent Map

### Category 1: Identity & Account Management

| # | Caller Intent (what they say) | Endpoint(s) Used | Coverage |
|---|-------------------------------|------------------|----------|
| 1 | "Hi, I'm calling about..." (identify caller) | `get-client-by-phone` | ✅ Full |
| 2 | "I'm a new customer" | `submit-new-lead` / `create-client` | ✅ Full |
| 3 | "I need to update my email" | `update-client` | ✅ Full |
| 4 | "My phone number changed" | `update-client` | ✅ Full |
| 5 | "I changed my name" | `update-client` | ✅ Full |
| 6 | "What info do you have for me?" | `get-client-by-phone` | ✅ Full |

### Category 2: Property / Service Location Management

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 7 | "I have a new address / I moved" | `update-property` | ✅ Full |
| 8 | "I have a second location that needs service" | `create-property` | ✅ Full |
| 9 | "Which addresses do you have for me?" | `list-properties` | ✅ Full |
| 10 | "The address on file is wrong" | `update-property` | ✅ Full |
| 11 | "Remove my old property" | — | ❌ **GAP**: No `delete-property` endpoint (adapter method exists) |

### Category 3: Service Inquiry

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 12 | "What services do you offer?" | `get-services` | ✅ Full |
| 13 | "Do you do [specific service]?" | `get-services` (LLM matches) | ✅ Full |
| 14 | "How much does [service] cost?" | `get-services` | ⚠️ **Partial**: Only if pricing is configured in Jobber's ProductOrService catalog |
| 15 | "Do you service my area?" | — | ❌ **GAP**: No service area check. Agent must fall back to general response or transfer. |

### Category 4: New Service Request

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 16 | "I need [service] done" | `submit-new-lead` | ✅ Full |
| 17 | "I have a leak / emergency" | `create-service-request` (priority=emergency) | ✅ Full |
| 18 | "Can someone come look at [problem]?" | `submit-new-lead` → `create-assessment` | ✅ Full |
| 19 | "I'd like a quote/estimate" | `submit-new-lead` (creates Request → contractor quotes) | ✅ Full |
| 20 | "My neighbor recommended you" (referral) | `submit-new-lead` | ✅ Full (captured in description) |

### Category 5: Request / Quote Status

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 21 | "What's happening with my request?" | `get-requests` / `get-request` | ✅ Full |
| 22 | "Did you get my request?" | `get-requests` | ✅ Full |
| 23 | "When is my consultation/assessment?" | `get-request` → metadata.assessment | ✅ Full |
| 24 | "Has my quote been sent?" | `get-request` → metadata.quotes | ✅ Full |
| 25 | "What's the quote amount?" | `get-request` → metadata.quotes[0].total | ✅ Full |
| 26 | "I want to approve the quote" | — | ❌ **GAP**: No `quote-approve` endpoint. Must transfer to human or email link. |
| 27 | "The quote is too high / I want to negotiate" | `add-note-to-job` | ⚠️ **Workaround**: Agent notes concern, suggests contractor follow-up |

### Category 6: Scheduling & Availability

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 28 | "When are you available?" | `get-availability` | ✅ Full |
| 29 | "Can you come [specific date]?" | `get-availability` (date range) | ✅ Full |
| 30 | "I need to schedule an appointment" | `get-availability` → `create-visit` | ✅ Full |
| 31 | "What's my next appointment?" | `get-visits` | ✅ Full |
| 32 | "What appointments do I have?" | `get-visits` | ✅ Full |
| 33 | "Schedule an assessment/consultation" | `create-assessment` | ✅ Full |
| 34 | "I'm available mornings only" | `get-availability` (LLM filters AM slots) | ✅ Full |

### Category 7: Reschedule & Cancel

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 35 | "I need to reschedule" | `get-visits` → `reschedule-visit` | ✅ Full |
| 36 | "Can I move my appointment?" | `get-visits` → `get-availability` → `reschedule-visit` | ✅ Full |
| 37 | "I need to cancel my appointment" | `get-visits` → `cancel-visit` | ✅ Full |
| 38 | "Something came up, I can't make it" | `cancel-visit` or `reschedule-visit` | ✅ Full |
| 39 | "Cancel my assessment/consultation" | — | ❌ **GAP**: No `assessment-cancel` endpoint (Jobber has `assessmentDelete` mutation) |

### Category 8: Job / Work Status

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 40 | "What's the status of my job?" | `get-jobs` / `get-job` | ✅ Full |
| 41 | "What's my job number?" | `get-jobs` | ✅ Full |
| 42 | "When will the work be done?" | `get-job` (endAt/completedAt) | ✅ Full |
| 43 | "Who's assigned to my job?" | `get-request` → metadata.jobs[].assignedUsers | ✅ Full |
| 44 | "I have a note about my job / special instructions" | `add-note-to-job` | ✅ Full |
| 45 | "The gate code is [X]" | `add-note-to-job` | ✅ Full |

### Category 9: Billing & Payments

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 46 | "How much do I owe?" | `get-client-balance` | ✅ Full |
| 47 | "What's my balance?" | `get-client-balance` | ✅ Full |
| 48 | "Can I see my invoices?" | `get-invoices` | ✅ Full |
| 49 | "I got an invoice, can you explain it?" | `get-invoices` (LLM reads line items) | ✅ Full |
| 50 | "When is my payment due?" | `get-invoices` (dueDate field) | ✅ Full |
| 51 | "I want to pay my bill" | — | ❌ **GAP**: No payment processing via API. Agent must direct to payment portal or transfer. |
| 52 | "Can I set up a payment plan?" | — | ❌ **GAP**: Not available in Jobber API. Transfer to human. |
| 53 | "I already paid, but it's showing a balance" | — | ⚠️ **Partial**: Agent can read balance + note concern via `add-note-to-job`. Needs human follow-up. |

### Category 10: Complaints & Follow-up

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 54 | "I'm not happy with the work" | `add-note-to-job` + transfer | ⚠️ **Workaround**: Agent documents complaint, transfers to human |
| 55 | "The technician didn't show up" | `add-note-to-job` + transfer | ⚠️ **Workaround**: Same pattern |
| 56 | "My repair broke again" (warranty/callback) | `create-service-request` | ✅ Full (creates new request referencing original) |
| 57 | "I need to speak to a manager" | Transfer call (LiveKit) | ✅ Full (not a Jobber endpoint) |
| 58 | "Is this covered under warranty?" | — | ❌ **GAP**: No warranty info in Jobber API. Transfer to human. |

### Category 11: Estimate / Quote Operations

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 59 | "I'd like an estimate" | `submit-new-lead` → contractor creates quote | ✅ Full |
| 60 | "Can you email me a quote?" | `get-request` (quotes have email delivery) | ⚠️ **Partial**: Jobber sends quotes via email, agent confirms it will be sent |
| 61 | "I want to change my quote / add items" | — | ❌ **GAP**: No `quote-edit` endpoint. Transfer to human. |

### Category 12: General / Meta

| # | Caller Intent | Endpoint(s) Used | Coverage |
|---|---------------|------------------|----------|
| 62 | "What are your hours?" | — | ⚠️ **System prompt**: Configured in business settings, not a Jobber API call |
| 63 | "Where are you located?" | — | ⚠️ **System prompt**: Configured in business settings |
| 64 | "How do I leave a review?" | — | ⚠️ **System prompt**: Can be configured to provide review link |
| 65 | "I need to talk to a real person" | Transfer call (LiveKit) | ✅ Full |

---

## Coverage Summary

| Status | Count | Percentage |
|--------|-------|------------|
| ✅ **Full coverage** | 48 | 73.8% |
| ⚠️ **Partial / workaround** | 9 | 13.8% |
| ❌ **Gap (no endpoint)** | 8 | 12.3% |
| **Total intents** | **65** | 100% |

---

## Gaps Analysis & Recommendations

### Critical Gaps (should address before production)

| Gap | Impact | Recommendation | Effort |
|-----|--------|----------------|--------|
| **Quote approval** (#26) | High — callers can't approve quotes by phone | Add `jobber-approve-quote` endpoint using `quoteApprove` mutation | Low |
| **Assessment cancel** (#39) | Medium — callers can't cancel consultations | Add `jobber-cancel-assessment` endpoint using `assessmentDelete` mutation | Low |

### Nice-to-Have Gaps (address in Phase 2)

| Gap | Impact | Recommendation | Effort |
|-----|--------|----------------|--------|
| **Delete property** (#11) | Low — rare intent | Add `jobber-delete-property` endpoint (adapter method exists) | Trivial |
| **Payment processing** (#51) | Medium — but outside Jobber API scope | Provide Jobber payment link or transfer to human | Config |
| **Quote editing** (#61) | Low — contractor-side operation | Transfer to human | N/A |
| **Service area check** (#15) | Low — can handle in system prompt | Configure service area in system prompt | Config |
| **Payment plans** (#52) | Low — business policy decision | Transfer to human | N/A |
| **Warranty info** (#58) | Low — business-specific | Transfer to human | N/A |

### Workarounds That Are Acceptable

These intents use `add-note-to-job` as a catch-all + transfer to human. This is the correct pattern for a voice agent — document the caller's concern and escalate:

- Pricing negotiations (#27)
- Payment disputes (#53)
- Work quality complaints (#54, #55)

---

## Voice Agent Call Flow Decision Tree

```
Inbound Call
│
├─ get-client-by-phone
│  ├─ FOUND → "Hi [name], how can I help you?"
│  │  ├─ Scheduling → get-visits / get-availability / create-visit / reschedule / cancel
│  │  ├─ Status check → get-requests / get-request / get-jobs
│  │  ├─ Billing → get-client-balance / get-invoices
│  │  ├─ New service → create-service-request / submit-new-lead
│  │  ├─ Update info → update-client / update-property / create-property
│  │  ├─ Complaint → add-note-to-job + transfer
│  │  └─ Transfer → LiveKit warm/cold transfer
│  │
│  └─ NOT FOUND → "I don't see an account. Let me help you get started."
│     ├─ Collect name, email, address, service need
│     └─ submit-new-lead (creates Client + Property + Request)
```

---

## Entity CRUD Coverage Matrix

| Entity | Create | Read | Update | Delete | List |
|--------|--------|------|--------|--------|------|
| **Client** | ✅ | ✅ | ✅ | — | — (by phone) |
| **Property** | ✅ | — | ✅ | ❌ gap | ✅ |
| **Request** | ✅ | ✅ | — | — | ✅ |
| **Assessment** | ✅ | ✅ (via request) | — | ❌ gap | — |
| **Quote** | ✅ | ✅ (via request) | — | — | — |
| **Job** | ✅ (via visit) | ✅ | ✅ (notes) | — | ✅ |
| **Visit** | ✅ | — | ✅ (reschedule) | ✅ (cancel) | ✅ |
| **Invoice** | — (contractor) | — | — | — | ✅ |

### Missing Operations Worth Adding

1. **Assessment delete** — `assessmentDelete` mutation exists in Jobber
2. **Quote approve** — `quoteApprove` mutation exists in Jobber
3. **Property delete** — adapter method exists, just needs server endpoint
