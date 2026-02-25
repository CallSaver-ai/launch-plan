# Master Intent List — Voice Agent for Field Service Businesses

**Last Updated:** Feb 24, 2026  
**Purpose:** Comprehensive catalog of every customer intent that could come up on a phone call to a field service business, ordered by likelihood/priority, with handling strategy for each.

---

## Legend

| Status | Meaning |
|--------|---------|
| **HANDLED** | Agent has tools and prompt instructions to handle this directly |
| **PARTIALLY HANDLED** | Agent can do some of this but not all — may need to defer part of it |
| **DEFERRED** | Agent acknowledges, captures context, offers callback/transfer |
| **NOT APPLICABLE** | Doesn't apply to our architecture or is out of scope for V1 |

---

## Tier 1: Core Intents (Happen on Nearly Every Call)

These are the bread and butter — the reasons 80%+ of callers are calling.

### 1. New Service Request / Booking
- **Likelihood:** Very High
- **Status:** HANDLED
- **How:** Full intake workflow → `fs_create_customer` → `fs_create_property` → `fs_create_service_request` → optional scheduling via `fs_reschedule_assessment`
- **Notes:** Agent matches service to catalog, validates address, checks service area, collects preferred time

### 2. Schedule / Book an Appointment
- **Likelihood:** Very High
- **Status:** HANDLED
- **How:** `fs_check_availability` → `fs_reschedule_assessment` (new) or `fs_reschedule_appointment` (existing job, HCP only)
- **Notes:** Controlled by `autoScheduleAssessment` toggle. When false, agent defers scheduling to the office.

### 3. Reschedule an Appointment / Estimate
- **Likelihood:** High
- **Status:** HANDLED
- **How:** `fs_check_availability` → `fs_reschedule_assessment` or `fs_reschedule_appointment`
- **Notes:** Agent confirms new time before committing. Mid-conversation rescheduling (picked a time then changed mind) is supported — agent re-checks availability.

### 4. Cancel an Appointment / Estimate
- **Likelihood:** High
- **Status:** HANDLED
- **How:** `fs_cancel_assessment` or `fs_cancel_appointment` (HCP only)
- **Notes:** Agent always confirms before cancelling

### 5. Check Schedule / Upcoming Items
- **Likelihood:** High
- **Status:** HANDLED
- **How:** `fs_get_client_schedule` returns all upcoming assessments, visits, jobs
- **Notes:** Returning caller prompt includes this in OTHER ACTIONS menu

### 6. Business Hours / Location / General Info
- **Likelihood:** High
- **Status:** HANDLED
- **How:** Answered from system prompt (business info section)
- **Notes:** Includes hours, address, areas served, services offered

### 7. "What Services Do You Offer?"
- **Likelihood:** High
- **Status:** HANDLED
- **How:** Agent lists services from catalog (injected into prompt) or uses `fs_get_services`
- **Notes:** Service categories scoped by `callsaverCategories` if configured

### 8. Pricing Inquiry
- **Likelihood:** High
- **Status:** HANDLED (conditional)
- **How:** If `includePricing=true`, agent quotes from catalog. If `false`, defers: "Pricing depends on the specifics — our team will go over that with you during the consultation."
- **Notes:** Agent never negotiates price — see Tier 2 for negotiation intent

### 9. Request a Callback
- **Likelihood:** High
- **Status:** HANDLED
- **How:** `request-callback` tool (available on BOTH Path A and Path B)
- **Notes:** Always available as a fallback for any intent the agent can't handle

### 10. Transfer to Live Person
- **Likelihood:** High
- **Status:** HANDLED (Path B only)
- **How:** `transfer-call` tool via SIP REFER (blind transfer)
- **Notes:** No failure detection — if target doesn't answer, call goes to voicemail. Agent offers callback as alternative.

### 11. Service Area Check ("Do You Come to [City]?")
- **Likelihood:** High
- **Status:** HANDLED
- **How:** Prompt-based: agent compares city (and ZIP for HCP) against SERVICE ZONES / AREAS SERVED injected into prompt. Backend guard on `create-property` as safety net.

### 12. Update Contact Information
- **Likelihood:** Medium-High
- **Status:** HANDLED
- **How:** `fs_update_customer` — updates name, email, phone in CRM

---

## Tier 2: Common Secondary Intents (Come Up Regularly)

### 13. Check Request / Lead Status
- **Likelihood:** Medium-High
- **Status:** HANDLED
- **How:** `fs_get_requests` / `fs_get_request`

