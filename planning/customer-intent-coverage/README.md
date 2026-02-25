# Customer Intent Coverage — Brainstorm

**Date:** Feb 24, 2026  
**Status:** Brainstorm / Early Planning  
**Platforms:** Google Calendar, Jobber, Housecall Pro

## The Problem

Today our voice agent handles two primary flows well:
1. **New caller** → collect info → create customer → create property → create service request
2. **Returning caller** → greet by name → confirm property → create new service request

But real callers have many more intents. A plumber's phone rings and the caller might be:
- A new lead wanting service (handled ✅)
- A returning customer who already has an open request and wants a status update
- Someone who had a technician visit and wants to know about their estimate/quote
- Someone who wants to approve or decline a quote over the phone
- Someone with a scheduled appointment who wants to reschedule or cancel
- Someone calling about a completed job with a follow-up question or warranty issue

We need to systematically identify these intents and ensure the agent can handle them across all three platforms.

---

## Platform Lifecycle Models

### Google Calendar (Simplest)
```
Caller → Calendar Event (appointment)
```
- No concept of estimates, quotes, leads, or jobs
- Just calendar events with optional caller address metadata
- Callback requests are our own model (not in Google Calendar)
- Simplest intent set

### Jobber
```
Caller → Request → Assessment (site visit) → Quote → [Customer Approves] → Job → Visit(s)
```
- **Request**: The initial service request (what we create today)
- **Assessment**: Pre-sale site visit/consultation linked to a Request
- **Quote**: Price estimate generated after assessment (by technician, not voice agent)
- **Job**: Approved work order (created when customer approves quote)
- **Visit**: Scheduled work appointments within a Job

### Housecall Pro
```
Caller → Lead → Estimate → [Customer Approves] → Job → Appointment(s)
```
- **Lead**: The initial service request (what we create today via `fs_create_service_request`)
- **Estimate**: Price estimate (created by technician after site visit or remotely)
- **Job**: Active work order (created when estimate is approved or lead is converted)
- **Appointment**: Scheduled work slots within a Job

---

## Customer Intent Matrix

### Intent Group 1: New Service Requests (Currently Handled ✅)

| Intent | GCal | Jobber | HCP |
|--------|------|--------|-----|
| "I need a plumber" (new caller) | Create event | Create customer → property → request | Create customer → property → lead |
| "I need service at a different address" (returning) | Create event | Confirm/create property → request | Confirm/create property → lead |

**Status:** Fully implemented across all platforms.

### Intent Group 2: Existing Request / Lead Status

| Intent | GCal | Jobber | HCP |
|--------|------|--------|-----|
| "I called last week about a leak, any update?" | Check calendar events | `fs_get_requests` → show status | `fs_get_requests` → show lead status |
| "Has anyone been assigned to my job?" | N/A | `fs_get_request` → check assigned users | `fs_get_request` → check assignment |
| "When is someone coming out?" | Check calendar | `fs_get_client_schedule` | `fs_get_client_schedule` |

**Current state:** Partially handled. The returning caller workflow shows pre-loaded customer info and the agent has `fs_get_requests` / `fs_get_client_schedule` tools. But the system prompt doesn't explicitly instruct the agent on HOW to use these for status inquiries — it's mostly focused on the "create new request" flow.

**Gap:** The agent needs clearer instructions like: "If a returning caller asks about an existing request rather than wanting new service, use `fs_get_requests` to look up their open requests and provide status."

### Intent Group 3: Estimates / Quotes

This is the most complex area and the one we haven't addressed.

#### The Technician Workflow (How Estimates Get Created)

**Jobber:**
1. Voice agent creates Request + Assessment (site visit)
2. Technician goes to customer's home, evaluates the work
3. Technician creates a Quote in Jobber (on-site via mobile app, or back at office)
4. Jobber sends Quote to customer via email/SMS (configurable by business)
5. Customer reviews and approves/declines (via Jobber customer portal, or by calling back)
6. If approved → Jobber creates a Job → technician schedules Visits

**HCP:**
1. Voice agent creates Lead + Estimate visit
2. Technician goes to customer's home, evaluates the work
3. Technician creates an Estimate in HCP (on-site or back at office)
4. HCP sends Estimate to customer via email/SMS
5. Customer reviews and approves/declines (via HCP customer portal, or by calling back)
6. If approved → HCP converts to Job → technician schedules Appointments

**Key insight:** The voice agent NEVER creates estimates/quotes. The technician does. But callers WILL call back asking about them.

#### Caller Intents Around Estimates/Quotes

