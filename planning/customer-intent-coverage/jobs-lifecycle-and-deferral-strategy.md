# Jobs / Visits / Quotes Lifecycle — Build vs. Defer Strategy

**Date:** Feb 24, 2026  
**Status:** Brainstorm / Decision Framework

## Where We Are Today

### Jobber
```
Voice Agent Creates:
  Request → Assessment (scheduled or unscheduled, based on agent.config.autoScheduleAssessment)

Voice Agent Does NOT Touch:
  Quote → Job → Visit(s)
```

### Housecall Pro
```
Voice Agent Creates:
  Lead → Estimate visit (scheduled or unscheduled, equivalent to Jobber's Assessment)

Voice Agent Does NOT Touch:
  Estimate (the pricing doc) → Job → Appointment(s)
```

Both platforms follow the same pattern: **we handle intake, the business handles fulfillment.**

---

## The Core Question: Should the Voice Agent Create Jobs?

### What Creating a Job Means

Creating a Job is fundamentally different from creating a Request/Lead:

| | Request / Lead | Job |
|---|---|---|
| **Business commitment** | None — "we'll look into it" | Yes — "we'll do this work for $X" |
| **Pricing** | Not required | Line items with amounts required |
| **Scheduling** | Optional assessment/estimate visit | Actual work visits/appointments |
| **Authority needed** | Receptionist-level | Dispatcher/manager-level |
| **Reversal cost** | Low — just cancel the request | High — customer expects the work |

**A receptionist doesn't create jobs. A dispatcher does.**

