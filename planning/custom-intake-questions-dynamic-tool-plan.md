# Custom Intake Questions — Dynamic Tool Schema Plan

## Problem

The `submit_intake_answers` tool currently accepts a `custom: Optional[Dict[str, str]]` parameter, allowing the LLM to pass **any** key-value pairs. This leads to ad-hoc keys like `sample_request`, `cabinet_color_preference` appearing in `customIntakeAnswers` that were never configured by the business owner.

Additionally, the frontend UI for managing custom intake questions is **commented out** in the `tabs-toggle` layout, so business owners cannot configure custom questions at all.

## Root Cause

1. **No structural constraint**: The `custom` dict is untyped — the LLM invents keys based on conversation context
2. **No backend validation**: `/internal/intake-answers` merges whatever keys arrive without checking them against configured `customFieldKey` values
3. **UI hidden**: Two comment blocks in `LocationsPage.tsx` disable the Intake tab and section panel

## Solution: Dynamic `raw_schema` Tool Creation

LiveKit Agents supports `function_tool(handler, raw_schema=schema)` which lets us build a tool's JSON schema dynamically at runtime. Instead of a generic `custom` dict, we generate **named parameters** for each configured custom question at agent startup.

### Before (current)

```python
@function_tool()
async def submit_intake_answers(
    ctx: RunContext,
    name: Optional[str] = None,
    address: Optional[str] = None,
    address_id: Optional[str] = None,
    email: Optional[str] = None,
    preferred_time: Optional[str] = None,
    custom: Optional[Dict[str, str]] = None,  # ← LLM can pass anything
) -> str:
```

### After (dynamic schema)

If a location has custom questions with keys `best_time_to_call_back` and `cabinet_color`, the tool schema becomes:

```python
schema = {
    "type": "function",
    "name": "submit_intake_answers",
    "description": "Save caller information collected during the call...",
    "parameters": {
        "type": "object",
        "properties": {
            "name": {"type": "string", "description": "Caller's full name"},
            "address": {"type": "string", "description": "New service address"},
            "address_id": {"type": "string", "description": "ID of existing address"},
            "email": {"type": "string", "description": "Caller's email"},
            "preferred_time": {"type": "string", "description": "Preferred appointment time"},
            # ↓ Dynamically added from configured custom questions ↓
            "best_time_to_call_back": {
                "type": "string",
                "description": "Best time to call back?"
            },
            "cabinet_color": {
                "type": "string",
                "description": "What color cabinets does the caller want?"
            },
        }
    }
}
tool = function_tool(handler, raw_schema=schema)
```

The LLM **structurally cannot** submit keys that aren't in the schema.

If a location has **no custom questions**, the tool is generated with only the base parameters (name, address, address_id, email, preferred_time) — no `custom` dict at all.

## Intake Question Ordering Architecture

### Current State (Code Audit)

**No Integration / Google Calendar** (`src/utils.ts` line 1264):
```
typeOrder: { name: 0, address: 1, email: 2, custom: 3 }
```
`preferred_time` is NOT a question type — it's hardcoded separately in the "SAVING CALLER INFORMATION" section as "ALWAYS ASK after address/email."

Effective order today: **name → address → email → custom → preferred_time**

**FSM (Jobber / HCP)** (`src/server.ts` ~line 9644):
The generic intake section is **skipped entirely** (`isFieldServiceIntegration` gate). FSM has its own 10-step workflow:
1. `fs_get_customer_by_phone` (check existing)
2. `fs_get_services` (catalog)
3. Match service
4. **Collect name** → 5. `fs_create_customer`
6. Service area check
7. **Collect address** → validate → 8. `fs_create_property`
9. **Ask preferred time**
10. `fs_create_service_request` (includes `intake_answers` dict)

Custom intake questions are mentioned at step 10 as `intake_answers`, but **there is no explicit step to ASK the custom questions** in the FSM workflow. This is a gap.

### Recommended Architecture: Zone System

Instead of a flat reorderable list, define **zones** — fixed-position blocks in the conversation flow. Each zone has a specific purpose and a fixed position relative to other zones. Only the **Custom zone** is user-reorderable (internally).

