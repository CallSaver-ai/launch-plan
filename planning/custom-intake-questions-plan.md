# Custom Intake Questions — Re-enablement Plan

**Date:** February 26, 2025
**Status:** Planning
**Related:** `~/callsaver-api/livekit-python/tools/submit_intake_answers.py`, `~/callsaver-frontend/src/pages/LocationsPage.tsx`

---

## 1. Current State Audit

### Frontend (`LocationsPage.tsx`) — Code Preserved

The custom intake questions UI was temporarily hidden but **all code is still present**:

| Component | Location | Status |
|---|---|---|
| `IntakeQuestion` interface | Lines 226–234 | ✅ Present — defines `id`, `type` (`name`/`address`/`email`/`custom`), `label`, `promptText`, `required`, `customFieldKey` |
| `Location.intakeQuestions` field | Line 264 | ✅ Present — `IntakeQuestion[] \| null` |
| State variables | Lines 691–703 | ✅ Present — `editingIntakeQuestions`, `intakeModalOpen`, `intakeModalLocationId`, `savingIntakeQuestions`, form fields for add/edit |
| Modal/UI rendering | Hidden/commented out | ⚠️ UI rendering code needs to be re-enabled |

Some state setters are underscore-prefixed (`_newIntakePromptText`, `_newIntakeRequired`, etc.) to suppress lint warnings while preserved.

### Backend (`callsaver-api`) — Schema & Endpoints Present

| Component | Location | Status |
|---|---|---|
| Prisma schema | `prisma/schema.prisma` line 97 — `intakeQuestions Json? @map("intake_questions")` | ✅ Present |
| API contract | `src/contracts/more-user-endpoints.contract.ts` line 844 — `intakeQuestions: z.array(intakeQuestionSchema).optional()` | ✅ Present |
| PATCH handler | `src/server.ts` — `/me/locations/:locationId` endpoint | ✅ Present — accepts `intakeQuestions` in request body |
| Database column | `intake_questions` (JSON) on `locations` table | ✅ Present — no migration needed |

### Python Agent (`submit_intake_answers.py`) — Supports Custom Questions

The `submit_intake_answers` tool already accepts a `custom` parameter:

```python
async def submit_intake_answers(
    ctx: RunContext,
    name: Optional[str] = None,
    address: Optional[str] = None,
    address_id: Optional[str] = None,
    email: Optional[str] = None,
    custom: Optional[Dict[str, str]] = None,   # ← Custom intake question answers
    call_record_id: Optional[str] = None,
) -> str:
```

The `custom` dict maps question labels/keys to answer text: `{"preferred_contact_time": "Mornings"}`.

---

## 2. How `collect-email` Relates to `submit_intake_answers`

### Current Design

`collect-email` and `submit_intake_answers` are **separate tools** by design:

| Tool | Purpose | When Called |
|---|---|---|
| `collect-email` | Collects email via LiveKit's `GetEmailTask` — handles noisy voice-to-text normalization (e.g., "dot" → `.`, "at" → `@`) and confirmation with the caller | When the agent needs the email address |
| `submit_intake_answers` | Persists all intake data (name, address, email, custom answers) to the backend | After data is collected — can be called multiple times, merges with existing data |

### Recommended Flow

1. Agent collects name → calls `submit_intake_answers(name="John Smith")` immediately
2. Agent collects address (via `validate_address` if needed) → calls `submit_intake_answers(address="123 Main St, City, ST 12345")` immediately
3. Agent collects email (via `collect-email` tool) → calls `submit_intake_answers(email="john@example.com")` immediately
4. Agent collects custom intake answers → calls `submit_intake_answers(custom={"question_label": "answer"})` immediately

**Key principle: Submit each piece of data as soon as it's available.** The tool merges with existing data. If the call drops mid-intake, whatever was already submitted is preserved.

### Why Multiple Calls (Not One Batch Call)

- **Resilience:** If the call drops after collecting name + address but before email, the name and address are already saved. A single batch call at the end risks losing everything.
- **Progressive save:** The backend endpoint merges answers, so repeated calls are safe and additive.
- **Tool docstring already says:** "Do NOT wait until the end of the call — call it as soon as you have at least one piece of information."
- **Email is special:** The `collect-email` tool uses LiveKit's `GetEmailTask` which handles the noisy voice transcription problem. The email result then flows into `submit_intake_answers` as a second call.

---

## 3. Which Integrations Use `submit_intake_answers`?

### Tool Assignment by Integration Type