### 14. Check Job Status
- **Likelihood:** Medium-High
- **Status:** HANDLED (HCP) / DEFERRED (Jobber)
- **How:** HCP: `fs_get_jobs` / `fs_get_job`. Jobber: no job tools → defer to callback/transfer.
- **Notes:** Jobber jobs are accessed through requests, not directly

### 15. Service Not in Catalog (Out of Scope)
- **Likelihood:** Medium
- **Status:** HANDLED
- **How:** Agent declines, lists available services. Does NOT create a request for unlisted services.
- **Notes:** Scoped by `callsaverCategories` if configured

### 16. Outside Service Area
- **Likelihood:** Medium
- **Status:** HANDLED
- **How:** Agent politely declines: "I'm sorry, we don't currently service that area"

### 17. Mid-Conversation Service Change
- **Likelihood:** Medium
- **Status:** PARTIALLY HANDLED
- **How:** Agent can pivot the service type before creating the request. If already created, agent notes the change in callback/description.
- **Notes:** LLM naturally handles "actually, I need X instead of Y" if it happens before the `fs_create_service_request` call. After creation, can't modify — creates callback.

### 18. Multiple Services ("While You're At It")
- **Likelihood:** Medium
- **Status:** PARTIALLY HANDLED
- **How:** Agent creates ONE service request with combined description: "Primary: HVAC tune-up. Also requested: filter replacement." Office handles line items.
- **Notes:** V1 decision: single line item + descriptive notes. Technician/office adds line items on-site. Keeps voice flow simple.

### 19. Warranty / Failed Repair ("The Fix Didn't Hold")
- **Likelihood:** Medium
- **Status:** DEFERRED (with context capture)
- **How:** Agent creates NEW service request referencing previous work. Notes: "Follow-up/warranty — previous work may not have resolved the issue." Offers callback/transfer.
- **Prompt:** In UNHANDLED INTENTS section of fsInstructions

### 20. Estimate / Quote Follow-Up
- **Likelihood:** Medium
- **Status:** PARTIALLY HANDLED
- **How:** Agent looks up via `fs_get_requests`. If estimate info available, relays it. Otherwise defers: "Let me have the office follow up with those details."
- **Prompt:** In UNHANDLED INTENTS section

### 21. Approved Estimate — Wants to Schedule Work
- **Likelihood:** Medium
- **Status:** PARTIALLY HANDLED
- **How:** Agent checks `fs_get_jobs` (HCP). If job exists with appointment → provide details. If unscheduled → capture preferred time, defer. If no job → defer.
- **Prompt:** In UNHANDLED INTENTS section

### 22. Emergency / Urgent Request
- **Likelihood:** Medium
- **Status:** DEFERRED (with urgency capture)
- **How:** Agent captures urgency in service request. Path B: offers immediate transfer. Path A: creates urgent callback request.
- **Prompt:** In UNHANDLED INTENTS section

### 23. Recurring Service Setup
- **Likelihood:** Medium
- **Status:** DEFERRED (with context capture)
- **How:** Agent creates service request noting it's recurring (e.g., "monthly lawn maintenance") with preferred schedule. Office sets up recurring job.
- **Prompt:** In UNHANDLED INTENTS section

### 24. "Can I Talk to the Owner / Manager?"
- **Likelihood:** Medium
- **Status:** HANDLED
- **How:** Path B: offers transfer. Path A: offers callback. Both: captures what it's about.

### 25. Third-Party Booking ("Calling for My Mother")
- **Likelihood:** Medium
- **Status:** PARTIALLY HANDLED
- **How:** Agent can create a customer with a different name/address than the caller. Should ask for the service address and the contact name for the person at the property.
- **Notes:** Agent should note in the request that booking was made by a third party

### 26. Caller Says They're Someone Else (Wrong Caller ID Match)
- **Likelihood:** Medium
- **Status:** HANDLED
- **How:** Prompt instructs: use the new name for this call, don't update existing customer record. May create new customer via `fs_create_customer`.

---

## Tier 3: Less Common but Important Intents

### 27. Billing / Invoice Question
- **Likelihood:** Medium-Low
- **Status:** DEFERRED
- **How:** Agent has no billing tools. "I'll have the office follow up with your billing details."
- **Prompt:** In UNHANDLED INTENTS section

### 28. Payment ("I Want to Pay My Bill")
- **Likelihood:** Medium-Low
- **Status:** DEFERRED
- **How:** Agent cannot process payments. "I'll have someone reach out to help you with payment."
- **Prompt:** In UNHANDLED INTENTS section

