# Jobber Request Enrichment Plan

**Created**: Feb 18, 2026  
**Status**: Planning (not yet implemented)

## Problem

When `fs_create_service_request` creates a Jobber Request, three things are missing:

1. **Property not linked** — The property was created separately via `fs_create_property` but its ID isn't passed to the request creation, so the Request has no associated Property in Jobber.
2. **Service not attached as line item** — The service name is used as the Request title, but no `lineItems` with `productOrServiceId` are set, so the Request isn't linked to an actual service in Jobber's catalog.
3. **No `requestDetails` form** — Jobber's `RequestCreateInput` supports a `requestDetails` field (structured form) for external apps. We don't populate it with the caller's request summary, desired appointment time, or intake question answers.

## Jobber Schema Reference

```graphql
type RequestCreateInput {
  clientId: EncodedId!
  propertyId: EncodedId              # ← NOT BEING SET
  title: String
  lineItems: [RequestCreateLineItemAttributes!]  # ← NOT BEING SET
  requestDetails: RequestDetailsInput             # ← NOT BEING SET
  assessment: AssessmentCreateInput
  referringClientId: EncodedId
  formIds: [EncodedId!]
}

type RequestCreateLineItemAttributes {
  name: String!
  description: String
  category: ProductsAndServicesCategory
  taxable: Boolean
  saveToProductsAndServices: Boolean!
  unitCost: Float
  unitPrice: Float
  quantity: Float
  productOrServiceId: EncodedId      # ← Links to Jobber service catalog
  sortOrder: Int
}

type RequestDetailsInput {
  form: FormInput!
}

type FormInput {
  sections: [FormSectionInput!]!     # 1+ required
}

type FormSectionInput {
  label: String!
  items: [FormItemInput!]!           # 1+ required
}

type FormItemInput {
  label: String!
  answerText: String
}
```

## Plan — 3 Changes Across 4 Layers

### Change A: Pass `propertyId` through the stack

| Layer | File | Change |
|-------|------|--------|
| 1. Python tool | `livekit-python/tools/fs_service_request.py` | Add `property_id: Optional[str] = None` param. Send as `propertyId` in body. |
| 2. API endpoint | `src/routes/field-service-tools.ts` | Accept `propertyId` from request body, pass to adapter. |
| 3. Unified type | `src/types/field-service.ts` | Add `propertyId?: string` to `CreateServiceRequestInput`. |
| 4. JobberAdapter | `JobberAdapter.ts` | If `data.propertyId` is provided, set `input.propertyId = data.propertyId` directly (skip the address-based property lookup/create block). The existing address-based block (lines 2522-2618) becomes a **fallback** — only runs if `propertyId` is NOT provided. |

### Change B: Pass `serviceId` as a line item

| Layer | File | Change |
|-------|------|--------|
| 1. Python tool | `livekit-python/tools/fs_service_request.py` | Add `service_id: Optional[str] = None` param. Send as `serviceId` in body. |
| 2. API endpoint | `src/routes/field-service-tools.ts` | Accept `serviceId`, pass to adapter. |
| 3. Unified type | `src/types/field-service.ts` | Add `serviceId?: string` to `CreateServiceRequestInput`. |
| 4. JobberAdapter | `JobberAdapter.ts` | If `data.serviceId`, add to mutation input: `lineItems: [{ name: data.serviceType, productOrServiceId: data.serviceId, saveToProductsAndServices: false }]`. Update GraphQL mutation to request `lineItems` in response. |
| 5. get-services endpoint | `src/routes/field-service-tools.ts` | Include service IDs in the formatted response message so the agent can reference them. Currently the message is `"1. Service Name (description) - 30 min - $50"` — needs to become `"1. Service Name [id=Z2lk...] (description) - 30 min - $50"`. |
| 6. Prompt | `src/server.ts` + `src/utils.ts` | Update workflow step 8 to instruct the agent to pass both `property_id` and `service_id` to `fs_create_service_request`. |

### Change C: Populate `requestDetails` form

The `requestDetails` form is built by the **JobberAdapter** from data passed through the stack. No separate "source" or "caller details" section needed — the source is already set elsewhere, and caller details are on the linked Client.

**Sections to include:**

1. **"Request Summary"**
   - `Summary`: LLM-synthesized summary of what the caller is requesting (from conversation context)

2. **"Scheduling Preference"**
   - `Desired Appointment Time`: The caller's preferred time for the appointment. Collected even in UNSCHEDULED mode — won't be auto-scheduled, but the team sees the preference on the Request.

3. **"Intake Answers"** (if any custom intake questions were answered)
   - Each answered intake question becomes a `FormItemInput` with `label` = question text and `answerText` = caller's answer.

| Layer | File | Change |
|-------|------|--------|
| 1. Python tool | `livekit-python/tools/fs_service_request.py` | Add optional params: `summary: Optional[str]`, `desired_time: Optional[str]`, `intake_answers: Optional[dict]` (key=question label, value=answer). Send as `summary`, `desiredTime`, `intakeAnswers` in body. |
| 2. API endpoint | `src/routes/field-service-tools.ts` | Accept `summary`, `desiredTime`, `intakeAnswers` from request body, pass to adapter. |
| 3. Unified type | `src/types/field-service.ts` | Add `summary?: string`, `desiredTime?: string`, `intakeAnswers?: Record<string, string>` to `CreateServiceRequestInput`. |
| 4. JobberAdapter | `JobberAdapter.ts` | Build `requestDetails.form.sections` from the data. See form structure below. |