```
┌─────────────────────────────────────────────────┐
│ Zone 1: IDENTITY          name                  │  ← Always first
├─────────────────────────────────────────────────┤
│ Zone 2: LOCATION          address + validate    │  ← Always second
├─────────────────────────────────────────────────┤
│ Zone 3: CONTACT           email (on/off toggle)  │  ← Third (if enabled)
├─────────────────────────────────────────────────┤
│ Zone 4: SCHEDULING        preferred_time        │  ← Fourth
├─────────────────────────────────────────────────┤
│ Zone 5: CUSTOM            custom questions      │  ← Last, reorderable
│                           (drag-and-drop)       │    within this zone
└─────────────────────────────────────────────────┘
```

**Why custom questions go LAST (after preferred_time):**
1. **Call drop resilience** — if the call drops during custom questions, we've already captured name, address, email, and preferred time (all the critical business data)
2. **Clean separation** — standard fields first, business-specific extras last
3. **FSM alignment** — in FSM workflow, custom answers feed into `fs_create_service_request` which is the last step before scheduling; asking them right before that step is natural
4. **Cognitive flow** — the caller handles the "business" of the call (who, where, when) first, then answers any special questions

### Cross-Integration Ordering

All three integration types share the same zone ordering. The difference is in *how* each zone is implemented (which tools are called), not *what order* they appear.

#### No Integration (Callback-Only)

```
1. NAME         → ask + spell → submit_intake_answers(name)
2. ADDRESS      → ask + validate_address → confirm → submit_intake_answers(address)
3. EMAIL        → ask (if enabled) → submit_intake_answers(email)
4. PREF TIME    → "When works best?" → submit_intake_answers(preferred_time)
5. CUSTOM Qs    → ask each in configured order → submit_intake_answers(custom fields)
6. → request_callback (mandatory post-intake if no scheduling tools)
```

#### Google Calendar

```
1. NAME         → ask + spell → submit_intake_answers(name)
2. ADDRESS      → ask + validate_address → confirm → submit_intake_answers(address)
3. EMAIL        → ask (REQUIRED for GCal reminders) → submit_intake_answers(email)
4. PREF TIME    → "When works best?" → submit_intake_answers(preferred_time)
5. CUSTOM Qs    → ask each in configured order → submit_intake_answers(custom fields)
6. → google_calendar_check_availability → google_calendar_create_event
```

#### FSM (Jobber / HCP) — New Caller

```
1. fs_get_customer_by_phone → fs_get_services → match service
2. NAME         → ask + spell → fs_create_customer
3. ADDRESS      → ask + validate → service area check → fs_create_property
4. EMAIL        → ask (if enabled) → submit_intake_answers(email)
5. PREF TIME    → "When works best?" (becomes desired_time)
6. CUSTOM Qs    → ask each in configured order
7. → fs_create_service_request(intake_answers={custom answers})
8. → (optional) fs_check_availability + fs_reschedule_assessment
```

Note: `preferred_time` maps to `desired_time` on the service request. Email is collected via `submit_intake_answers` (not an fs_* tool) since Jobber/HCP don't have an email field on customer creation.

#### FSM (Jobber / HCP) — Returning Caller

```
1. NAME         → skip (pre-loaded from platform)
2. ADDRESS      → confirm existing or collect new → fs_create_property if new
3. EMAIL        → ask (if enabled) → submit_intake_answers(email)
4. PREF TIME    → "When works best?"
5. CUSTOM Qs    → ask each in configured order
6. → fs_create_service_request(intake_answers={custom answers})
```

### FSM Workflow Changes

The unified `intakeQuestions` array provides configuration, but FSM maps it to its own step-based prompt format in `server.ts`. Two gaps need filling:

**Gap 1: Email** — FSM has no email collection step. When the email question is enabled (`required: true`), inject a step after address/fs_create_property (step 8) and before preferred_time (step 9). Email is saved via `submit_intake_answers` since fs_* tools don't handle email.

**Gap 2: Custom questions** — FSM mentions `intake_answers` on `fs_create_service_request` but has **no explicit steps to ask them**. Inject custom question steps between preferred_time (step 9) and fs_create_service_request (step 10).

When both are configured, the FSM new caller workflow becomes:

```
...
8.  fs_create_property (with validated address)
8a. EMAIL (conditional) — "Can I get your email address?" → submit_intake_answers(email)
9.  Ask preferred time
9a. CUSTOM INTAKE QUESTIONS (conditional, dynamically generated):
    "I just have a couple more questions before I get your request submitted."
    - Ask each custom question in configured order
    - Record answers for intake_answers dict
10. fs_create_service_request (with intake_answers from step 9a)
...
```

