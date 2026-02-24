# Pre-Launch Improvements Plan

**Created:** Feb 17, 2026
**Status:** Proposal — do not implement until reviewed

---

## 1. Change Default Voice from "Katie" to "Ray"

### Goal
Make "Ray" the default voice for newly provisioned locations and the first voice displayed in the onboarding flow.

### Current State
- **Backend (`~/callsaver-api/src/services/provision-execution.ts:461`)**: `createLocationWithFullEnrichment` creates the default Agent with `voiceId: 'Katie'`.
- **Backend (`~/callsaver-api/src/server.ts:3130`)**: The `GET /me/locations/:locationId/agent` endpoint creates a fallback agent with `voiceId: 'Katie'` if none exists.
- **Backend (`~/callsaver-api/src/server.ts:3287`)**: The `PATCH .../agent/voice` endpoint also falls back to `'Katie'` when creating a new agent.
- **Frontend (`~/callsaver-frontend/src/lib/voice-config.ts:81`)**: `DEFAULT_VOICE = CARTESIA_VOICES.Katie`.
- **Frontend (`~/callsaver-frontend/src/lib/voice-config.ts:193-198`)**: `getAllVoices()` moves Katie to the front of the array.
- **Frontend (`~/callsaver-frontend/src/pages/OnboardingPage.tsx:465`)**: Form `defaultValues` has `voice: 'Katie'`.
- **Frontend (`~/callsaver-frontend/src/pages/OnboardingPage.tsx:621-624`)**: Voice step initialization defaults to `'Katie'`.

### Changes Required

#### `~/callsaver-api` (3 files)
1. **`src/services/provision-execution.ts:461`** — Change `voiceId: 'Katie'` → `voiceId: 'Ray'` in `createLocationWithFullEnrichment`.
2. **`src/server.ts:3130`** — Change fallback `voiceId: 'Katie'` → `'Ray'` in `GET /me/locations/:locationId/agent` (agent creation fallback).
3. **`src/server.ts:3191`** — Change response fallback `agent.voiceId || 'Katie'` → `agent.voiceId || 'Ray'`.
4. **`src/server.ts:3287`** — Change `voiceId: voiceId || 'Katie'` → `voiceId: voiceId || 'Ray'` in `PATCH .../agent/voice`.

#### `~/callsaver-frontend` (2 files)
1. **`src/lib/voice-config.ts`**:
   - Line 31: Update Katie's description from `'Good (default)'` → `'Good'`.
   - Line 58: Update Ray's description from `'Pretty good'` → `'Good (default)'`.
   - Line 81: Change `DEFAULT_VOICE = CARTESIA_VOICES.Katie` → `CARTESIA_VOICES.Ray`.
   - Lines 193-198: Update `getAllVoices()` to move Ray to the front instead of Katie.
2. **`src/pages/OnboardingPage.tsx`**:
   - Line 452: Change `currentVoiceIndex` comment to reference Ray.
   - Line 465: Change `voice: 'Katie'` → `voice: 'Ray'` in form defaults.
   - Lines 621-624: Change `selectedVoiceId = 'Katie'` → `selectedVoiceId = 'Ray'` and update log message.

### Risk
Low. Existing provisioned locations keep their current voice. Only new provisions are affected.

---

## 2. Transfer Number Editing in Location Settings

### Goal
Add an "Edit" button to the "Call Handling" card in LocationsPage that opens a modal for editing the transfer phone number (only when `onboardingPath === 'full_auto_pilot'`).

### Current State
- **Frontend (`~/callsaver-frontend/src/pages/LocationsPage.tsx:3054-3090`)**: The "Call Handling" section displays `transferPhoneNumber` read-only with no Edit button.
- **Backend (`~/callsaver-api/src/server.ts:3888-4216`)**: `PATCH /me/locations/:locationId` already accepts `transferPhoneNumber` and `onboardingPath` in the request body with validation (E.164 format regex).
- **Agent config (`~/callsaver-api/src/server.ts:8920-8972`)**: The `/internal/agent-config` endpoint reads `location.transferPhoneNumber` and injects it into the transfer instructions for Path B agents. So updating the number on the Location model automatically updates the agent's behavior on next call.

### Changes Required