| Intent | GCal | Jobber | HCP |
|--------|------|--------|-----|
| "I got an estimate, how much was it?" | N/A | `fs_get_request` → quote details | `fs_get_estimates` → estimate details |
| "I want to approve the estimate" | N/A | Need: approve quote API | `fs_accept_estimate` (API exists) |
| "I want to decline the estimate" | N/A | Need: decline quote API | `fs_decline_estimate` (API exists) |
| "Can I get a breakdown of the estimate?" | N/A | Quote line items | Estimate line items |
| "The estimate seems high, can you adjust?" | N/A | Escalate to human | Escalate to human |
| "I haven't received my estimate yet" | N/A | Check request status | Check lead/estimate status |

**Current state:**
- Jobber: We have `fs_get_request` which returns quote data in metadata, but no approve/decline tools
- HCP: We have `fs_get_estimates` and `fs_accept_estimate` / `fs_decline_estimate` Python handlers (currently "dead" — not in the tool list but implemented)
- The HCP estimate tools are among the 6 "dead handlers" we identified — they're ready to activate!

**Action items:**
- Activate `fs-get-estimates` in the HCP tool list
- Evaluate whether to activate `fs-accept-estimate` / `fs-decline-estimate` (business owners may want to control this)
- For Jobber: investigate if the Jobber API supports quote approval via API (may need to check)
- Add prompt instructions for handling estimate inquiries

### Intent Group 4: Appointment / Visit Management

| Intent | GCal | Jobber | HCP |
|--------|------|--------|-----|
| "When is my next appointment?" | `google-calendar-list-events` | `fs_get_client_schedule` | `fs_get_client_schedule` / `fs_get_appointments` |
| "I need to reschedule" | `google-calendar-update-event` | `fs_reschedule_assessment` or `fs_reschedule_appointment` | `fs_reschedule_appointment` |
| "I need to cancel" | `google-calendar-cancel-event` | `fs_cancel_assessment` or `fs_cancel_appointment` | `fs_cancel_appointment` |
| "Can you move it to next week?" | Update event | Reschedule tool | Reschedule tool |
| "I'm running late, will the tech wait?" | Escalate to human | Escalate to human | Escalate to human |

**Current state:** Tools exist for all of these. The returning caller workflow mentions these in "OTHER RETURNING CALLER ACTIONS" section. Reasonably well covered.

**Gap:** The agent needs to distinguish between:
- Jobber: Assessment (pre-sale) vs Visit (actual work) — different tools for each
- HCP: Estimate visit vs Job appointment — different tools

### Intent Group 5: Completed Work Follow-up

| Intent | GCal | Jobber | HCP |
|--------|------|--------|-----|
| "The plumber was here yesterday, I have a question" | N/A | `fs_get_jobs` → completed jobs | `fs_get_jobs` → completed jobs |
| "The repair didn't hold, I need someone back" | Create new event | Create new request (reference old job) | Create new lead (reference old job) |
| "I need my invoice" | N/A | `fs_get_invoices` | Need: invoice lookup |
| "I want to pay my bill" | N/A | `fs_get_account_balance` | Need: balance lookup |
| "Is the work guaranteed/warranty?" | Check FAQ/policies | Check FAQ/policies | Check FAQ/policies |

