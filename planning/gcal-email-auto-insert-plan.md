# GCal Email Auto-Insert Plan

When Google Calendar becomes the active integration, the backend should automatically ensure the `email` intake question exists at slot 3 (index 2: after Name and Address) in every location's `intakeQuestions` array.

## Why

Email is **required** for GCal appointment reminders (A2P SMS not yet available). The production prompt already marks email as required via `isGoogleCalendar` conditionals in `utils.ts:1201` and `utils.ts:1350`. But if the `email` question isn't in the `intakeQuestions` array, the agent won't have a dedicated intake step to collect it — the prompt says "required" but there's no step in the flow to ask for it.

## Current Architecture

### Frontend: Intake Questions Modal (`LocationsPage.tsx`)

- **Fixed slots**: Name, Address, Email — `FIXED_TYPES = new Set(['name', 'address', 'email'])` (line 2016). These cannot be dragged/reordered.
- **Email auto-insert in UI**: When user adds an email question, it auto-inserts after address (lines 4867–4873).
- **Email CAN be removed**: Trash button exists for email (lines 4986–4996). Name and Address cannot be removed.
- **Default intake questions** (`generateDefaultIntakeQuestions()` in `more-user-endpoints.contract.ts:816`): Name → Address → Email → Preferred Time. New locations get email by default.

### Frontend: Integration Connection Flow

Both `OnboardingPage.tsx` and `IntegrationsPage.tsx` use `IntegrationConnectDialog` → `usePipedreamAuth` hook. On OAuth success:
1. Pipedream iFrame completes
2. Frontend calls `POST /me/integrations/connect` with `{ accountId, integrationType: 'google-calendar' }`
3. Frontend calls `refetchIntegrations()` to update UI state

**Neither page touches `intakeQuestions` when connecting GCal.**

### Backend: `POST /me/integrations/connect` (`server.ts:7449–7574`)

1. Validates `integrationType` ∈ `['google-calendar', 'jobber']`
2. Deletes existing connections (single-integration model)
3. Creates new `IntegrationConnection` record
4. Invalidates GCal caches
5. Returns success

**Does NOT touch `intakeQuestions` at all.**

### Backend: `PATCH /me/locations/:locationId` (`server.ts:4779–5128`)

Handles intake question saves. Validates against `z.array(intakeQuestionSchema)`. No auto-add logic for email based on integration type.

### Backend: `cleanupAfterDisconnect` (`server.ts:3598–3647`)

Only cleans up field-service integrations (jobber, housecall-pro, servicetitan). Does NOT handle google-calendar. Does NOT touch `intakeQuestions`.

### Existing precedent: `autoScheduleAssessment` toggle

In `LocationsPage.tsx:1894–1911`, toggling `autoScheduleAssessment`:
- ON → removes `preferred_time` from `intakeQuestions`
- OFF → adds `preferred_time` back

This is done on the **frontend** before calling `updateLocation`. Our email auto-insert is better placed on the **backend** because:
1. **Single bottleneck**: `POST /me/integrations/connect` is the only path where GCal gets activated, regardless of which page triggers it
2. **No frontend duplication**: Don't need to add the same logic to both `OnboardingPage` and `IntegrationsPage`
3. **Server authority**: Backend is the source of truth for what the agent sees

## Implementation Plan

### Step 1: Backend — Auto-insert email in `POST /me/integrations/connect`

**File**: `src/server.ts` — inside `POST /me/integrations/connect`, after connection creation (line 7534) and before the existing cache invalidation block (line 7537).

**Logic**:

```typescript
// When Google Calendar is connected, ensure email intake question exists
// Email is REQUIRED for GCal appointment reminders (no A2P SMS yet)
if (integrationType === 'google-calendar') {
  const locations = await prisma.location.findMany({
    where: { organizationId },
    select: { id: true, intakeQuestions: true }
  });

  for (const loc of locations) {
    const questions = (loc.intakeQuestions as any[]) || [];

    // Skip if no intake questions configured (null/empty = not yet set up)
    // Onboarding generates default questions which already include email
    if (questions.length === 0) continue;

    // Skip if email already exists
    const hasEmail = questions.some((q: any) => q.type === 'email');
    if (hasEmail) continue;

    // Insert email after address (slot 2), or after name, or at start
    const emailQuestion = {
      id: crypto.randomUUID(),
      type: 'email',
      label: 'Email',
      required: true,
    };

    const addressIdx = questions.findIndex((q: any) => q.type === 'address');
    const nameIdx = questions.findIndex((q: any) => q.type === 'name');
    let insertAt: number;
    if (addressIdx >= 0) {
      insertAt = addressIdx + 1; // After address = slot 2
    } else if (nameIdx >= 0) {
      insertAt = nameIdx + 1; // After name
    } else {
      insertAt = 0; // Fallback: beginning
    }

    const updatedQuestions = [
      ...questions.slice(0, insertAt),
      emailQuestion,
      ...questions.slice(insertAt),
    ];

    await prisma.location.update({
      where: { id: loc.id },
      data: { intakeQuestions: updatedQuestions },
    });

    console.log(`📧 GCal: Auto-added email intake question at position ${insertAt} for location ${loc.id}`);
  }
}
```

### Step 2 (optional): Frontend — Prevent email removal when GCal is active

**File**: `LocationsPage.tsx` — in the intake questions modal (lines 4986–4996).

Currently email has a Trash button. When GCal is connected, we should either:
- **Option A**: Hide the trash button entirely (cleanest)
- **Option B**: Show a warning tooltip: "Email is required for Google Calendar appointment reminders"

This requires knowing whether GCal is the active integration. The `useIntegrations()` hook already provides `connectedIntegration` — we'd pass `isGCalConnected` down to the modal rendering.

**This is a polish item** — the backend auto-insert ensures email is present at connection time, and even if the user removes it afterward, the prompt still says email is required so the agent will still ask for it (just without a numbered step in the intake flow).

### Step 3 (not needed): Disconnecting GCal

Do **NOT** remove email when GCal is disconnected. Email is still useful for non-GCal flows (general business communication). The prompt just stops marking it as required — `isGoogleCalendar` becomes false, so the prompt says "If the caller declines, that is okay — move on" instead.

## Edge Cases

| Scenario | Behavior |
|---|---|
| `intakeQuestions` is null/empty | Skip — onboarding will set defaults (which include email) |
| Email already in array | No-op |
| Multiple locations | Apply to all locations in org |
| No address question in array | Insert after name. No name either? Insert at position 0 |
| User removes email after GCal connected | Agent still asks for email (prompt says required), just no dedicated numbered step. Optional: frontend Step 2 prevents this |
| Switching from Jobber/HCP to GCal | Intake questions exist from initial setup. Email may have been removed — auto-insert adds it back |
| Switching from GCal to Jobber/HCP | Email stays (not removed). FS integrations don't use intake questions (they have their own fs_* workflow) |
| Reconnecting same GCal account | `POST /me/integrations/connect` fires again → email check runs again → no-op if already present |

## Files to Modify

| File | Change |
|---|---|
| `src/server.ts` (line ~7534) | Add email auto-insert block after connection creation in `POST /me/integrations/connect` |
| `src/pages/LocationsPage.tsx` (optional) | Hide email trash button when GCal is active integration |

## Effort

- **Step 1 (backend)**: ~15 lines of code, ~15 minutes
- **Step 2 (frontend, optional)**: ~10 lines, ~15 minutes
- **Testing**: Manual test via staging — connect GCal with and without email in intake questions, verify auto-insert