**What does NOT change for FSM:**
- Name/address/preferred_time handling stays as-is — tightly coupled to fs_* tool calls
- The FSM step numbering and workflow structure remain the same — we just conditionally inject email and custom question steps
- FSM prompt generation still lives in `server.ts` (not in `utils.ts` `generateIntakeSteps`)

### Data Model: Unified `intakeQuestions` Array

All intake questions — including email and preferred_time — live in one array. This is the single source of truth for what the agent asks and in what order.

```typescript
intakeQuestions: [
  { id: "uuid-1", type: "name",           label: "Name",           required: true },
  { id: "uuid-2", type: "address",        label: "Address",        required: true },
  { id: "uuid-3", type: "email",          label: "Email",          required: true },
  { id: "uuid-4", type: "preferred_time", label: "Preferred Time", required: true },
  { id: "uuid-5", type: "custom",         label: "Best time to call back?",
    customFieldKey: "best_time_to_call_back", required: true },
  { id: "uuid-6", type: "custom",         label: "Cabinet color preference?",
    customFieldKey: "cabinet_color_preference", required: true },
]
```

#### Schema Changes Required

**`intakeQuestionSchema`** in `more-user-endpoints.contract.ts` (line 791):
- Add `'preferred_time'` to the type enum: `z.enum(['name', 'address', 'email', 'preferred_time', 'custom'])`
- No `mode` field needed — email uses the same `required: true/false` as all other question types

**Email semantics**: For the `email` type, `required` means "enabled":
- `required: true` → agent asks for email (politely — if caller refuses, agent moves on)
- `required: false` → agent skips the email step entirely
- Google Calendar → backend overrides to `required: true` and the prompt adds "required for appointment reminders" (makes the agent more insistent)

**`generateDefaultIntakeQuestions()`** in `more-user-endpoints.contract.ts` (line 811):
- Expand from `[name, address]` to `[name, address, email, preferred_time]`
- Email defaults to `required: true` (ask by default, matching current `collectEmail ?? true` behavior)
- preferred_time defaults to `required: true`

**Null fallback**: If a location has `intakeQuestions: null` (e.g., created via API before defaults were set), prompt generation and agent-config should fall back to `generateDefaultIntakeQuestions()`.

#### Reserved Key Guard

Custom question `customFieldKey` values must not collide with base parameter names. The following keys are reserved and must be rejected in the UI and backend validation: `name`, `address`, `address_id`, `email`, `preferred_time`.

The frontend "Add Question" flow should auto-generate `customFieldKey` from the label (slugified) and check against the reserved list. The backend `updateLocation` handler should also validate this on save.

#### Retiring the `collectEmail` Toggle

**Current state**: `agent.config.collectEmail` (boolean) on the Agent model controls email collection. It's exposed in the frontend as a Switch toggle in two places:
- Inside "Scheduling Settings" when `hasFieldService` (line 3709-3720)
- As standalone "Intake Settings" when `!hasFieldService && !hasGoogleCalendar` (line 3724-3740)

**New state**: The email question's `required` field in `intakeQuestions` replaces `collectEmail`. The Intake tab shows a simple on/off toggle for email. The standalone collectEmail toggles are removed.

**Mapping** (for adhoc migration):
- `collectEmail: true` → email question with `required: true`
- `collectEmail: false` → email question with `required: false`
- `collectEmail: undefined` (default, treated as true) → email question with `required: true`

**Migration path**: Since there's only one location in the database, update its `intakeQuestions` directly via adhoc script. The script should:
1. Read the current `intakeQuestions` array and `agent.config.collectEmail` value
2. Insert `email` and `preferred_time` entries if missing
3. Set email `required` based on the current `collectEmail` value (true/undefined → true, false → false)
4. The `collectEmail` field on `agent.config` can remain but becomes ignored — prompt generation reads from `intakeQuestions` instead

#### Why This Is Better

1. **Single source of truth** — No split brain between `intakeQuestions`, `agent.config.collectEmail`, and hardcoded preferred_time logic
2. **Future reorderability is free** — To let future verticals reorder everything, just remove the UI drag constraints. No data model changes needed.
3. **Simpler prompt generation** — `generateIntakeSteps` iterates one array for ALL questions. No separate injection of email/preferred_time.
4. **Consistent UI** — All intake question configuration lives in the Intake tab, not scattered across Settings toggles

### Frontend UI Design

The restored Intake tab should be **simplified** for the current field-service vertical:

**What the UI shows:**

1. **Standard Intake Fields** (read-only summary, non-reorderable):
   - **Name** — "Always collected first" (no controls — always required)
   - **Address** — "Always collected second" (no controls — always required)
   - **Email** — On/Off toggle (replaces the collectEmail toggle)
     - For GCal integrations, this is locked to "On" with a tooltip: "Required for Google Calendar appointment reminders"
   - **Preferred Time** — "Always asked" (no controls — always required)

2. **Custom Questions** (below the standard fields):
   - "Add Question" button (creates a new custom-type question)
   - Drag-and-drop list of custom questions (reorderable within this block)
   - Edit / Remove buttons per question
   - Each question shows: label text, customFieldKey

**What the UI does NOT allow:**
- Reordering name, address, email, or preferred_time relative to each other
- Removing name, address, or preferred_time
- Adding duplicate name/address/email/preferred_time questions

**What needs to change vs current code:**
- Remove the `collectEmail` Switch toggle from "Scheduling Settings" (line 3709-3720) and "Intake Settings" (line 3724-3740) — replaced by email on/off toggle in the Intake tab
- Simplify the intake modal to only allow creating custom questions (lock type dropdown to "Custom")
- Show the standard fields as a non-editable summary with the email on/off toggle inline
- Auto-ensure `[name, address, email, preferred_time]` always exist in the array — prepend them on open if missing
- On save, construct as: `[name, address, email, preferred_time, ...customQuestionsInUserOrder]`

**What the current code already does (reusable):**
- The modal at line ~4740 already supports type selection (name, address, custom)
- `PRESET_INTAKE_TYPES` at line 771 already prevents duplicate name/address
- `SortableIntakeRow` at line 534 already implements drag-and-drop
- `handleToggleAgentConfig` at line 1874 already handles PATCH to update location — can be reused for saving email toggle

### Future Vertical Extensibility (Post-Launch)

Since all question types (name, address, email, preferred_time, custom) now live in one array, extending to new verticals requires only **UI and prompt generation changes** — no data model changes.

For future verticals like law/legal offices:

1. **Zone reordering** — Remove the `typeOrder` sort in `generateIntakeSteps`. The array order IS the question order. The UI would allow drag-and-drop of ALL question types, not just custom. A law office could configure: name → email → custom ("case type") → address (optional).

2. **Zone toggling** — A law office might not need address at all. Add a "remove" button to standard fields in the UI. When removed from the array, the agent skips that question. Name would likely remain non-removable across all verticals.

3. **New question types** — Add types like `'phone'` (for verticals where the caller's number isn't the contact number) or `'insurance_info'` (for medical/legal). Each type gets its own prompt generation logic in `getIntakeTypeInstructions`.

**For now**: The UI enforces fixed zone ordering for field service (name → address → email → preferred_time → custom). The data model is already ready for everything above.

## Implementation Steps

Implementation order is **backend-first**: schema → data → prompt generation → Python tool → backend validation → FSM → frontend. This ensures the backend is solid before the UI is built on top.

### Step 1: Schema Changes

**File**: `callsaver-api/src/contracts/more-user-endpoints.contract.ts`

1. Add `'preferred_time'` to the `intakeQuestionSchema` type enum (line 791)
2. No `mode` field needed — email uses `required: true/false` like all other types
3. Add reserved-key validation: custom questions with `customFieldKey` matching `name`, `address`, `address_id`, `email`, or `preferred_time` should be rejected
4. Expand `generateDefaultIntakeQuestions()` to return `[name, address, email (required: true), preferred_time]`

### Step 2: Adhoc Data Migration

**Script**: Update the one existing location's `intakeQuestions` directly.

1. Read the current `intakeQuestions` array and `agent.config.collectEmail` value
2. Insert `email` entry (with `required` derived from `collectEmail`: true/undefined → true, false → false) and `preferred_time` entry if missing
3. `collectEmail` field on `agent.config` remains but becomes ignored

### Step 3: Refactor Prompt Generation (Non-FSM)

**File**: `callsaver-api/src/utils.ts`

Now that all question types live in the `intakeQuestions` array, prompt generation simplifies:

**`generateIntakeSteps`** (~line 1260):
- Update `typeOrder` safety-net sort: `{ name: 0, address: 1, email: 2, preferred_time: 3, custom: 4 }`
- Add `case 'email':` and `case 'preferred_time':` to `getIntakeTypeInstructions()`
- For email: if `required: false`, skip the step entirely. If `required: true`, generate the email collection step. For GCal, the prompt adds "required for appointment reminders" to make the agent more insistent.
- For preferred_time: always generate the step (currently hardcoded in "SAVING CALLER INFORMATION" — move it into the loop)
- **Null fallback**: If `intakeQuestions` is null/undefined, use `generateDefaultIntakeQuestions()`

**`getIntakeTypeInstructions` — add `preferred_time` case** (~line 1166):
```typescript
case 'preferred_time':
    return ` Ask when works best for the service visit or appointment (e.g., "Do you have a preferred day or time for someone to come out?"). This is about when someone should come to the property — NOT when to receive a callback. If the caller says "anytime" or has no preference, record "anytime". Pass the answer as preferred_time in submit_intake_answers.`;
```

**🚨 "SAVING CALLER INFORMATION" section** (~line 1330) — **critical prompt update**:
- Remove the hardcoded "PREFERRED TIME — ALWAYS ASK" block (line 1347) — now generated as a step from the array
- Remove the separate email instruction lines — now generated as a step from the array
- **⚠️ Replace the `custom` dict instructions (lines 1340-1346)**. Currently the prompt tells the LLM:
  ```
  - custom: A dictionary of custom field answers. Keys and their meanings:
      - "preferred_contact_time": Answer to "Best time to call back?"
  ```
  With the new raw_schema, there IS no `custom` parameter — custom answers are flat params. If this prompt isn't updated, the LLM will try to pass a `custom` dict that doesn't exist in the tool schema. Replace with dynamically generated lines listing each custom field as its own parameter:
  ```typescript
  // Replace the custom dict block with:
  const customParamLines = customQs.map((q: any) =>
      `  - ${q.customFieldKey}: Answer to "${q.label}"`
  ).join('\n');
  // Output:
  //   - best_time_to_call_back: Answer to "Best time to call back?"
  //   - cabinet_color: Answer to "What color cabinets?"
  ```
- The example flow simplifies to: "Name → Address → submit → Email (if enabled) → Preferred Time → Custom Qs → submit again with all collected fields"
- The `collectEmail` variable (line 1152) is no longer read from the function parameter — read the email question's `required` from the `intakeQuestions` array

**Email injection block in `server.ts`** (~lines 9492-9511):
- **Remove the entire block**: the `collectEmailMode` 3-way mapping (lines 9497-9502), the `emailSection` string construction (lines 9506-9509), and the `systemPrompt = systemPrompt + emailSection` injection (line 9510). Email is now handled by `generateIntakeSteps` from the array.
- GCal override: when building the agent config, if GCal is active, override the email question's `required` to `true` in the `intakeQuestions` array **before** passing it to `generateSystemPrompt`. Also pass an `isGoogleCalendar` flag so prompt generation can add the "required for appointment reminders" tone to the email step.

### Step 4: Inject Email + Custom Question Steps into FSM Workflow

**File**: `callsaver-api/src/server.ts` (FSM instructions block, ~line 9658)

**⚠️ FSM dual-tool note**: In FSM, custom answers flow through `fs_create_service_request` (as `intake_answers` dict → stored as a note in Jobber/HCP), NOT through `submit_intake_answers`. The dynamic `submit_intake_answers` schema will still have custom field params (generated in Step 6), but the FSM prompt explicitly tells the LLM to pass them via `fs_create_service_request`. This is intentional — having unused params on `submit_intake_answers` is harmless, and keeps the tool schema consistent across integration types.

**⚠️ `fs_submit_lead` gap** (HCP): The simplified `fs_submit_lead` tool does not currently accept `intake_answers`. If HCP uses this path instead of step-by-step tools, custom answers need to either: (a) be appended to `service_description`, or (b) have `intake_answers` added to `fs_submit_lead`. Flag for follow-up.

Read the `intakeQuestions` array and conditionally inject two step blocks:

**4a. Email step** (between fs_create_property and preferred_time):
```typescript
const emailQuestion = ((location.intakeQuestions as any[]) || [])
    .find((q: any) => q.type === 'email');
const collectEmail = emailQuestion?.required !== false; // default true

let emailStepText = '';
if (collectEmail) {
    emailStepText = `
