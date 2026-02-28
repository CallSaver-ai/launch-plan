# Email Collection — Implementation Status & Design

**Date:** February 26, 2025
**Status:** Implemented (pending deployment)
**Related files:**
- `~/callsaver-api/src/server.ts` — `/internal/agent-config` endpoint (email logic + prompt injection)
- `~/callsaver-api/src/contracts/more-user-endpoints.contract.ts` — `collectEmail` in schema
- `~/callsaver-api/livekit-python/tools/collect_email.py` — `GetEmailTask` wrapper
- `~/callsaver-api/livekit-python/tools/__init__.py` — tool registration
- `~/callsaver-frontend/src/pages/LocationsPage.tsx` — toggle UI

---

## 1. What Has Been Done

### Backend — `callsaver-api`

#### Agent Config Endpoint (`src/server.ts` — `/internal/agent-config`)

The endpoint now determines email collection mode based on integration type and the `agent.config.collectEmail` boolean:

```
hasGoogleCalendar = tools.some(t => t.startsWith('google-calendar'))
agentConfig = (agent?.config as any) || {}
collectEmailEnabled = hasGoogleCalendar ? true : (agentConfig.collectEmail !== false)
collectEmailMode = hasGoogleCalendar ? 'required' : (collectEmailEnabled ? 'optional' : 'off')
```

- If mode is not `'off'`, the `collect-email` tool is pushed to the tools list.
- Email collection instructions are **appended to the system prompt** after `buildDynamicAssistantConfig` generates the base prompt.

**Required mode (Google Calendar):**
> 📧 EMAIL COLLECTION — REQUIRED
> You MUST collect the caller's email address before completing the booking. Use the **collect_email** tool — it handles voice-to-text normalization automatically (e.g., "dot", "at", "underscore" are converted to symbols). After collecting, call submit_intake_answers with the email.

**Optional mode (all others with toggle on):**
> 📧 EMAIL COLLECTION — OPTIONAL
> Offer to collect the caller's email for confirmation (e.g., "Would you like to provide an email address for a confirmation?"). If they agree, use the **collect_email** tool — it handles voice-to-text normalization automatically. After collecting, call submit_intake_answers with the email. If they decline, proceed without it.

#### Contract Schema (`src/contracts/more-user-endpoints.contract.ts`)

`collectEmail` added to the `agentConfig` Zod schema:

```typescript
agentConfig: z.object({
  autoScheduleAssessment: z.boolean().optional(),
  includePricing: z.boolean().optional(),
  collectEmail: z.boolean().optional().describe(
    'Whether the voice agent collects email during intake (default true). '
    'Always required for Google Calendar regardless of this setting.'
  ),
}).optional()
```

#### PATCH Handler (`src/server.ts` — `/me/locations/:locationId`)

The `collectEmail` boolean is merged into `agent.config` alongside existing toggles:

```typescript
if (agentConfigBody.collectEmail !== undefined) {
  updatedConfig.collectEmail = agentConfigBody.collectEmail;
}
```

#### Generated API Client (`src/lib/generated-api-client/services/UserService.ts`)

`collectEmail?: boolean` added to the `agentConfig` request body type.

### Python Agent — `callsaver-api/livekit-python`

#### `tools/collect_email.py`

A `@function_tool` wrapper around LiveKit's `GetEmailTask`:

- Instantiates `GetEmailTask` with the current session's `chat_ctx`, `llm`, `tts`, `stt`, `vad`
- `GetEmailTask` handles noisy voice transcription (e.g., "j-o-h-n at gmail dot com" → `john@gmail.com`)
- Returns the confirmed email address string, or `None` if collection failed/was cancelled

#### `tools/__init__.py`

The `collect-email` tool is registered when the tool name appears in the tools list:

```python
elif tool_name == "collect-email":
    tool = collect_email
```

#### `server.py`

`EndCallTool` is always added to allow the agent to gracefully end calls when the conversation naturally concludes.

### Frontend — `callsaver-frontend`

#### Location Type (`LocationsPage.tsx`)

```typescript
agentConfig?: {
  autoScheduleAssessment?: boolean;
  includePricing?: boolean;
  collectEmail?: boolean;       // ← Added
};
```

#### Integration Detection