Our voice agent is positioned as a 24/7 AI receptionist. Expanding into dispatcher territory adds:
- Pricing authority decisions (what if the price has changed?)
- Scheduling complexity (which technician? how long? equipment needed?)
- Business liability (committing to work the business can't deliver)

### Recommendation: Don't Create Jobs from the Voice Agent (V1)

Stay in the receptionist lane. The voice agent should:
1. **Intake** — Create requests/leads (done ✅)
2. **Inform** — Look up existing jobs, appointments, estimates (partially done)
3. **Route** — Recognize when a caller needs dispatcher-level help and defer gracefully

---

## The Real Scenarios That Will Come Up

### Scenario 1: Recurring Service Customer

> "Hi, I need my regular yard cleanup" / "Can you send someone for my monthly HVAC maintenance?"

**Why this is tricky:** This customer has had the service before. They have an established price. Creating a new Request + Assessment is wasteful — nobody needs to come evaluate a job they've already done 10 times.

**What the business owner actually wants:** A new Job + Visit at the existing price, scheduled for the next available slot.

**What the voice agent should do (V1):**

```
Agent: "Welcome back, [name]! I see you've had yard cleanup service with us before. 
        I'll put in a request for your regular service and have the office confirm 
        the scheduling and pricing. They'll reach out to you shortly. 
        Do you have a preferred day or time?"

→ Create service request with context:
  - description: "Returning customer requesting regular yard cleanup (recurring service)"
  - summary: "Returning customer, has had this service before. Wants regular yard cleanup. Preferred time: Tuesday morning."
  - desired_time: "Tuesday morning"
```

The office sees the context, recognizes it's a repeat customer, and can convert the request to a Job with one click (Jobber) or convert the lead (HCP) — using the existing pricing from past jobs.

**Why this works:** The agent captures the intent and context perfectly. The 30-second conversion from Request → Job is trivial for the office. The caller gets a good experience ("they know me, they're scheduling me in"). No pricing authority needed.

**V2 Enhancement (Future):** If we can detect that the customer has a past Job for the same service type, we could pre-populate the request with the past pricing and let the agent say "Your last cleanup was $150 — shall I book at the same rate?" But this requires:
- Looking up past jobs by service type
- Business owner opt-in for repeat pricing
- A way to create Jobs via API (more complex)

### Scenario 2: Estimate Approved, Wants to Schedule Work

> "I approved the estimate you sent me. When can you start?"

**What happened:** Technician visited → created Estimate/Quote → sent to customer → customer approved (via portal or email).

**Platform behavior on approval:**
- **Jobber:** When customer approves Quote, Jobber can auto-create a Job (configurable by business)
- **HCP:** When customer approves Estimate, HCP can auto-convert to Job (configurable)

**What the voice agent should do (V1):**

```
Agent: "Great, thank you for approving the estimate! Let me check on that for you."
→ Look up customer's jobs/estimates
→ If Job exists: "I can see the job has been created. Let me check available times for the work."
  → Use fs_get_client_schedule to see if anything is already scheduled
  → If nothing scheduled: "The job is confirmed but hasn't been scheduled yet. 
     Would you like me to have the office reach out to schedule? 
     Do you have a preferred day?"
  → Create callback request or add note to job
→ If no Job yet: "I can see your estimate was approved. The office will be creating 
   the work order shortly. Would you like me to have them call you to confirm scheduling?"
```

**Why we don't need to create the Job:** The platform typically auto-creates it on approval. If it hasn't been created yet, that's an office task (assigning technicians, confirming materials, etc.).

### Scenario 3: Follow-up on Estimate / Quote

> "The plumber came out last week. Have you sent me an estimate yet?"

**What the voice agent should do (V1):**

```
Agent: "Let me check on that for you."
→ fs_get_requests (Jobber) or fs_get_requests (HCP) to find the request
→ Check if quote/estimate is attached
→ If yes: "Yes, I can see an estimate was sent on [date] for $[amount]. 
   Have you had a chance to review it?"
→ If no: "It looks like the estimate hasn't been finalized yet. 
   Would you like me to have the office follow up with you on that?"
```

**Tools needed:**
- Jobber: `fs_get_request` (already returns quote data in metadata)
- HCP: `fs_get_estimates` (dead handler, ready to activate)

### Scenario 4: Existing Customer, New But Different Service

> "You did my plumbing last month, now I need electrical work"

**This is just a new service request.** The customer is returning but the service is different. Normal intake flow applies — create a new Request for the new service type.

The only nuance: the agent should recognize the returning customer and skip redundant questions ("I already have your address as 123 Main St. Is that where you need the electrical work?").

**Current state:** Already handled by returning caller flow. ✅

### Scenario 5: Completed Job, Issue / Warranty

> "Your tech fixed my faucet last week but it's leaking again"

**What the voice agent should do (V1):**

```
Agent: "I'm sorry to hear that. Let me look into your recent service."
→ fs_get_jobs / fs_get_client_schedule to find the completed job
→ "I can see we completed a faucet repair on [date]. I'll flag this as a 
   follow-up for the same issue and have the office prioritize getting 
   someone back out to you. Do you have a preferred time?"
→ Create service request with context:
  - description: "Follow-up: faucet repair from [date] — issue has recurred. 
    Customer reports leak has returned. May be warranty/callback work."
  - summary: "Returning customer, previous faucet repair on [date] didn't hold. 
    Requesting follow-up visit. Possible warranty work."
```

**Why this is a Request, not a Job:** The business needs to decide if this is warranty (free), a new service call, or a redo. That's a business decision, not a receptionist decision.

---

## The Deferral Strategy (V1)

For any intent the voice agent can't fully resolve, the deferral should feel natural and competent — not like hitting a dead end.

### Deferral Tier 1: Informed Handoff (Best UX)

Agent looks up context, acknowledges the situation, captures the caller's needs, and creates a service request or callback with full context.

```
"I can see your account and the recent work we did. I'll put in a priority 
request for [specific thing] and have the office reach out to confirm 
details and scheduling. They should be in touch [today/by tomorrow]. 
Is there anything else I can help with?"
```

**When to use:** Recurring service, warranty follow-up, estimate status, scheduling existing work.

### Deferral Tier 2: Warm Acknowledgment (Good UX)

Agent can't look up full context but acknowledges the type of request and captures info.

```
"That sounds like something our office team will need to handle directly. 
Let me take down your information and have them follow up with you. 
Can you give me a brief description of what you need?"
```

**When to use:** Complex scheduling, pricing negotiations, multi-job coordination.

### Deferral Tier 3: Transfer / Callback (Acceptable UX)

For time-sensitive or complex issues.

```
"Let me connect you with our office team who can help with that right away."
→ transfer-call (Path B) or request-callback (Path A)
```

**When to use:** Angry caller about failed work, billing disputes, urgent scheduling changes.

### Implementation

This is mostly **prompt engineering**. The tools already exist. We need the system prompt to:

1. Detect the intent category (new service, status check, estimate inquiry, repeat service, warranty issue)
2. Route to the appropriate deferral tier
3. Always capture context into the service request / callback

**Prompt addition for returning callers:**
```
RETURNING CALLER INTENT ROUTING:
When a returning caller explains what they need, determine the type of request:

- "I need [same service again]" / "regular cleanup" / "monthly maintenance"
  → This is a REPEAT SERVICE request. Create a service request noting it's recurring 
    and include their preferred timing. The office will convert to a Job at the 
    existing rate.

- "What's happening with my estimate?" / "Did you send the quote?"
  → Look up their open requests/estimates. Provide status. If they want to 
    approve, confirm, and note it in the request.

- "The repair didn't work" / "same problem came back"
  → This is a WARRANTY/CALLBACK request. Look up the recent completed job, 
    create a new service request referencing it, and flag as follow-up/warranty.

- "I approved the estimate, when can you start?"
  → Check if a Job exists. If scheduled, provide details. If not scheduled, 
    note their preferred time and have the office follow up.

- Anything involving pricing changes, billing, payment, or complex scheduling
  → Capture the details and create a callback request for the office to handle.
```

---

## What Would It Take to Actually Create Jobs? (V2 / V3)

If we eventually want the voice agent to create Jobs directly:

### Jobber
- **API capability:** `createJob` mutation exists in Jobber GraphQL
- **Required fields:** Client ID, Property ID, line items (service + price), scheduled visit times
- **Complexity:**
  - Need to look up or determine pricing (from past jobs? from service catalog?)
  - Need to assign team members (or leave unassigned)
  - Need to schedule visits (check availability, pick slots)
  - Need to handle multi-visit jobs
- **Adapter work:** New `createJob()` method, new `createVisit()` method
- **Python tools:** `fs-create-job`, `fs-create-visit`
- **Prompt work:** New workflow section for job creation
- **Risk:** Creating a job commits the business to work at a price. If the AI gets the price wrong, it's a real problem.

### HCP
- **API capability:** `POST /jobs` exists in HCP REST API, also `POST /leads/{id}/convert` to convert Lead → Job
- **Required fields:** Customer ID, address, line items (service + price), schedule
- **Complexity:** Similar to Jobber — pricing authority, technician assignment, scheduling
- **Adapter work:** New `createJob()` method, `convertLead()` method
- **Python tools:** `fs-create-job`, `fs-convert-lead`
- **Prompt work:** Same as Jobber

### Effort Estimate for Job Creation (V2)

| Component | Jobber | HCP |
|---|---|---|
| Adapter methods | 2-3 new methods | 2-3 new methods |
| Backend routes | 2-3 new endpoints | 2-3 new endpoints |
| Python tools | 2-3 new handlers | 2-3 new handlers |
| Prompt engineering | Significant rework | Significant rework |
| Testing | Extensive (pricing edge cases) | Extensive |
| **Total** | **15-20 hours** | **15-20 hours** |

### When Would Job Creation Make Sense?

Only when ALL of these are true:
1. Business has standard/fixed pricing for services (not custom quotes)
2. Business opts in to AI-created jobs
3. The service is one they've done for this customer before (repeat service)
4. Pricing can be pulled from the service catalog or past job history

**The safest path:** "Repeat service at the same price" — look up the customer's past job for the same service type, use the same line items and pricing, create a new Job. This is low-risk because the price is established.

---

## Recommended Phasing

### V1 (Launch — Now)

**Mantra: "Smart receptionist, not a dispatcher."**

- Voice agent creates Requests/Leads + optional Assessment/Estimate visits
- For returning callers: use existing lookup tools to provide context and status
- For intents beyond intake: informed deferral (capture context → service request or callback)
- Add returning caller intent routing to the system prompt
- Activate `fs-get-estimates` for HCP (read-only, low risk)

**No new backend/adapter/Python work needed.** Just prompt engineering + activating one dead handler.

### V2 (Post-Launch, Based on Call Data)

**Mantra: "Informed receptionist who can answer questions."**

- Activate estimate/quote lookup and approval tools
- Pre-load lightweight caller context at session start (open requests, pending estimates, next appointment)
- Add estimate approval over phone (business opt-in flag on agent.config)
- Better repeat-service detection (look up past jobs by service type)

**Effort: ~10-15 hours** across adapter methods, Python tools, and prompt work.

### V3 (When Validated by Market Demand)

**Mantra: "Dispatcher for simple, pre-priced work."**

- Create Jobs directly for repeat services at established pricing
- Business opt-in required
- Limited to services with fixed catalog pricing or repeat-customer pricing
- Full scheduling: create Visits/Appointments with technician availability check

**Effort: ~30-40 hours** across both platforms. Only build if customers are actively requesting it.

---

## Summary

**For V1 launch:** Don't build Job creation. The voice agent creates service requests with rich context, and the office converts to Jobs in seconds. The 80% of callers are new customers or returning customers wanting new service — our current flow handles them. The 20% edge cases (recurring service, estimate follow-up, warranty) are handled gracefully via informed deferral.

**The key insight:** Every scenario where the voice agent "can't" create a Job, it CAN create a perfectly-contextualized service request that tells the office exactly what to do. The office converts Request → Job in one click. The caller experience is nearly identical:

> "I've scheduled a service request for your regular yard cleanup and noted your preference for Tuesday morning. The office will confirm the details and reach out shortly."

vs.

> "I've booked your yard cleanup for Tuesday at 10 AM. That'll be $150, same as last time."

The second is marginally better, but the first is perfectly acceptable for V1 and requires zero additional engineering.