8a. Ask for the caller's **email address**. If they decline, that is okay — move on. Save it by calling **submit_intake_answers** with the email parameter.`;
}
```

**4b. Custom question steps** (between preferred_time and fs_create_service_request):
```typescript
const customIntakeQuestions = ((location.intakeQuestions as any[]) || [])
    .filter((q: any) => q.type === 'custom' && q.customFieldKey);

let customStepsText = '';
if (customIntakeQuestions.length > 0) {
    const questionLines = customIntakeQuestions.map((q: any, i: number) => {
        const prompt = q.promptText || q.label;
        return `   ${String.fromCharCode(97 + i)}. Ask: "${prompt}" — save the answer as "${q.customFieldKey}"`;
    }).join('\n');
    customStepsText = `
9a. **CUSTOM INTAKE QUESTIONS** — Before submitting the service request, ask these additional questions:
    "I just have a couple more questions before I get your request submitted."
${questionLines}
    Record all answers — you will pass them as the **intake_answers** dictionary in step 10.`;
}
```

### Step 5: Pass Custom Questions to Python Agent

**File**: `callsaver-api/src/server.ts` (agent-config endpoint, ~line 9931)

Add `customIntakeQuestions` to the agent config response:

```typescript
const intakeQuestions = (location.intakeQuestions as any[]) || generateDefaultIntakeQuestions();

const response = {
    systemPrompt: finalSystemPrompt,
    tools,
    // ... existing fields ...
    // NEW: Pass custom intake question definitions for dynamic tool schema
    customIntakeQuestions: intakeQuestions
        .filter((q: any) => q.type === 'custom' && q.customFieldKey)
        .map((q: any) => ({
            customFieldKey: q.customFieldKey,
            label: q.label,
            promptText: q.promptText || q.label,
        })),
};
```

### Step 6: Dynamic Tool Schema in Python

**File**: `callsaver-api/livekit-python/tools/submit_intake_answers.py`

Replace the current `@function_tool()` decorated function with `function_tool(handler, raw_schema=schema)`:

```python
def submit_intake_answers_tool(context: "ToolContext"):
    """Create submit intake answers tool with dynamic schema based on configured custom questions."""

    # Get custom intake questions from agent config
    custom_questions = (context.agent_config or {}).get("customIntakeQuestions", [])

    # Build base properties (always present)
    properties = {
        "name": {"type": "string", "description": "Caller's full name (if collected)"},
        "address": {
            "type": "string",
            "description": "New service address - use normalized address from validate_address if available",
        },
        "address_id": {
            "type": "string",
            "description": "ID of an existing address the caller selected/confirmed (mutually exclusive with address)",
        },
        "email": {"type": "string", "description": "Caller's email (if collected)"},
        "preferred_time": {
            "type": "string",
            "description": "Caller's preferred day or time for the appointment or service visit (freeform)",
        },
    }

    # Add dynamic properties for each configured custom question
    custom_field_keys = set()
    for q in custom_questions:
        key = q.get("customFieldKey")
        desc = q.get("promptText") or q.get("label") or key
        if key:
            properties[key] = {"type": "string", "description": desc}
            custom_field_keys.add(key)

    schema = {
        "type": "function",
        "name": "submit_intake_answers",
        "description": (
            "MANDATORY: Call this tool to save caller information you collected during the call. "
            "You MUST call this after collecting the caller's name and/or confirmed address. "
            "Do NOT wait until the end of the call. You can call this tool multiple times — it merges with existing data. "
            "For addresses: use address_id for existing, address for new (mutually exclusive). "
            "Do NOT include the country in the address string."
        ),
        "parameters": {
            "type": "object",
            "properties": properties,
        },
    }

    async def handler(raw_arguments: dict, context: RunContext):
        # ... existing handler logic, but reads from raw_arguments ...
        # Separate base fields from custom fields
        name = raw_arguments.get("name")
        address = raw_arguments.get("address")
        address_id = raw_arguments.get("address_id")
        email = raw_arguments.get("email")
        preferred_time = raw_arguments.get("preferred_time")

        # Collect custom field answers (only configured keys)
        custom = {}
        for key in custom_field_keys:
            val = raw_arguments.get(key)
            if val and str(val).strip():
                custom[key] = str(val).strip()

        # ... rest of existing POST logic to /internal/intake-answers ...

    return function_tool(handler, raw_schema=schema)