#### `~/callsaver-frontend` (1 file)
1. **`src/pages/LocationsPage.tsx`**:
   - Add state variables: `transferModalOpen`, `transferModalLocationId`, `editingTransferNumber`.
   - Add an "Edit" button (pencil icon or text) to the Call Handling card, positioned similarly to other section Edit buttons (e.g., Voice Agent section).
   - Create a modal (Dialog) that:
     - Displays the current transfer number (formatted as `(xxx) xxx-xxxx`).
     - Has an input field with phone number formatting: `(xxx) xxx-xxxx` display format.
     - Limits input to digits only, max 10 digits (strip leading `1` if 11 digits entered).
     - Validates: must be exactly 10 digits, cannot be the same as the CallSaver provisioned number.
     - On save: calls `PATCH /me/locations/:locationId` with `{ transferPhoneNumber: "+1XXXXXXXXXX" }` (convert to E.164 before sending).
     - Shows success toast and updates local state.
   - Only show the Edit button when `location.onboardingPath === 'full_auto_pilot'`.

#### No backend changes needed
The `PATCH /me/locations/:locationId` endpoint already supports `transferPhoneNumber` with E.164 validation.

### How the transfer tool uses this number
The Python agent's `transfer_call` tool reads `transferPhoneNumber` from the agent config response (injected by `/internal/agent-config`). When the location's `transferPhoneNumber` is updated via the PATCH endpoint, the next call session will pick up the new number automatically — no agent restart required.

---

## 3. First Call Celebration Email: Link to Dashboard Instead of Call Detail

### Goal
Change the "View Call Details" CTA button in the first-call celebration email to link to the main dashboard page instead of `/calls/:callRecordId`.

### Current State
- **`~/callsaver-api/src/email/templates/nurture/first-call-celebration.ts:44`**:
  ```ts
  const callDetailsUrl = `${dashboardUrl}/calls/${options.callRecordId}`;
  ```
- The button text is `'View Call Details'` (line 92) and the link goes to `callDetailsUrl` (line 93).

### Changes Required

#### `~/callsaver-api` (1 file)
1. **`src/email/templates/nurture/first-call-celebration.ts`**:
   - Line 44: Change to `const callDetailsUrl = dashboardUrl;` (just the dashboard root).
   - Line 92: Change CTA text from `'View Call Details'` → `'Go to Dashboard'` or `'View Your Dashboard'`.
   - Optionally update the body copy on line 78 from "Check out the full call details" to "Check out your dashboard to see how your AI is performing".

### Risk
None. Cosmetic email change only.

---

## 4. AppointmentsPage: Show Only CallSaver-Booked Events

### Goal
Filter the AppointmentsPage to only show appointments booked by the CallSaver voice agent, not the user's personal calendar events. Also, only show appointments when the user's integration is Google Calendar.

### Current State
- **Frontend (`~/callsaver-frontend/src/pages/AppointmentsPage.tsx`)**: Renders `<CalendarEvents>` component.
- **Frontend (`~/callsaver-frontend/src/hooks/use-calendar-events.ts`)**: Calls `GET /me/calendar/events` which returns **ALL** Google Calendar events — no filtering by source.
- **Backend (`~/callsaver-api/src/server.ts:5412-5665`)**: `GET /me/calendar/events` fetches all events from Google Calendar API with no `sharedExtendedProperty` filter.
- **How CallSaver events are tagged**: When the agent creates an event via `POST /internal/tools/google-calendar-create-event`, it sets `extendedProperties.shared.callerPhoneNumber` on the event. Personal events don't have this property.

### Recommendation: Use Google Calendar API (not Appointment DB records)
**Use Google Calendar as the source of truth** for the AppointmentsPage. Reasons:
- If the user modifies an event on Google Calendar (reschedules, changes location), those changes are immediately reflected.
- The Appointment DB records can become stale (no webhook sync from Google Calendar).
- The `sharedExtendedProperty` filter is a reliable, efficient way to query only CallSaver-created events.
- Avoids building a Google Calendar webhook sync pipeline (complex, unnecessary pre-launch).

The Appointment DB records remain valuable for **analytics/stats** (e.g., "X appointments booked this month") and for historical data even if the Google Calendar integration is disconnected.

### Changes Required