### 29. Pricing Negotiation ("Can You Give Me a Discount?")
- **Likelihood:** Medium-Low
- **Status:** DEFERRED
- **How:** Agent cannot negotiate. "I'll have someone from the team follow up to discuss your estimate."
- **Prompt:** In UNHANDLED INTENTS section

### 30. Specific Technician Request
- **Likelihood:** Medium-Low
- **Status:** DEFERRED (with note capture)
- **How:** Agent notes preference in service request or callback. "I'll make sure the team knows your preference."
- **Prompt:** In UNHANDLED INTENTS section

### 31. Trip Charge / Service Fee Clarification
- **Likelihood:** Medium-Low
- **Status:** PARTIALLY HANDLED
- **How:** If trip charges are in the system prompt / business info, agent can answer. Otherwise defers to pricing policy.
- **Notes:** Could be added to business FAQ section of prompt

### 32. Discount Inquiry (Senior / Military / First-Time)
- **Likelihood:** Medium-Low
- **Status:** DEFERRED
- **How:** Agent has no discount authority. "I'll make a note of that — our team can discuss any available discounts when they follow up."

### 33. Symptom Triage ("My AC Is Making a Weird Noise")
- **Likelihood:** Medium-Low
- **Status:** PARTIALLY HANDLED
- **How:** Agent should NOT give professional advice. Should categorize to nearest service and create request with symptom description. "That sounds like it could be [general category]. I'd recommend we have a technician take a look. Let me get you set up for a diagnostic visit."

### 34. "Is This a Robot?"
- **Likelihood:** Medium-Low
- **Status:** HANDLED
- **How:** System prompt includes instruction to handle gracefully: "I'm an AI assistant for [Business]. I can help you schedule service, check on appointments, or connect you with the team."
- **Notes:** Honesty is the best policy — don't pretend to be human

### 35. ETA / "Where's My Technician?"
- **Likelihood:** Medium-Low
- **Status:** DEFERRED
- **How:** Agent has no real-time tech tracking. "I don't have real-time tracking available, but let me have the office check on that and get back to you."

### 36. Access Instructions / Gate Codes
- **Likelihood:** Medium-Low
- **Status:** PARTIALLY HANDLED
- **How:** Agent can capture access notes in the service request description field: "Gate code: 1234, key under mat." Office sees this in the request.
- **Notes:** No dedicated field for this — goes in description/notes

### 37. Documentation Request ("Resend My Invoice / Estimate")
- **Likelihood:** Medium-Low
- **Status:** DEFERRED
- **How:** Agent cannot send documents. "I'll have the office resend that to your email on file."

### 38. Commercial vs. Residential Clarification
- **Likelihood:** Low-Medium
- **Status:** PARTIALLY HANDLED
- **How:** Agent doesn't explicitly ask, but the service catalog and address context usually clarify. If ambiguous, agent should ask and note in request.

---

## Tier 4: Edge Cases & Operational Intents

### 39. Tenant Booking (Landlord Pays)
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** Agent should capture tenant info + ask for landlord name/phone for billing. Note in request: "Tenant booking — landlord authorization needed." Defer to office for billing setup.

### 40. Vendor / Supplier Call
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** "This sounds like it's for our office team. Let me take your name and number and have them call you back." → callback request

### 41. Employment Inquiry
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** "Thanks for your interest! Please send your resume to [email if in prompt]. I'll let the team know you called." → callback request

### 42. Spam / Telemarketer / Wrong Number
- **Likelihood:** Low
- **Status:** HANDLED (implicitly)
- **How:** Agent stays in character. If caller clearly doesn't need a service: "It sounds like you may have the wrong number. Is there something I can help you with regarding [business name]?"

### 43. Behavior / Conduct Complaint About Technician
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** High empathy required. "I'm really sorry to hear about that experience. I'm going to make sure this gets to the right person immediately." → urgent callback request with detailed notes
- **Notes:** Agent must NOT argue, defend, or minimize

### 44. Competitor Price Matching
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** "I appreciate you sharing that. I'll have someone from our team follow up to discuss pricing options."

### 45. Home Warranty / Insurance Dispatch
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** Agent has no warranty network info. "I'll need to check if we handle warranty claims for your provider. Let me have the office follow up with you on that." → callback request

### 46. Insurance Adjuster / Itemized Breakdown
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** "I'll have our office team prepare that documentation and send it over. Can I get the best email to send it to?" → callback request with email noted