```

**Key detail**: The handler receives `raw_arguments: dict` (not named params) when using `raw_schema`. We extract base fields by name and collect custom fields by iterating `custom_field_keys`.

### Step 7: Verify Agent Config → Tool Context

**File**: `callsaver-api/livekit-python/server.py`

The `ToolContext` already has `agent_config` — verify that `customIntakeQuestions` is available when the tool is registered. This should work automatically since `agent_config` is set before `register_tools()` is called.

### Step 8: Backend Validation (Defense in Depth)

**File**: `callsaver-api/src/server.ts` (`/internal/intake-answers` endpoint, ~line 10839)

Add allowlist validation before merging custom answers:

```typescript
if (answers.custom != null && typeof answers.custom === 'object') {
    const location = await prisma.location.findUnique({
        where: { id: locationId },
        select: { intakeQuestions: true },
    });
    const allowedKeys = new Set(
        ((location?.intakeQuestions as any[]) || [])
            .filter((q: any) => q.type === 'custom' && q.customFieldKey)
            .map((q: any) => q.customFieldKey)
    );

    const filtered: Record<string, string> = {};
    for (const [k, v] of Object.entries(answers.custom as Record<string, string>)) {
        if (allowedKeys.has(k)) {
            filtered[k] = v;
        } else {
            console.warn(`[intake-answers] Rejected unknown custom key: "${k}" (allowed: ${[...allowedKeys].join(', ')})`);
        }
    }
    // Use filtered instead of raw answers.custom
}
```

Defense-in-depth — even if the dynamic schema constraint is bypassed, the backend rejects unknown keys.

### Step 9: Restore & Simplify Frontend UI

**File**: `callsaver-frontend/src/pages/LocationsPage.tsx`

#### 9a. Uncomment the Intake tab and section

1. **Line ~2861** — Uncomment the Intake tab in the `tabs-toggle` tab bar
2. **Lines ~3533-3604** — Uncomment the Intake section panel

#### 9b. Simplify the modal to enforce zone system

- **Lock type dropdown to "Custom" only**. Name, address, email, preferred_time are always auto-included.
- **Auto-ensure standard fields exist**: When opening the modal, if `intakeQuestions` doesn't have `name`, `address`, `email`, `preferred_time`, auto-prepend them. These are non-removable.
- **Show standard fields as read-only summary**:
  - Name — "Always collected first"
  - Address — "Always collected second"
  - Email — On/Off toggle (replaces the collectEmail toggle). For GCal, locked to "On" with tooltip.
  - Preferred Time — "Always asked"
- **Below the summary**: "Custom Questions (asked after the standard intake):" with drag-and-drop reorderable list + "Add Question" button
- **Drag-and-drop only applies to custom questions** — standard field rows have no drag handles or remove buttons

#### 9c. Remove collectEmail toggles

- Remove the `collectEmail` Switch from "Scheduling Settings" block (line 3709-3720)
- Remove the standalone "Intake Settings" block (line 3724-3740)
- Email is now controlled by the on/off toggle in the Intake tab

#### 9d. Ensure intakeQuestions array is well-formed on save

When saving, construct the array as: `[name, address, email, preferred_time, ...customQuestionsInUserOrder]`. This guarantees the backend always receives a well-ordered array regardless of UI state.

### Step 10: ~~Cleanup Existing Bad Data~~ ✅ DONE

Bad data has already been manually cleaned. No further action needed.

## File Change Summary

| Step | File | Change | Risk |
|------|------|--------|------|
| 1 | `callsaver-api/src/contracts/more-user-endpoints.contract.ts` | Add `'preferred_time'` to type enum; reserved-key validation; expand `generateDefaultIntakeQuestions()` | Low |
| 2 | Adhoc script | Update one location's `intakeQuestions` to include email + preferred_time entries | Low |
| 3 | `callsaver-api/src/utils.ts` | Refactor `generateIntakeSteps` for all types; remove hardcoded preferred_time/email blocks; **⚠️ replace `custom` dict prompt with flat param listing** | **High** |
| 3 | `callsaver-api/src/server.ts` (email injection) | **Remove entire block** (lines 9492-9511): `collectEmailMode` mapping + `emailSection` injection; GCal overrides email `required` | Low |
| 4 | `callsaver-api/src/server.ts` (FSM instructions) | Inject email + custom question steps into FSM workflow | Medium |
| 5 | `callsaver-api/src/server.ts` (agent-config) | Add `customIntakeQuestions` to response | Low |
| 6 | `callsaver-api/livekit-python/tools/submit_intake_answers.py` | Rewrite to use `raw_schema` dynamic generation | Medium |
| 7 | `callsaver-api/livekit-python/server.py` | Verify `customIntakeQuestions` in ToolContext (likely no change) | None |
| 8 | `callsaver-api/src/server.ts` (intake-answers) | Add allowlist validation for custom keys | Low |
| 9 | `callsaver-frontend/.../LocationsPage.tsx` | Uncomment tab + section; simplify modal; add email on/off toggle; remove collectEmail toggles | Medium |

## Testing Plan

### Unit Tests (Python)

1. **Dynamic schema generation** — Verify correct properties for 0, 1, N custom questions
2. **Handler field separation** — Verify base fields extracted correctly, custom fields collected by key
3. **No custom questions** — Schema has base params only, no `custom` dict, tool still works
4. **Collision safety** — Custom field key that matches a base field name (e.g., someone names a custom question "name") is handled gracefully

### Backend Tests (TypeScript)

5. **Allowlist validation** — `/internal/intake-answers` rejects unknown custom keys, accepts configured ones
6. **Agent config response** — `customIntakeQuestions` array matches location's configured custom questions
7. **Reserved key rejection** — `updateLocation` rejects custom questions with `customFieldKey` matching reserved names (`name`, `address`, `address_id`, `email`, `preferred_time`)

### Prompt Generation Tests (TypeScript)

8. **🚨 Custom params listed as flat params (not dict)** — With custom questions configured, verify the "SAVING CALLER INFORMATION" section lists each custom field as its own param (e.g., `- best_time_to_call_back: Answer to "..."`) and does NOT reference a `custom` dict
9. **Email step generated from array** — Verify `generateIntakeSteps` produces an email step when `required: true`, skips when `required: false`
10. **Preferred time step generated** — Verify `generateIntakeSteps` produces a preferred_time step, and the hardcoded "PREFERRED TIME — ALWAYS ASK" block is gone
11. **GCal email override** — Verify that when GCal is active, email `required` is forced to `true` and prompt says "required for appointment reminders"
12. **FSM email injection** — Verify step 8a appears in FSM prompt when email is enabled
13. **FSM custom question injection** — Verify step 9a with custom questions appears in FSM prompt, referencing `intake_answers` on `fs_create_service_request`

### Integration Tests (Voice Call)

14. **No Integration + custom questions** — Verify ordering: name → address → email → preferred_time → custom questions → request_callback
15. **Google Calendar + custom questions** — Same ordering, email is REQUIRED, custom answers stored correctly
16. **FSM (Jobber/HCP) + custom questions** — Custom question steps appear between preferred_time and fs_create_service_request; answers passed as `intake_answers`
17. **FSM returning caller + custom questions** — Custom questions still asked even when name/address are skipped
18. **No custom questions configured** — All three integration types work without any custom questions (regression)
19. **Call drop resilience** — If call drops during custom questions, name/address/email/preferred_time are already saved via earlier submit_intake_answers call

### Frontend Tests

20. **Intake tab visible** — Tab appears in `tabs-toggle` layout
21. **Custom question CRUD** — Add, edit, remove, reorder custom questions
22. **Fixed zones read-only** — Name/address cannot be removed or reordered
23. **Save round-trip** — Save → reload → questions preserved in correct order
24. **Email toggle** — On/Off toggle updates email question's `required` field; GCal locks to On
25. **Reserved key guard** — Cannot create custom question with key matching reserved names

## Alternatives Considered

| Approach | Prevents ad-hoc keys? | LLM sees explicit params? | Effort |
|----------|----------------------|--------------------------|--------|
| **Raw schema (this plan)** | ✅ Structurally impossible | ✅ Each question = named param | Medium |
| Constrain via docstring only | ❌ LLM can still hallucinate | ❌ Generic dict | Low |
| Backend validation only | ⚠️ Rejects after the fact | ❌ Generic dict | Low |
| `update_tools()` dynamic add | ✅ Same as raw schema | ✅ Same | Medium (unnecessary complexity — we know questions at startup) |

## LiveKit Docs Reference

- [Creating tools from raw schema](https://docs.livekit.io/agents/logic/tools/#creating-tools-from-raw-schema)
- [Creating tools programmatically](https://docs.livekit.io/agents/logic/tools/#creating-tools-programmatically)
- [Adding tools dynamically](https://docs.livekit.io/agents/logic/tools/#adding-tools-dynamically) (not needed — questions known at startup)