#### `~/callsaver-api` (1 file)
1. **`src/server.ts` — `GET /me/calendar/events`**:
   - Add an optional query parameter `source=callsaver` (default: `'all'`).
   - When `source=callsaver`: add `sharedExtendedProperty: 'callerPhoneNumber'` filter to the Google Calendar API request. This returns only events that have the `callerPhoneNumber` shared property (i.e., events created by CallSaver). Note: Google Calendar API supports filtering by property key existence — passing `callerPhoneNumber` without a `=value` returns all events with that key, regardless of value.
   - **Alternative (simpler)**: Always filter by `callerPhoneNumber` key on the AppointmentsPage endpoint. The existing `by-phone` endpoint already does this for a specific phone. We could add a new endpoint or just a query param.

#### `~/callsaver-frontend` (2 files)
1. **`src/hooks/use-calendar-events.ts`**:
   - When `phoneNumber` is not provided (AppointmentsPage mode), pass `?source=callsaver` query parameter.
2. **`src/pages/AppointmentsPage.tsx`** or **`src/components/calendar-events.tsx`**:
   - Before rendering, check if the user has a Google Calendar integration connected. If not, show a message: "Connect Google Calendar in Settings → Integrations to see appointments here."
   - This requires either passing integration status as a prop or using the `useIntegrations` hook.

### Integration Check
The `useIntegrations` hook returns `connectedIntegration` which has a `type` field (e.g., `'google-calendar'`). The AppointmentsPage should:
- If no integration connected: Show "Connect an integration to view appointments."
- If integration is not google-calendar (e.g., `square-bookings`): Show appointments from that integration's data source (future work) or hide the page.
- If google-calendar is connected: Show filtered CallSaver events.

---

## 5. Remove "Active" Badge from Integration Cards

### Goal
Remove the blue "Active" badge from integration cards on the IntegrationsPage, keeping only the green "Connected" indicator.

### Current State
- **`~/callsaver-frontend/src/components/integrations/integration-card.tsx:70-74`**:
  ```tsx
  {isActive && (
    <div className="flex items-center gap-[0.4rem] px-[0.6rem] py-[0.2rem] bg-blue-600 text-white rounded-md">
      <span className="font-medium text-[0.7rem]">Active</span>
    </div>
  )}
  ```
- The `IntegrationCard` component receives `isActive` prop from `IntegrationsPage.tsx:197`.
- The "Activate Integration" button (lines 108-129) also shows when `isConnected && !isActive`.

### Changes Required

#### `~/callsaver-frontend` (2 files)
1. **`src/components/integrations/integration-card.tsx`**:
   - Remove the `isActive` badge block (lines 70-74).
   - Remove the `isActive` prop from the interface and component params.
   - Remove the "Activate Integration" button block (lines 108-129) — since with single-integration model, connecting IS activating.
   - Optionally remove `isActivating` and `onActivate` props if the activate button is removed.
2. **`src/pages/IntegrationsPage.tsx`**:
   - Remove `isActive` prop from `<IntegrationCard>` (line 196).
   - Remove `isActivating` prop (line 197).
   - Remove `onActivate` prop (line 199).
   - Remove `handleActivate` callback (lines 112-130) and `isActivating` state (line 44) if no longer used.

### Risk
Low. The "Active" concept is redundant with single-integration model. Connected = Active.

---

## 6. Flag as Spam: Business Logic Investigation

### Goal
Verify that the "Flag as Spam" feature is properly implemented end-to-end.

### Current State — Analysis

#### Frontend
- **`~/callsaver-frontend/src/pages/CallersPage.tsx:410-451`**: `handleToggleSpam` calls `POST /me/flag-spam` with `{ callerId, flagged: !currentStatus }`. On success, if flagged, the caller is **removed from the list** in the React Query cache. If unflagged, the caller is updated in-place.
- **`~/callsaver-frontend/src/hooks/use-callers.ts:26-27`**: The `useCallersList` hook **filters out spam callers** from the response before returning, so spam callers are hidden from the CallerPage list.

#### Backend
- **`~/callsaver-api/src/server.ts:1837-1943`**: `POST /me/flag-spam` endpoint:
  - Validates `callerId` or `phoneNumber` is provided.
  - Verifies the caller belongs to the user's organization.
  - Verifies the caller has at least one CallRecord to the organization (security check).
  - Updates `flaggedSpam` boolean on the Caller record.
  - Returns updated caller data.

#### What's Working
1. ✅ Spam flag is toggled correctly on the Caller record.
2. ✅ Flagged callers are hidden from the CallerPage list (filtered client-side).
3. ✅ Organization ownership is validated.
4. ✅ Unflagging works (toggle back to `false`).

