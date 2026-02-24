# Jobber Voice Agent: Customer Intents & Tool Design

> How customers interact with a field service business by phone, and how the voice agent handles each intent using Jobber Requests, Jobs, and Visits.

---

## The Jobber Data Model (for context)

```
Client (customer)
  └── Request (lead / work request — pre-sale)
        └── Quote (pricing estimate — sent to client for approval)
              └── Job (approved scope of work — post-sale)
                    └── Visit (scheduled event on the calendar)
                          └── Invoice (billing after completion)
```

**Key insight:** Requests are pre-sale. Jobs are post-sale. The voice agent primarily creates Requests.

---

## Caller Types

### 1. New Caller (not in Jobber)
Phone number not found. Agent must collect info and create a Client + Request.

### 2. Existing Client — No Active Work
Phone found, but no open Requests or Jobs. Likely calling for new work.

### 3. Existing Client — Has Open Request(s)
Phone found, has pending Request(s). Likely calling to check status or add info.

### 4. Existing Client — Has Active Job(s)
Phone found, has Job(s) with scheduled Visits. Likely calling about scheduling.

### 5. Existing Client — Has Overdue Invoice(s)
Phone found, has unpaid invoices. May be calling about billing.

---

## Customer Intents & Agent Responses

### Intent 1: "I need service / I want a quote"
**Caller type:** New or Existing with no active work
**This is the #1 most common call.**

**Agent flow:**
1. `jobber-get-customer-by-phone` → identify caller
2. If not found → collect name, email → `jobber-create-customer`
3. Collect: what service they need, property address, any urgency
4. `jobber-create-property` (if address not on file) or `jobber-update-property`
5. `jobber-create-service-request` → creates Request in Jobber
6. Confirm: "I've submitted a request for [service] at [address]. Our team will review it and get back to you with a quote."

**Tools used:**
- `jobber-get-customer-by-phone`
- `jobber-create-customer`
- `jobber-create-property`
- `jobber-create-service-request`

**What happens next (in Jobber, not the agent):**
- Contractor sees Request in Jobber dashboard
- Contractor creates a Quote and sends to client
- Client approves → Request converts to Job
- Contractor schedules Visit(s) on the Job

---

### Intent 2: "What's the status of my request?"
**Caller type:** Existing with open Request(s)

**Agent flow:**
1. `jobber-get-customer-by-phone` → identify caller
2. `jobber-get-requests` → list their requests
3. Read back status: "You have a request for [service] submitted on [date]. It's currently [awaiting review / quoted / scheduled]."
4. If request has a Quote attached, mention it: "A quote for $X has been sent to your email."

**Tools used:**
- `jobber-get-customer-by-phone`
- `jobber-get-requests`
- `jobber-get-request` (for detailed single request with quotes)

---

### Intent 3: "When is my appointment?" / "When are you coming?"
**Caller type:** Existing with active Job + Visit

**Agent flow:**
1. `jobber-get-customer-by-phone` → identify caller
2. `jobber-get-appointments` → list upcoming visits
3. Read back: "You have a [service] visit scheduled for [day] at [time]."
4. If no visits: check for Jobs → "You have an active job for [service] but no visit scheduled yet. Would you like me to note that you'd like to get scheduled?"

**Tools used:**
- `jobber-get-customer-by-phone`
- `jobber-get-appointments`
- `jobber-get-jobs` (fallback if no visits)
- `jobber-add-note-to-job` (to flag scheduling request)

---

### Intent 4: "I need to reschedule"
**Caller type:** Existing with scheduled Visit

**Agent flow:**
1. `jobber-get-customer-by-phone` → identify caller
2. `jobber-get-appointments` → find the visit
3. Ask when they'd like to reschedule to
4. `jobber-reschedule-appointment` → move the visit
5. Confirm new date/time

**Tools used:**
- `jobber-get-customer-by-phone`
- `jobber-get-appointments`
- `jobber-reschedule-appointment`

**Open question:** Should the agent reschedule directly, or create a note/request for the office to reschedule? Direct reschedule is faster but the contractor may need to check crew availability. For now, direct reschedule — contractor can adjust in Jobber if needed.

---

### Intent 5: "I need to cancel"
**Caller type:** Existing with scheduled Visit or open Request