```typescript
const hasGoogleCalendar = connectedIntegration?.type === 'google-calendar';
```

#### Toggle Handler

`handleToggleAgentConfig` extended to accept `'collectEmail'` as a key:

```typescript
const handleToggleAgentConfig = async (
  location: Location,
  key: 'autoScheduleAssessment' | 'includePricing' | 'collectEmail',
  enabled: boolean
) => { ... }
```

#### Toggle UI

Two placement scenarios:

**1. Field Service integrations (Jobber / HCP):** The "Collect Email" toggle appears **inside** the Scheduling Settings block, below the existing "Include Pricing" toggle:

```
┌─ Scheduling Settings ──────────────────────┐
│  Auto-Schedule Assessments     [toggle]     │
│  Include Pricing               [toggle]     │
│  Collect Email                 [toggle]     │  ← Added here
└─────────────────────────────────────────────┘
```

**2. No Integration (standalone):** A standalone "Intake Settings" section appears with just the "Collect Email" toggle:

```
┌─ Intake Settings ──────────────────────────┐
│  Collect Email                 [toggle]     │
└─────────────────────────────────────────────┘
```

**3. Google Calendar:** No toggle is shown. Email is **always required** for GCal (needed for appointment reminders / attendee emails). The backend forces `collectEmailMode = 'required'` regardless of the `agent.config.collectEmail` value.

---

## 2. Toggle Behavior by Integration

| Integration | Toggle Visible? | Default Value | Behavior When On | Behavior When Off |
|---|---|---|---|---|
| **Google Calendar** | ❌ No toggle shown | Always on | Agent MUST collect email before booking. Prompt says "REQUIRED." Email passed as `attendee_email` to `google-calendar-create-event`. | N/A — cannot be turned off |
| **Jobber** | ✅ In Scheduling Settings | On (`true`) | Agent OPTIONALLY offers to collect email. Prompt says "OPTIONAL." Email passed to `fs-create-customer` or `fs-submit-lead`. | Agent does not ask for email |
| **Housecall Pro** | ✅ In Scheduling Settings | On (`true`) | Same as Jobber — optional email collection | Agent does not ask for email |
| **No Integration** | ✅ In Intake Settings | On (`true`) | Agent OPTIONALLY offers to collect email. Email saved via `submit_intake_answers(email=...)` | Agent does not ask for email |

---

## 3. System Prompt Integration

The email instructions are injected **after** the base system prompt is generated by `buildDynamicAssistantConfig`. This ensures:

1. The base prompt is generated normally without email-specific logic
2. The email section is appended as a clear, separate block
3. The `collect-email` tool is added to the tools list so the Python agent registers it

The prompt instructs the agent to:
- Use the `collect_email` tool (which wraps `GetEmailTask` for voice normalization)
- After collecting, call `submit_intake_answers` with the email (for No Integration / GCal)
- For Jobber/HCP, the email flows through `fs-create-customer` or `fs-submit-lead` instead

---

## 4. Data Flow

### No Integration / Google Calendar

```
Caller speaks email
  → collect_email tool (GetEmailTask handles "at" → @, "dot" → .)
  → Returns confirmed email string
  → Agent calls submit_intake_answers(email="john@example.com")
  → Backend POST /internal/intake-answers
  → Stored on Caller record
  → (GCal only) Also passed as attendee_email to google-calendar-create-event
```

### Jobber / HCP

```
Caller speaks email
  → collect_email tool (GetEmailTask)
  → Returns confirmed email string
  → Agent passes email to fs-create-customer(email="john@example.com")
    OR fs-submit-lead(email="john@example.com")
  → Backend creates/updates customer in Jobber/HCP with email
```

---

## 5. What Remains

- [ ] **Deploy** backend changes (agent-config endpoint + PATCH handler)
- [ ] **Deploy** Python agent changes (collect_email tool + EndCallTool)
- [ ] **Deploy** frontend changes (toggle UI)
- [ ] **Test** GCal flow: email required, no toggle visible, email used as attendee
- [ ] **Test** Jobber/HCP flow: toggle on/off, email passed to fs tools
- [ ] **Test** No Integration flow: toggle on/off, email saved via submit_intake_answers
- [ ] **Test** `GetEmailTask` voice normalization with real calls (e.g., "john dot doe at gmail dot com")