#### What's Missing / Potential Issues
1. **No impact on voice agent behavior**: When a flagged-spam caller calls again, the agent still answers and processes the call normally. Consider:
   - Should the agent see a "flagged as spam" note in the caller context?
   - Should we auto-hang-up or provide a short message?
   - **Recommendation for pre-launch**: This is fine as-is. The spam flag is primarily for the dashboard UI (hiding noisy callers). Automated call blocking can be a post-launch feature.
2. **No "Spam" tab or way to view/unflag spam callers**: Once a caller is flagged, they disappear from the list. The only way to unflag them is if you know their caller ID. Consider adding a "Show spam" toggle or a separate spam section.
   - **Recommendation for pre-launch**: Add a small "Show spam callers" toggle or filter at the top of the CallersPage. Low effort, high value for accidental spam flags.
3. **CallerDetailPage still accessible**: If a user navigates directly to `/callers/:id` for a spam-flagged caller, the page still loads. This is fine — it means users can unflag from the detail page if they find the URL.

### Verdict
The feature is **properly implemented** for its current scope. The backend business logic is correct (ownership checks, toggle, persistence). The frontend correctly hides spam callers. Two minor enhancements recommended:
- Add a "Show spam" filter toggle on CallersPage.
- (Post-launch) Consider agent-side behavior for repeat spam callers.

---

## 7. Onboarding Without Integration — Recommendation

### Goal
Decide whether to require integration connection during onboarding or allow users to continue without one.

### Current State
- **`~/callsaver-frontend/src/pages/OnboardingPage.tsx`**: Step 5 (Connect Integrations) allows the user to skip and proceed. The UI says the agent will only answer questions without an integration.
- The agent config (`/internal/agent-config`) generates a system prompt with or without calendar tools. If no Google Calendar is connected, tools like `create_google_calendar_event`, `check_google_calendar_availability`, etc., are not included in the tools list.
- Intake questions are still collected even without an integration (name, address, email, custom questions).

### Recommendation: **Allow skipping, but keep intake questions**

**Rationale for allowing skip:**
1. **Trial friction reduction**: Some users want to hear the agent before connecting their calendar. Forcing integration blocks them.
2. **Legitimate use case**: Small businesses that just want a smart answering service (e.g., after-hours Q&A, callback requests, intake collection). They may never need calendar booking.
3. **Data collection still has value**: Even without booking, collecting caller name, address, and email is valuable business data. The `submit_intake_answers` tool works independently of calendar integration.

**What changes if no integration is connected:**
- The agent can still: answer questions, collect intake data, create callback requests, validate addresses.
- The agent cannot: book/cancel/reschedule appointments, check availability.
- The system prompt already adapts — calendar tool sections are omitted when no calendar is connected.

**What would need to change if we enforce integration:**
- Remove the "skip" option from OnboardingPage Step 5.
- Block the "Complete Setup" button until an integration is connected.
- This risks higher onboarding abandonment.

### Recommendation for intake questions
**Yes, still collect intake questions even without an integration.** The intake flow (name → address → email → custom questions) feeds into the `submit_intake_answers` tool which creates/updates Caller records. This data has standalone value for the business owner's CRM view (CallersPage, CallerDetailPage).

### System prompt generation changes needed
**None.** The `generateSystemPrompt` function in `~/callsaver-api/src/utils.ts` already handles the no-integration case:
- Intake questions are generated regardless of integration.
- Calendar-specific instructions are only included when calendar tools are in the tools list.
- The `getLiveKitToolsForLocation` function already conditionally includes calendar tools based on whether a Nango connection exists.

---

## 8. Callback Request Reason Types — Audit & Recommendations

### Goal
Review the current callback request reason types and determine if they adequately cover real-world scenarios.

### Current Types
From `~/callsaver-api/livekit-python/tools/request_callback.py:88` and `~/callsaver-api/src/services/push-notifications.ts:266-274`:

| Reason Key | Display Label | Auto Priority |
|---|---|---|
| `requested_human` | Requested to speak with a human | normal |
| `frustrated` | Caller frustrated | **high** |
| `complex_issue` | Complex issue | normal |
| `pricing` | Pricing question | normal |
| `billing` | Billing question | normal |
| `complaint` | Complaint | **high** |
| `other` | General inquiry | normal |