### 47. Certificate of Insurance (COI) Request
- **Likelihood:** Low (mostly commercial)
- **Status:** DEFERRED
- **How:** "I'll have our office send over the Certificate of Insurance. What entity name should be listed as additional insured?" → callback request with details

### 48. Permit / Inspection Status
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** Agent has no permit tracking. "Let me have our team check on the permit status and get back to you."

### 49. Parts / Material Status ("Is My Part In Yet?")
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** Agent has no inventory/parts tracking. "I don't have that information right now, but let me have the team check and call you back."

### 50. On-Site Price Dispute ("Your Guy Wants $800, Is That Right?")
- **Likelihood:** Very Low
- **Status:** DEFERRED
- **How:** Agent should NOT override technician pricing. "Our technicians use our standard pricing. If you'd like to discuss this further, I can have a manager follow up with you." → urgent callback

### 51. "Stop Work" Emergency
- **Likelihood:** Very Low
- **Status:** DEFERRED (urgent)
- **How:** Immediate escalation. If Path B: immediate transfer. If Path A: urgent callback request. "I'm going to get someone on this right away."

### 52. Membership / Maintenance Plan Inquiry
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** If membership info is in the system prompt, agent can describe the plan. Signup, cancellation, or benefit disputes → defer to office.

### 53. Financing Inquiry
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** If financing info is in business FAQ/prompt, agent can mention it exists. "We do offer financing options. I'll have someone from our team follow up with the details and help you get started."

### 54. Second Opinion Request
- **Likelihood:** Low
- **Status:** PARTIALLY HANDLED
- **How:** Treat as a high-value new service request. Agent should note: "Caller seeking second opinion — has existing quote from competitor." Creates standard service request.

### 55. Real Estate / Escrow Inspection
- **Likelihood:** Low
- **Status:** PARTIALLY HANDLED
- **How:** Agent creates service request noting time sensitivity. "I'll note this is for a real estate transaction. What's the closing date so we can prioritize accordingly?"

### 56. Customer-Supplied Parts ("I Bought the Part, Just Install It")
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** Agent should note in request. "I'll make a note that you have the part. Our team can confirm the installation details and any warranty considerations."

### 57. Lost Item ("Your Tech Left His Drill Here")
- **Likelihood:** Very Low
- **Status:** DEFERRED
- **How:** "Thank you for letting us know! I'll make sure the team is notified right away." → callback request with urgency

### 58. Multi-Property Booking
- **Likelihood:** Low
- **Status:** PARTIALLY HANDLED
- **How:** Agent can create ONE service request per call (guardrail). For multiple properties: creates request for first, notes others. "For the additional properties, I'll have the office set those up and reach out to confirm times."

### 59. Cancellation with Churn Risk ("I Found Someone Cheaper")
- **Likelihood:** Low
- **Status:** DEFERRED
- **How:** Agent should NOT argue. Capture reason. "I understand. I'll process that cancellation. Is there anything specific we could have done differently?" → callback request noting churn reason for office follow-up

### 60. Language Preference ("Do You Have a Spanish Speaker?")
- **Likelihood:** Low
- **Status:** PARTIALLY HANDLED
- **How:** If multilingual is enabled, agent may switch languages. For technician language preference: note in request. "I'll note that you'd prefer a Spanish-speaking technician."
- **Notes:** System supports multilingual agent if enabled

### 61. GC / Subcontractor Bid Request
- **Likelihood:** Very Low (B2B)
- **Status:** DEFERRED
- **How:** "For bid requests, please email the plans to [email if in prompt]. I'll let our estimating team know to look out for them." → callback request

### 62. Sponsorship / Donation Request
- **Likelihood:** Very Low
- **Status:** DEFERRED
- **How:** "Thanks for thinking of us! We handle those requests through our office. Let me take your info and have someone follow up."

### 63. W-9 / Tax Document Request
- **Likelihood:** Very Low (B2B)
- **Status:** DEFERRED
- **How:** "I'll have our office send that over. What's the best email?" → callback request

### 64. Failed City Inspection
- **Likelihood:** Very Low
- **Status:** DEFERRED (urgent)
- **How:** Immediate escalation. "That's important — I'm going to make sure our team is notified right away and follows up with you." → urgent callback

### 65. Manufacturer Recall
- **Likelihood:** Very Low
- **Status:** DEFERRED
- **How:** "I'd need to check if we're an authorized dealer for that brand. Can I get the model and serial number? I'll have our team look into the recall and call you back."