| Integration | `submit_intake_answers` | `collect-email` | How Intake Data Is Stored |
|---|---|---|---|
| **No Integration** | ✅ Yes | ✅ Yes (if toggle on) | `submit_intake_answers` → `/internal/intake-answers` → Caller record |
| **Google Calendar** | ✅ Yes | ✅ Yes (always) | `submit_intake_answers` → Caller record; email also passed to `google-calendar-create-event` as `attendee_email` |
| **Jobber** | ❌ No | ✅ Yes (if toggle on) | `fs-create-customer` (name, email), `fs-create-property` (address), `fs-create-service-request` (intake_answers as JSON) |
| **Housecall Pro** | ❌ No | ✅ Yes (if toggle on) | `fs-create-customer` (name, email), `fs-create-property` (address), `fs-submit-lead` (description includes service details) |

**Why `submit_intake_answers` is excluded from Jobber/HCP:** The field-service tools (`fs-create-customer`, `fs-create-property`, etc.) handle name, address, and customer creation directly in the external platform. Having `submit_intake_answers` alongside them would be redundant and confuse the LLM about which tool to use.

---

## 4. Custom Intake Questions × Integration Matrix

### No Integration / Google Calendar

Custom intake questions work **directly** with `submit_intake_answers`:

1. Admin configures custom questions in Location Settings (e.g., "How did you hear about us?", "What's the best time to reach you?")
2. Questions are injected into the system prompt during `/internal/agent-config`
3. Agent asks each question during the call
4. Agent calls `submit_intake_answers(custom={"How did you hear about us?": "Google search", "Best time to reach you": "Mornings"})`
5. Backend stores answers on the Caller record

**This flow already works.** The `custom` parameter on `submit_intake_answers` was designed for this.

### Jobber

Custom intake questions need to be written to Jobber. **This is partially supported:**

- `fs-create-service-request` already accepts an `intake_answers` parameter:
  ```python
  intake_answers: Optional[str] = None,  # JSON string of intake question answers
  # e.g. '{"Question label": "Answer text"}'
  ```
- The backend parses this and attaches intake answers as a **note** on the service request in Jobber.

**Gap:** The agent needs prompt instructions to:
1. Ask the custom intake questions
2. Collect the answers
3. Pass them as the `intake_answers` JSON string to `fs-create-service-request`

**Action needed:** When custom intake questions are configured, inject them into the system prompt for Jobber locations and instruct the agent to pass answers via the `intake_answers` parameter on `fs-create-service-request`.

### Housecall Pro

HCP is more constrained. There are two paths for new callers:

**Path 1: Service Requests (Leads)**
- `fs-create-service-request` has the same `intake_answers` parameter as Jobber
- The backend can attach answers as a note on the lead/request in HCP

**Path 2: `fs-submit-lead` (Simplified Lead)**
- `fs-submit-lead` currently does **not** have an `intake_answers` parameter
- It creates customer + property + service request in one call
- **Gap:** Custom intake answers would need to be appended to the `service_description` field, or `fs-submit-lead` needs an `intake_answers` parameter added

**Recommendation for HCP custom intake answers:**
1. **Option A (Simple):** Append custom intake answers to the `description` field of the lead/request: `"Leaking roof needs repair\n\nIntake Answers:\n- How did you hear about us?: Google\n- Best time: Mornings"`
2. **Option B (Structured):** Add `intake_answers` parameter to `fs-submit-lead` (same as `fs-create-service-request`) and store as a note on the HCP Pro job/estimate
3. **Recommended: Option A** first (no schema change, works immediately), then migrate to Option B

---

## 5. Re-enablement Plan

### Phase 1: Backend Verification (No Changes Needed)
- [x] Prisma schema has `intakeQuestions` field
- [x] PATCH endpoint accepts `intakeQuestions` in request body
- [x] `submit_intake_answers` tool supports `custom` dict
- [x] `fs-create-service-request` supports `intake_answers` parameter

### Phase 2: System Prompt Integration
- [ ] Verify that configured `intakeQuestions` are injected into the system prompt in `buildDynamicAssistantConfig` / `generateSystemPrompt`
- [ ] For Jobber/HCP: Add prompt instructions to pass intake answers via `intake_answers` parameter on `fs-create-service-request`
- [ ] For No Integration/GCal: Add prompt instructions to pass intake answers via `custom` parameter on `submit_intake_answers`

### Phase 3: Frontend Re-enablement
- [ ] Re-enable the intake questions modal/section in `LocationsPage.tsx`
- [ ] Verify the add/edit/delete/reorder UI works with the existing state variables
- [ ] Test saving custom intake questions via the PATCH endpoint

### Phase 4: HCP `fs-submit-lead` Enhancement
- [ ] Add `intake_answers` parameter to `fs-submit-lead` tool
- [ ] Update the backend HCP lead submission to include intake answers as a note or description addendum

### Phase 5: Testing
- [ ] Test custom intake questions with No Integration scenario
- [ ] Test custom intake questions with Google Calendar
- [ ] Test custom intake questions with Jobber (via `fs-create-service-request.intake_answers`)
- [ ] Test custom intake questions with HCP (via `fs-create-service-request.intake_answers` or description)
- [ ] Verify progressive save behavior (submit after each answer vs batch)