### System prompt instructions
In `~/callsaver-api/src/server.ts:8951-8971`, the Path A callback instructions tell the agent:
- Frustrated → `"frustrated"`
- Discount/pricing → `"pricing"`
- Dispute/complaint → `"complaint"`
- Speak to human → `"requested_human"`
- Unable to fulfill request → `"complex_issue"`
- Billing questions → `"billing"`

### Issue Identified
The user reported that a **failed reschedule** triggered `"complex_issue"`. This is technically correct — the agent couldn't fulfill the request, so it categorized it as a complex issue. But from the business owner's perspective, knowing it was specifically a **reschedule failure** is more actionable.

### Proposed New Types

| Reason Key | Display Label | Auto Priority | When to Use |
|---|---|---|---|
| `requested_human` | Requested human | normal | Caller explicitly asks for a person |
| `frustrated` | Caller frustrated | **high** | Caller is upset/angry |
| `complaint` | Complaint | **high** | Dispute or dissatisfaction |
| `pricing` | Pricing question | normal | Discount/pricing negotiation |
| `billing` | Billing question | normal | Billing dispute or question |
| `scheduling_issue` | Scheduling issue | normal | **NEW** — Failed to book/reschedule/cancel, no availability, calendar errors |
| `service_question` | Service question | normal | **NEW** — Detailed service question agent can't answer |
| `other` | Other | normal | Catch-all |

**Removed**: `complex_issue` — too vague. Replaced by more specific types (`scheduling_issue`, `service_question`).

### Changes Required

#### `~/callsaver-api` (3 locations)
1. **`src/services/push-notifications.ts:266-274`** — Update `formatCallbackReason` map with new types, remove `complex_issue`.
2. **`src/server.ts:8951-8971`** — Update the callback instructions in the system prompt to reference new reason types.
3. **`src/contracts/callback-requests.contract.ts:23`** — Update the `reason` field description.

#### `~/callsaver-api/livekit-python` (1 file)
4. **`tools/request_callback.py:47-53`** — Update the `reason` arg docstring with new enum values.
5. **`tools/request_callback.py:88`** — Update `valid_reasons` list.

#### Backward compatibility
- Existing callback requests with `complex_issue` remain in the DB as-is.
- The `formatCallbackReason` function should keep a fallback for `complex_issue` → `"Complex issue"` for old records.
- The Python tool should map `complex_issue` → `other` if the LLM still sends it (unlikely after prompt update).

---

## 9. Service-Specific Appointment Durations

### Goal
Decide whether to support per-service appointment durations before launch.

### Current State
- **Prisma (`Location.settings`)**: Stores `appointmentSettings: { defaultMinutes: 60, bufferMinutes: 0 }` as a single JSON object.
- **System prompt**: References `defaultAppointmentMinutes` and `bufferMinutes` as single values.
- **Agent behavior**: When booking, the agent uses `defaultMinutes` for all appointment types.

### Recommendation: **Do NOT build this for launch. Plan the data model now.**

**Rationale:**
1. **Pre-revenue, pre-launch** — Adding per-service durations increases complexity in the settings UI, system prompt, and booking logic.
2. **Most home service businesses** (your primary market) have a single standard appointment slot (e.g., 60 min for an initial visit). Variations are rare enough to handle manually.
3. **No customer has requested this yet.** Build when there's demand.

### Future Implementation Plan (when needed)

#### Data Model — Service Duration Overrides
Add a `serviceDurations` field to the Location model:

```prisma
model Location {
  // ... existing fields ...
  serviceDurations Json? @map("service_durations")
  // Schema: Array<{ service: string; durationMinutes: number; bufferMinutes?: number }>
}
```

This is a **sparse override** approach:
- Only services with non-default durations need entries.
- Services not in the list use `appointmentSettings.defaultMinutes`.
- Example:
  ```json
  [
    { "service": "Full HVAC Installation", "durationMinutes": 180, "bufferMinutes": 30 },
    { "service": "AC Tune-Up", "durationMinutes": 45 }
  ]
  ```

#### Frontend UI
In LocationsPage settings, under the "Appointment Settings" section:
- Show the default duration (existing).
- Add an expandable "Service-Specific Durations" section.
- List the location's services with an optional duration override input next to each.
- Only services with explicit overrides get stored; others inherit the default.