### 66. Neighbor Complaint (Van Blocking Driveway, Noise)
- **Likelihood:** Very Low
- **Status:** DEFERRED
- **How:** "I'm sorry about that. Let me notify the team right away." → urgent callback

### 67. "Gatekeeper" Screening (Salesperson Asking for Owner)
- **Likelihood:** Low
- **Status:** HANDLED (implicitly)
- **How:** Agent stays professional. "They're not available right now. Is this regarding a current job or service? I'd be happy to take a message."

---

## Already in UNHANDLED INTENTS Deferral Section (fsInstructions)

These are already in the system prompt for both new-caller and returning-caller FS branches:

### Returning Caller Branch (11 items)
1. Billing / invoices
2. Payments
3. Pricing negotiation
4. Job creation / dispatching (don't create Jobs directly)
5. Recurring service setup
6. Estimate follow-up
7. Approved estimate, wants to schedule work
8. Warranty / callback work
9. Emergency / urgent
10. Specific technician preference

### New Caller Branch (7 items)
1. Billing / invoices
2. Payments
3. Pricing negotiation
4. Recurring service setup
5. Emergency / urgent
6. Specific technician preference
7. Catch-all: "Anything else you can't handle — always offer a callback or transfer"

---

## Intents to Add to the Deferral Prompt (Recommended)

These came out of the Gemini analysis and should be added to the UNHANDLED INTENTS section:

### High Priority (Callers will actually say these)
1. **ETA / "Where's my technician?"** — No real-time tracking. Defer.
2. **Parts status ("Is my part in yet?")** — No inventory tracking. Defer.
3. **Documentation request ("Resend my invoice/estimate")** — Can't send docs. Defer.
4. **On-site price dispute** — Don't override tech pricing. Defer to manager.
5. **Conduct/behavior complaint** — High empathy, don't argue. Urgent callback.
6. **"Stop work" emergency** — Immediate transfer or urgent callback.

### Medium Priority (Come up occasionally)
7. **Tenant booking (landlord pays)** — Capture both parties' info, note billing auth needed.
8. **Home warranty / insurance dispatch** — Can't verify network status. Defer.
9. **Financing inquiry** — Mention if in FAQ, otherwise defer.
10. **Customer-supplied parts** — Note in request, defer for warranty discussion.
11. **Cancellation with churn reason** — Capture reason, don't argue. Defer.
12. **Vendor / supplier / employment calls** — Take message, callback.

### Lower Priority (Rare but worth handling gracefully)
13. **COI request** — Take entity name, defer.
14. **Permit / inspection status** — No tracking. Defer.
15. **W-9 / tax docs** — Take email, defer.
16. **Manufacturer recall** — Get model/serial, defer.
17. **GC bid request** — Direct to email, callback.
18. **Sponsorship / donation** — Polite deflection, callback.

---

## Intents NOT Addressable with Current Architecture

These would require new backend capabilities or integrations to handle directly:

| Intent | What's Missing | V2+ Effort |
|--------|---------------|------------|
| Real-time tech ETA tracking | GPS/dispatch integration | High |
| Parts/inventory status | Inventory system integration | High |
| Send documents (invoice, estimate PDF) | Email/SMS sending capability | Medium |
| Process payments | Payment gateway integration | High |
| Membership plan signup/management | Membership CRUD tools | Medium |
| Job creation (dispatch) | Job creation tools + pricing authority | High (V3) |
| Recurring job setup | Recurring job API + schedule builder | Medium |
| Real-time on-site communication | Tech-to-office messaging | High |
| Financing pre-approval link | Wisetack/GreenSky integration | Medium |
| Permit tracking | Permit management system | High |
| Abandoned call follow-up SMS | Post-call automation trigger | Medium |
| Delayed callback scheduling | Scheduled task/reminder system | Low-Medium |

---

## Summary

| Category | Count | Handled | Partial | Deferred | N/A |
|----------|-------|---------|---------|----------|-----|
| Core (Tier 1) | 12 | 11 | 1 | 0 | 0 |
| Secondary (Tier 2) | 14 | 3 | 6 | 5 | 0 |
| Less Common (Tier 3) | 12 | 1 | 3 | 8 | 0 |
| Edge Cases (Tier 4) | 29 | 2 | 5 | 22 | 0 |
| **Total** | **67** | **17** | **15** | **35** | **0** |

**Bottom line:** 17 intents fully handled, 15 partially handled (agent does what it can, defers the rest), 35 deferred to callback/transfer. Zero dead ends — every caller gets routed somewhere.
