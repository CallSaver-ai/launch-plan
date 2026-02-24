# Jobber Integration — Deferred Tasks

## 1. Auto-Schedule vs Unscheduled Toggle → Prompt Integration

**Status**: Deferred  
**Context**: There is a boolean flag (`autoScheduleAssessment`) on the agent config that controls whether the agent should auto-schedule assessments or leave them unscheduled. Currently, the prompt in `src/server.ts` (the FS instructions injected at agent-config time) respects this toggle, but the base prompt in `src/utils.ts` may still instruct the agent to call `fs_check_availability` and ask the caller for a preferred time.

**What needs to happen**:
- When `autoScheduleAssessment = false` (unscheduled mode):
  - The agent should NOT call `fs_check_availability` or `fs_create_appointment`
  - The agent MAY still ask the caller for a preferred time/day, but should frame it as a preference, not a booking
  - The preferred time should be added as a **note** on the Jobber request (not scheduled)
  - Tell the caller: "I've submitted your request and our team will reach out to schedule a convenient time."
- When `autoScheduleAssessment = true`:
  - The agent calls `fs_check_availability`, presents options, and calls `fs_create_assessment` with the chosen time
  - Current behavior (works correctly when prompt instructs it)

**Jobber field for notes**: `Request.notes: RequestNoteUnionConnection!`

---

## 2. Custom Intake Question Answers → Jobber Request Notes

**Status**: Deferred  
**Context**: When the agent collects answers to custom intake questions (e.g., "What is the square footage of your home?"), those answers are currently saved to the internal DB via `submit_intake_answers`. For Jobber integrations, these answers should also be attached to the Jobber request as notes so the business owner sees them in their Jobber dashboard.

**What needs to happen**:
- After `fs_submit_lead` creates the request, attach custom intake answers as a note on the request
- Use the Jobber `RequestNoteUnionConnection` field
- Options:
  - A) Modify `fs_submit_lead` to accept optional `notes` and attach them during creation
  - B) Create a new tool/endpoint `fs_add_request_note` that the agent calls after lead submission
  - C) Have the API backend automatically attach notes when `submit_intake_answers` is called and a Jobber request exists
- Option C is likely cleanest (transparent to the agent, no extra tool call)

**Format for notes**: Something like:
```
Intake Answers:
- Square footage: 4000
- Type of service needed: AC repair
```

---

## 3. Desired Time as Request Note (Unscheduled Mode)

**Status**: Deferred  
**Context**: When `autoScheduleAssessment = false`, the agent may still collect a preferred time from the caller. This should be added as a note on the Jobber request so the business owner can see the caller's preference when scheduling manually.

**What needs to happen**:
- Create a mechanism to add notes to a Jobber request after creation
- The `fs_submit_lead` response includes the `requestId` — use this to attach the note
- Options:
  - Extend `fs_submit_lead` to accept an optional `preferred_time` field and attach it as a note
  - Create `fs_add_request_note` tool (also useful for task #2 above)

**Jobber GraphQL**: Need to investigate the mutation for adding notes to a request. Likely `requestNoteCreate` or similar.

---

## 5. Service Pricing Toggle & Response Sanitization for `fs_get_services`

**Status**: Deferred  
**Context**: The `fs_get_services` tool currently returns full pricing data from Jobber, including markup and unit cost. Business owners need control over whether the agent can quote prices at all, and even when pricing IS enabled, sensitive cost/markup data must never be exposed to the agent.

**What needs to happen**:

### A) New toggle: `showServicePricing` (boolean, per-agent config)
- Add a toggle to the agent config (similar to `autoScheduleAssessment`) that controls whether the agent receives pricing information from `fs_get_services`
- When `showServicePricing = false`:
  - Strip all pricing fields from the `fs_get_services` response before returning to the agent
  - The agent should say "I don't have pricing information available — the team can provide a quote" (prompt instruction)
- When `showServicePricing = true`:
  - Return sanitized pricing data (see below)

### B) Response sanitization (always, even when pricing is enabled)
- The raw Jobber service response includes sensitive fields that must NEVER reach the agent:
  - **`unitCost`** — the business's internal cost (what they pay)
  - **`markup`** / **`markupPercentage`** — the profit margin
  - Any other internal cost/margin fields
- When pricing is enabled, only return:
  - Service name
  - Service description
  - **Price** (the customer-facing price only)
  - Duration (if available)
- This sanitization should happen at the API layer (`/internal/tools/fs/get-services` route or the adapter) so the agent never sees raw cost data regardless of configuration

### Implementation options:
- A) Sanitize in the `field-service-tools.ts` route handler before returning the response
- B) Sanitize in the `JobberAdapter.getServices()` method itself
- C) Add a response transformer in `call_fs_endpoint` on the Python side
- Option A or B preferred — sanitize server-side before data leaves the API

### Where the toggle lives:
- `agent.config.showServicePricing` (JSON field on Agent model, same pattern as `autoScheduleAssessment`)
- Frontend: Add toggle to the Jobber integration settings section in LocationsPage

---

## 4. Email Collection Removed from Voice Agent

**Status**: Done (Feb 18, 2026)  
**Context**: Email collection over the phone is unreliable — the agent frequently mispronounces email addresses, leading to poor UX. Decision: stop collecting email via voice. Communication will be phone + SMS only.

**Changes made**:
- Removed email instructions from all integration prompt sections in `src/utils.ts`
- Email intake question removed from frontend LocationsPage intake modal
- `submit_intake_answers` still accepts email field (for backward compatibility / manual entry)