**Agent flow:**
1. `jobber-get-customer-by-phone` → identify caller
2. `jobber-get-appointments` → find the visit
3. Confirm cancellation: "Are you sure you want to cancel your [service] on [date]?"
4. `jobber-cancel-appointment` → cancel the visit
5. Or if cancelling a Request: note it (Jobber Requests don't have a cancel mutation — the contractor archives them manually)

**Tools used:**
- `jobber-get-customer-by-phone`
- `jobber-get-appointments`
- `jobber-cancel-appointment`
- `jobber-add-note-to-job` (for cancellation reason)

---

### Intent 6: "How much do I owe?" / "What's my balance?"
**Caller type:** Existing with invoices

**Agent flow:**
1. `jobber-get-customer-by-phone` → identify caller
2. `jobber-get-account-balance` → get balance
3. Read back: "Your current balance is $X." or "Your account is paid in full."
4. If they want invoice details: `jobber-get-invoices`

**Tools used:**
- `jobber-get-customer-by-phone`
- `jobber-get-account-balance`
- `jobber-get-invoices`

---

### Intent 7: "I have an emergency" / "My pipe burst" / urgent issue
**Caller type:** Any

**Agent flow:**
1. `jobber-get-customer-by-phone` → identify caller (create if new)
2. Collect: what's the emergency, address
3. `jobber-create-service-request` with priority: "emergency"
4. "I've flagged this as an emergency request. Let me also try to connect you with someone directly."
5. Attempt warm transfer to contractor's phone

**Tools used:**
- `jobber-get-customer-by-phone`
- `jobber-create-customer` (if new)
- `jobber-create-service-request` (priority: emergency)
- `request-callback` or warm transfer

---

### Intent 8: "I want to update my info" / "New phone number" / "New email"
**Caller type:** Existing

**Agent flow:**
1. `jobber-get-customer-by-phone` → identify caller
2. Collect updated info
3. `jobber-update-customer` → update in Jobber

**Tools used:**
- `jobber-get-customer-by-phone`
- `jobber-update-customer`

---

### Intent 9: "What services do you offer?"
**Caller type:** Any

**Agent flow:**
1. `jobber-get-services` → list available services
2. Read back the service catalog
3. If interested: flow into Intent 1 (create request)

**Tools used:**
- `jobber-get-services`

---

### Intent 10: "I want to talk to someone" / "Transfer me"
**Caller type:** Any

**Agent flow:**
1. Attempt warm transfer to contractor
2. If unavailable: `jobber-create-service-request` with note about callback
3. "I wasn't able to reach anyone right now. I've created a request for a callback."

**Tools used:**
- Warm transfer (existing LiveKit tool)
- `jobber-create-service-request` (fallback)

---

## Tool Priority for MVP

### Phase 1: Core lead capture (what we're building now)
These are the tools the agent needs for the most common call — new customer requesting service:

| Tool | Purpose |
|------|---------|
| `jobber-get-customer-by-phone` | Identify caller |
| `jobber-create-customer` | Onboard new caller |
| `jobber-create-property` | Add service address |
| `jobber-create-service-request` | Create the Request (lead) |
| `jobber-get-requests` | Check status of existing requests |
| `jobber-get-request` | Get details of a specific request |

### Phase 2: Active customer management
For returning customers with active work:

| Tool | Purpose |
|------|---------|
| `jobber-get-appointments` | Check upcoming visits |
| `jobber-get-jobs` | Check active jobs |
| `jobber-reschedule-appointment` | Move a visit |
| `jobber-cancel-appointment` | Cancel a visit |
| `jobber-add-note-to-job` | Add context to a job |

### Phase 3: Billing & extras
Lower priority, but valuable:

| Tool | Purpose |
|------|---------|
| `jobber-get-account-balance` | Check what they owe |
| `jobber-get-invoices` | Invoice details |
| `jobber-get-services` | Service catalog |
| `jobber-update-customer` | Update contact info |
| `jobber-update-property` | Update address |
| `jobber-list-properties` | List service addresses |

### Deferred (not needed for voice agent MVP)
| Tool | Purpose | Why deferred |
|------|---------|-------------|
| `jobber-create-appointment` | Schedule a visit | Contractor does this after quoting |
| `jobber-create-estimate` | Create estimate | Contractor does this in Jobber |
| `jobber-get-job-by-number` | Lookup by job # | Edge case |
| `jobber-check-availability` | Check calendar | Requires crew scheduling logic |

---

## System Prompt Guidance

The voice agent system prompt should include:

```
When a customer calls:
1. Always start by looking up their phone number in Jobber.
2. If they're a new customer, collect their first name, last name, and email.
3. Ask what service they need and their property address.
4. Create a service request — do NOT create a job or schedule a visit directly.
5. The contractor's office will follow up with a quote.

For existing customers:
- If they ask about status, check their requests first, then jobs.
- If they ask about scheduling, check their visits.
- If they ask about billing, check their balance.
- Always offer to create a new request if they need additional work.

Important:
- Requests are for NEW work that hasn't been quoted yet.
- Jobs are for APPROVED work that has been quoted and accepted.
- Visits are SCHEDULED events on specific dates/times.
- The voice agent creates Requests. The contractor creates Jobs and Visits.
```

---

## Open Questions for Later

1. **Should the agent ever create Jobs directly?** Maybe for simple, fixed-price services where no quote is needed (e.g., "$50 lawn mow"). The contractor could configure which services skip the quote step.

2. **Should the agent schedule Visits?** Only if the contractor enables it and the service has a fixed duration. Requires availability checking which is complex.

3. **How does the agent handle the Request → Quote → Job flow?** The agent can check if a Request has a Quote attached and tell the customer "a quote has been sent to your email." But the agent can't approve quotes on behalf of the customer.

4. **Multi-property customers?** Some customers have multiple service addresses. The agent should ask "which property is this for?" if the customer has more than one.