**Current state:**
- `fs_get_jobs` is active for HCP, not for Jobber (Jobber doesn't have a jobs list tool in the tool list — but jobs in Jobber are accessed via requests)
- `fs_get_invoices` and `fs_get_account_balance` are dead handlers — ready to activate
- Warranty/guarantee questions fall back to business profile FAQ (already in prompt)

**Key question:** Should the voice agent handle billing/payment inquiries? Or is this an escalation to human? Most businesses probably want a human handling payment issues.

### Intent Group 6: Callback Requests

| Intent | GCal | Jobber | HCP |
|--------|------|--------|-----|
| "I'd like someone to call me back" | `request-callback` | `request-callback` | `request-callback` |
| "I left a message earlier, has anyone called back?" | N/A (our model) | N/A (our model) | N/A (our model) |
| "Can the owner/manager call me?" | `request-callback` with note | `request-callback` with note | `request-callback` with note |

**Current state:** Handled via our own `request-callback` tool (Path A) or `transfer-call` (Path B). This is platform-agnostic and works today.

### Intent Group 7: General Inquiries

| Intent | GCal | Jobber | HCP |
|--------|------|--------|-----|
| "What services do you offer?" | From prompt (location.services) | `fs_get_services` | `fs_get_services` |
| "How much does X cost?" | From prompt / escalate | `fs_get_services` (has prices) | `fs_get_services` (has prices) |
| "Do you service my area?" | From prompt (location.serviceAreas) | From prompt (location.serviceAreas) | From prompt (service zones) |
| "What are your hours?" | From prompt | From prompt | From prompt |
| "Are you licensed/insured?" | From prompt (FAQ/policies) | From prompt | From prompt |

**Current state:** Well covered. Services, hours, areas, and FAQ are all in the system prompt.

---

## Priority Ranking

### P0 — Must Have Before Launch
1. ✅ New service request flow (done)
2. ✅ Returning caller with existing properties (done)
3. ✅ Service area validation (done — prompt + backend guard)
4. ✅ Appointment reschedule/cancel (tools exist, instructions in prompt)

### P1 — Should Have for Production Quality
5. **Better returning caller routing** — When a returning caller says "I'm calling about my request from last week," the agent should proactively look up their open requests/leads/schedule rather than assuming they want new service
6. **Estimate/quote status** — Callers WILL call asking "did you send me an estimate yet?" The agent needs to answer this
7. **Activate HCP estimate tools** — `fs-get-estimates` is a dead handler ready to go

### P2 — Nice to Have
8. **Estimate approval over phone** — Let callers approve/decline estimates verbally. Powerful but needs business owner opt-in (some owners want to control this)
9. **Invoice/billing lookup** — `fs-get-invoices` and `fs-get-account-balance` are dead handlers ready to activate
10. **Completed work context** — Reference past jobs when a caller says "the work didn't hold" to create a better-informed new request

### P3 — Future
11. **Payment collection** — Actually collecting payment over the phone (Stripe integration with Jobber/HCP)
12. **Multi-technician routing** — "I want to speak to the tech who came out" → warm transfer to assigned technician
13. **Review solicitation** — After completed work, proactively ask for a Google review (ties into GBP integration plan)

---

## Architectural Approach

### Option A: Intent Detection Layer (Recommended)

Add an explicit intent detection step at the start of returning caller conversations:

```
Returning caller detected (has customer_id + properties)
→ Agent greets by name
→ Agent asks: "How can I help you today?"
→ Based on response, route to appropriate sub-flow:
   - "I need service" → New request flow
   - "Checking on my request/estimate" → Status lookup flow
   - "Need to reschedule" → Schedule management flow
   - "Got a question about..." → General inquiry flow
```

This doesn't require code changes — it's purely prompt engineering. The tools already exist. We just need the system prompt to explicitly describe these sub-flows for returning callers.

### Option B: Proactive Context Loading

Before the agent speaks, pre-load the caller's full context:
- Open requests/leads
- Pending estimates/quotes
- Upcoming appointments/visits
- Recent completed jobs

Inject this as a "CALLER CONTEXT" section in the system prompt. The agent then naturally references it: "I see you have an open request for a kitchen faucet repair from last Tuesday. Is that what you're calling about?"

**Trade-off:** More API calls at session start = higher latency + cost. Could be mitigated by only loading for returning callers and doing it in parallel with other setup.

### Option C: Hybrid (Recommended Long-Term)

Combine A + B:
1. For returning callers, pre-load a lightweight summary (open request count, next appointment date, pending estimate flag)
2. Inject summary into prompt
3. Agent uses summary to ask smart questions
4. Agent calls detailed tools only when needed (e.g., `fs_get_request` for full details)

This balances latency vs. intelligence.

---

## Open Questions

1. **Estimate approval policy**: Should the voice agent be able to approve estimates by default, or should this be a per-business opt-in setting? Some businesses may want customers to approve via the portal only.

2. **Billing/payment scope**: How far should the voice agent go with billing inquiries? Just lookup, or actual payment processing? This has PCI compliance implications.

3. **Completed work warranty**: Should the agent create a new request when a caller reports a failed repair, or flag it as warranty/callback work? Different businesses handle this differently.

4. **Context loading latency**: Pre-loading full caller context adds API calls. Is the latency acceptable? Should we cache recent caller data?

5. **Tool activation strategy**: Should we activate the "dead" tools (estimates, invoices, balance) all at once, or incrementally per platform as we test?

6. **Cross-platform parity**: Jobber and HCP have rich lifecycle models. Google Calendar doesn't. How do we handle callers on GCal-only businesses who ask about estimates or invoices? (Answer: probably just escalate to human / callback.)

---

## Next Steps

1. Audit the current returning caller prompt instructions — identify gaps in intent routing
2. Decide on Option A vs B vs C for returning caller context
3. Activate P1 tools (estimate lookup) and add prompt instructions
4. Test with real calls to identify which intents callers actually have most frequently
5. Iterate prompt instructions based on call transcripts