#### System Prompt Changes
- The prompt would list service-specific durations alongside the service list.
- The agent would use the override when the caller specifies a matching service, falling back to the default otherwise.

---

## 10. System Prompt Generation Without S3 Business Profile

### Goal
Verify that the system prompt generates correctly when only Google Place Details are available (no S3 website extraction data).

### Current State — Analysis

The `generateSystemPrompt` function in `~/callsaver-api/src/utils.ts:1057-1826` receives a `profile` parameter (the S3 business profile) and many `location*` options.

#### What comes from S3 profile (the `profile` parameter):
- `profile.summary` → Business summary (line 1411)
- `profile.diagnostic_fee_policy` → Diagnostic fee policy (line 1509)
- `profile.financing_info` → Financing info (line 1510)
- `profile.value_propositions` → Why Choose Us section (line 1440)
- `profile.trust_and_guarantees` → Trust & Credentials section (line 1441)
- `profile.property_types_served` → Property types (line 1442)

#### What comes from Location model (NOT S3):
- `locationServices` → Services list (from `location.services`)
- `locationServiceAreas` → Areas served (from `location.serviceAreas`)
- `locationBrandsServiced` → Brands (from `location.brandsServiced`)
- `locationDiscountsAndPromotions` → Promotions (from `location.discountsAndPromotions`)
- `locationFrequentlyAskedQuestions` → FAQs (from `location.frequentlyAskedQuestions`)
- `locationEstimatePolicyText` → Estimate policy (from `location.estimatePolicyText`)
- `locationIntakeQuestions` → Intake flow (from `location.intakeQuestions`)

#### What comes from Google Place Details:
- `googlePlaceDetails.hours` → Business hours (line 1414)
- `googlePlaceDetails.business.paymentOptions` → Payment methods (line 1427)

### Is it already resilient?

**Yes.** The function handles missing S3 profile gracefully:

1. **`profile` can be `null`/`undefined`**: Line 1411 uses `profile?.summary?.trim() || ""` — safe.
2. **V3 fields all use optional chaining**: `Array.isArray(profile?.value_propositions)` — returns `false` if profile is null.
3. **Location model fields are the canonical source**: Services, areas, brands, promotions, FAQs, estimate policy all come from the Location model (populated during provisioning from S3, but editable by user). If S3 is unavailable, these fields can still be set via the settings UI.
4. **Google Place Details provides hours and payment**: These are fetched during provisioning independently of S3.

### What happens with NO S3 profile:
- Business summary: omitted (empty string).
- Diagnostic fee / financing: omitted.
- Value propositions: omitted.
- Trust & credentials: omitted.
- Property types: omitted.
- **Everything else works**: Services, areas, brands, promotions, FAQs, intake questions, hours, payment methods all come from Location model or Google Place Details.

### Verdict
**The system prompt generation is already equipped to work without S3 data.** The prompt will be less detailed (no summary, no trust credentials, no value propositions), but fully functional. The agent will still know the business name, hours, services, service areas, intake flow, and calendar instructions.

### Minor Improvement (optional)
If `profile?.summary` is empty and Google Place Details has a `generativeSummary`, we could fall back to that. This is already partially handled — the `generativeSummary` is extracted in provisioning and could be stored on the Location model as a fallback.

---

## Implementation Priority

| # | Item | Effort | Priority | Pre-Launch? |
|---|---|---|---|---|
| 1 | Default voice → Ray | 30 min | Medium | ✅ Yes |
| 2 | Transfer number edit modal | 2-3 hrs | High | ✅ Yes |
| 3 | First call email → dashboard link | 10 min | Low | ✅ Yes |
| 4 | AppointmentsPage filter by source | 1-2 hrs | High | ✅ Yes |
| 5 | Remove Active badge | 15 min | Low | ✅ Yes |
| 6 | Flag as Spam audit | N/A (verified) | — | ✅ Done (add spam filter toggle post-launch) |
| 7 | Onboarding without integration | N/A (keep as-is) | — | ✅ No changes needed |
| 8 | Callback reason types | 1 hr | Medium | ✅ Yes |
| 9 | Per-service durations | N/A (deferred) | Low | ❌ Post-launch |
| 10 | Prompt without S3 data | N/A (already works) | — | ✅ No changes needed |

**Total estimated effort for pre-launch items: ~5-6 hours**