**Form structure built by adapter:**

```typescript
const sections: any[] = [];

// Section 1: Request Summary (always present if summary provided)
if (data.summary) {
  sections.push({
    label: 'Request Summary',
    items: [{ label: 'Summary', answerText: data.summary }],
  });
}

// Section 2: Scheduling Preference (if desired time provided)
if (data.desiredTime) {
  sections.push({
    label: 'Scheduling Preference',
    items: [{ label: 'Desired Appointment Time', answerText: data.desiredTime }],
  });
}

// Section 3: Intake Answers (if any)
if (data.intakeAnswers && Object.keys(data.intakeAnswers).length > 0) {
  sections.push({
    label: 'Intake Answers',
    items: Object.entries(data.intakeAnswers).map(([label, answer]) => ({
      label,
      answerText: answer,
    })),
  });
}

if (sections.length > 0) {
  input.requestDetails = { form: { sections } };
}
```

### Change D: Inline assessment creation with the request

**Decision**: Always create an unscheduled assessment with every request.

**Rationale**:
- Most field service businesses follow Request → Assessment → Quote → Job. An unscheduled assessment is a "to-do" for the business — zero cost if not needed, they delete it in one click.
- Mirrors Jobber's own online booking behavior (creates request + assessment together).
- `RequestCreateInput.assessment` lets us inline it atomically — no separate tool call needed.
- **Eliminates the need for a separate `fs_create_assessment` tool call** in the new caller workflow. One fewer tool call = faster call, simpler prompt, fewer failure points.
- Per-service assessment toggles are YAGNI for now. Contractor can always delete an unnecessary assessment in Jobber.

**Implementation**:

The `assessment` field is built by the JobberAdapter based on the scheduling mode:

```typescript
// Always attach an assessment to the request
const assessmentInput: any = {};

// Use the description as assessment instructions
if (data.description) {
  assessmentInput.instructions = data.description;
}

// UNSCHEDULED mode: no schedule field — creates unscheduled assessment
// AUTO-SCHEDULE mode (future): add schedule: { startAt, endAt } after checking availability

input.assessment = assessmentInput;
```

| Layer | File | Change |
|-------|------|--------|
| 4. JobberAdapter | `JobberAdapter.ts` | Always set `input.assessment = { instructions: data.description }`. No `schedule` field in unscheduled mode. |

**Future (auto-schedule mode)**: The adapter will accept optional `assessmentStartTime` / `assessmentEndTime` and set `assessment.schedule = { startAt, endAt }`. This requires `fs_check_availability` → caller picks a slot → pass the chosen time. Significantly more complex — deferred.

## Prompt Changes

### UNSCHEDULED mode update
Even in unscheduled mode, the agent should ask for a preferred appointment time and pass it as `desired_time` to `fs_create_service_request`. The difference is:
- **UNSCHEDULED**: Collects preferred time, passes it in `requestDetails` form as "Desired Appointment Time". Does NOT call `fs_check_availability` or `fs_create_appointment`. Assessment is created unscheduled. Team sees the time preference on the Request details.
- **AUTO-SCHEDULE** (future): Collects preferred time, calls `fs_check_availability`, passes chosen slot as `assessment.schedule` to book it.

### Workflow simplification
The new caller workflow step 9 (assessment) is **removed as a separate step**. The assessment is created inline with the request in step 8. This means:
- No `fs_create_assessment` tool call needed for new callers
- No conditional auto-schedule vs unscheduled branching in the prompt for the assessment step
- The only difference between modes is whether `desired_time` gets auto-scheduled (future) or just noted in `requestDetails`

### Workflow step updates (both `server.ts` and `utils.ts`)
Step 8 (create service request) should instruct the agent to pass:
- `customer_id` (from step 5)
- `property_id` (from step 7 — `fs_create_property` response)
- `service_id` (from step 2/3 — `fs_get_services` response, matched to caller's request)
- `description` (caller's service description)
- `summary` (LLM synthesis of the full request from conversation context)
- `desired_time` (caller's preferred appointment time — always ask, even in unscheduled mode)
- `intake_answers` (dict of intake question→answer, if any custom intake questions were answered)

Step 9 becomes: **CONFIRM** — tell the caller the request and assessment have been submitted, team will reach out to schedule.

## Files to Touch (Complete List)

1. `src/types/field-service.ts` — Add `propertyId?`, `serviceId?`, `summary?`, `desiredTime?`, `intakeAnswers?` to `CreateServiceRequestInput`
2. `src/routes/field-service-tools.ts` — Accept new fields in `create-service-request` endpoint; add service IDs to `get-services` response format
3. `src/adapters/field-service/platforms/jobber/JobberAdapter.ts` — Use `propertyId` directly, add `lineItems` with `productOrServiceId`, build `requestDetails` form, always inline `assessment`. Update GraphQL mutation.
4. `livekit-python/tools/fs_service_request.py` — Add `property_id`, `service_id`, `summary`, `desired_time`, `intake_answers` optional params
5. `src/server.ts` + `src/utils.ts` — Update prompt workflow steps (remove separate assessment step, add new params to step 8, always ask for desired time)
