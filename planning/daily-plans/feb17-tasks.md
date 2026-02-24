# Feb 17 — Integration Testing & Launch Prep

**Date**: Feb 17, 2026  
**Goal**: Complete integration testing for all 4 launch integrations, frontend HCP API key flow, and landing page cleanup.

---

## Phase 0: Frontend Bug Fix — Integrations Page Refresh ✅

**Bug**: After connecting a new integration via Nango OAuth, the integrations page doesn't update to show the new connection. User has to manually refresh.

**Root cause**: `useIntegrations` hook sets `isLoading = true` on every `refetch()`, which causes the page to render the skeleton loader, unmounting the dialog and disrupting the state update. By the time the fetch completes and `isLoading` goes back to `false`, the component tree has been torn down and rebuilt, losing the connection between the success callback and the UI update.

**Fix**: Use a `useRef` (`hasFetchedOnce`) to track whether the initial fetch has completed. On subsequent `refetch()` calls (e.g., after connecting), skip `setIsLoading(true)` so the page stays rendered and the new integration data flows in seamlessly via `setIntegrations()`.

**File**: `~/callsaver-frontend/src/hooks/use-integrations.ts`

---

## Phase 1: Jobber Voice Agent Testing ✅ (wiring done)

All 20 fs-* tools are wired into the LiveKit agent. Agent config confirmed returning 23 tools for the test location.

### Known Issue: Business Hours Hardcoded
`JobberAdapter.checkAvailability()` hardcodes business hours to 8 AM – 5 PM (lines 2727-2728) instead of pulling from `Location.googlePlaceDetails.hours.regularOpeningHours`. This should be fixed before launch but is acceptable for testing.

### Steps
1. **Restart API server + LiveKit Python agent** to pick up new tool files

#### Assessment Scheduling Mode Toggle

The agent's behavior for new-caller assessments is controlled by `autoScheduleAssessment` on the agent's config (not by what the caller says):
- **OFF (default)**: Agent creates unscheduled assessment → team follows up to schedule
- **ON**: Agent checks availability, presents slots, schedules the assessment on the call

Toggle via API:
```bash
# Set to UNSCHEDULED mode (default)
curl -s -X POST "http://localhost:3002/internal/toggle-auto-schedule-assessment" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7" \
  -d '{"locationId":"cmloxy8vs000ar801ma3wz6s3","enabled":false}'

# Set to AUTO-SCHEDULE mode
curl -s -X POST "http://localhost:3002/internal/toggle-auto-schedule-assessment" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7" \
  -d '{"locationId":"cmloxy8vs000ar801ma3wz6s3","enabled":true}'
```

#### Pre-flight: Check Service Catalog
Before running tests, check what services exist in Jobber:
```bash
curl -s -X POST "http://localhost:3002/internal/tools/fs/get-services" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ef0f9e9513a20638fb1841e5080f4a0621629958fa8e040d9a2517c2612950f7" \
  -d '{"locationId":"cmloxy8vs000ar801ma3wz6s3","callerPhoneNumber":"+18313345344"}' | jq '.message'
```
Adjust the "what to say" prompts below based on the actual services listed.

#### Scenario 1 — New Caller (4 sub-tests)
Delete the Jobber client after each sub-test to reset.

**1.1 — Exact service match + UNSCHEDULED mode**
- Toggle: `autoScheduleAssessment = false`
- Call and say: "Hi, I need a **furnace tune-up**" *(use an exact service name from the catalog)*
- Agent should: `fs-get-customer-by-phone` → not found → `fs-get-services` → exact match → collect name, address → `fs-submit-lead` → `fs-create-assessment` (no start_time)
- Agent should say something like: "I've submitted your request and our team will reach out to schedule a time for the assessment."
- Agent should NOT ask about scheduling or availability.
- **Verify in Jobber**: Client + Property + Request + **unscheduled** Assessment.
- Delete client in Jobber.

**1.2 — Service NOT offered (agent should redirect)**
- Toggle: `autoScheduleAssessment = false` (same as 1.1)
- Call and say: "I need someone to **clean my pool**"
- Agent should: `fs-get-customer-by-phone` → not found → `fs-get-services` → no pool service
- Agent should explain that pool cleaning isn't offered and list available services.
- **Verify**: Agent does NOT create a request for pool cleaning.
- Then say: "OK, how about **[a real service from the list]**?" → agent proceeds with intake.
- Delete client in Jobber.

**1.3 — Fuzzy service match + UNSCHEDULED mode**
- Toggle: `autoScheduleAssessment = false` (same)
- Call and say: "I think there's something wrong with my **AC, it's blowing warm air**"
- Agent should: `fs-get-services` → fuzzy match to HVAC/AC service → confirm ("It sounds like you need our [AC Repair]. Is that right?")
- After confirmation → collect name + address → `fs-submit-lead` → `fs-create-assessment` (unscheduled)
- Agent should NOT ask about scheduling.
- **Verify in Jobber**: Client + Property + Request + **unscheduled** Assessment. Request references the catalog service name.
- Delete client in Jobber.

**1.4 — Exact match + AUTO-SCHEDULE mode (with availability check)**
- Toggle: `autoScheduleAssessment = true`
- **Pre-seed the calendar**:
  ```bash
  LOCATION_ID=cmloxy8vs000ar801ma3wz6s3 ./testing/setup-voice-scenario.sh seed-busy-schedule
  ```
  Expected gaps: Day +1 (10-11, 12-2, 4-5), Day +2 (11-1 only), Day +3 (12-1 only).
- Call and say: "I need a **plumbing inspection**, can you come out this week?"
- Agent should: `fs-get-services` → match → collect info → `fs-submit-lead` → `fs-check-availability` → present 2-3 slots → you pick one → `fs-create-assessment` with start_time
- **Verify in Jobber**: Client + Property + Request + **scheduled** Assessment at the correct time.
- **Verify**: Time is within business hours, doesn't conflict with pre-seeded items.
- Delete both clients (test + dummy +15550001234).

#### Scenario 2 — Returning Caller
2. Run `setup-voice-scenario.sh returning-caller`. Call and verify agent greets by name, finds open request.

#### Scenario 3 — Has Appointment
3. Run `setup-voice-scenario.sh has-appointment`. Call and test "When is my appointment?", reschedule, cancel flows.

#### Scenario 4 — Has Estimate
4. Run `setup-voice-scenario.sh has-estimate`. Call and test "Did you send me a quote?" flow.

#### Scenario 5 — Billing Inquiry
5. Run `setup-voice-scenario.sh has-invoice`. Call and test "What do I owe?" flow.

#### Wrap-up
6. **Fix any bugs** found during live testing — iterate until all scenarios pass.

---

## Phase 2: Housecall Pro Adapter Testing

HCP uses API keys (not Nango OAuth) until we become official partners. The `FieldServiceAdapterRegistry` already supports both auth methods.

### Steps
1. **Get HCP API key** — Sign up for Max plan ($99/mo) or use sandbox if available.
2. **Create OrganizationIntegration record** for the test location with the HCP API key.
3. **Run `test-fs-endpoints.sh`** against HCP adapter — same 34 endpoints, different platform.
4. **Wire HCP into `getLiveKitToolsForLocation`** — same 20 fs-* tool names (they're platform-agnostic, the adapter resolves dynamically).
5. **Live voice test** through the same scenarios as Jobber (new caller, returning, appointment, estimate, billing).
6. **Fix any HCP-specific bugs** — different GraphQL/REST quirks vs Jobber.

---

## Phase 3: Google Calendar Re-Testing

Google Calendar is already integrated and working. This is a regression/confidence pass.

### Steps
1. **Switch active integration** to `google-calendar` for the test location.
2. **Verify agent config** returns only Google Calendar tools (5 tools) + base tools.
3. **Live voice test**:
   - "When are you available?" → `google-calendar-check-availability`
   - "Schedule me for Thursday at 2pm" → `google-calendar-create-event`
   - "Cancel my appointment" → `google-calendar-cancel-event`
   - "Move it to Friday" → `google-calendar-update-event`
   - "What's on my calendar?" → `google-calendar-list-events`
4. **Confirm no regressions** from the fs-* tool additions.

---

## Phase 4: Square Bookings Integration

Square Bookings is a scheduling platform (not full FSM like Jobber/HCP). Similar scope to Google Calendar — availability + booking.

### Steps
1. **Audit existing Square Bookings adapter** — check what's implemented vs archived.
2. **Create/update Square Bookings tools** — likely a small set:
   - `square-check-availability`
   - `square-create-booking`
   - `square-cancel-booking`
   - `square-reschedule-booking`
   - `square-list-bookings`
   - `square-get-services` (catalog)
3. **Wire into `getLiveKitToolsForLocation`** — update the `case 'square-bookings':` block.
4. **Create Python tool wrappers** in `livekit-python/tools/`.
5. **Test with Square sandbox** — endpoint tests + live voice calls.

---

## Phase 5: HCP API Key Frontend Flow

Since HCP uses API keys (not OAuth), we need a frontend modal for users to enter their key securely.

### Steps
1. **Backend endpoint**: `POST /me/integrations/housecall-pro/api-key` — accepts API key, creates `OrganizationIntegration` record, validates key by making a test API call.
2. **Frontend modal**: On the Integrations page, HCP card shows "Connect" → opens modal with:
   - Text input for API key (masked/password field)
   - Link to HCP docs on where to find the key
   - "Test & Save" button that validates before saving
   - Success/error feedback
3. **Disconnect flow**: "Disconnect" button that removes the API key.
4. **Security**: API key stored encrypted in `OrganizationIntegration.encryptedApiKey` (not plain text). Never returned to frontend after save.
5. **Migration plan note**: When we become official HCP partners, transition to Nango OAuth. The `FieldServiceAdapterRegistry` already supports both — just swap the auth source.

---

## Phase 6: Landing Page & Website Cleanup

Temporarily remove integrations that aren't fully integrated. Official launch set:

### Supported Integrations (launch)
- **Google Calendar** — scheduling
- **Jobber** — full FSM
- **Housecall Pro** — full FSM
- **Square Bookings** — scheduling

### Coming Soon
- **ServiceTitan** — full FSM (coming soon badge)

### Steps
1. **Identify all integration references** on the landing page and marketing site.
2. **Remove/hide**: Acuity, Calendly, or any other integrations not in the launch set.
3. **Update integration grid/carousel** to show only the 4 supported + ServiceTitan (coming soon).
4. **Update any "X+ integrations" copy** to reflect the actual count.
5. **Add "Coming Soon" badge** styling for ServiceTitan.
6. **Test responsive layout** with the reduced set.

---

## Phase 7: Landing Page Background Video

Purchase stock video footage from Storyblocks and create a new background video for the landing page hero section (desktop only).

### Steps
1. **Browse Storyblocks** for relevant stock footage (home services, AI/tech, phone calls, etc.)
2. **Purchase and download** selected clips
3. **Edit/composite** into a looping background video suitable for the hero section
4. **Optimize** for web (compress, appropriate resolution, short loop)
5. **Replace** the current background video asset in the website/landing page

---

## Phase 8: Frontend TypeScript Config Audit

Re-enable strict TypeScript rules that were previously disabled. Need to review `tsconfig.json` in `~/callsaver-frontend`.

### Steps
1. **Check current tsconfig** — look for disabled rules like `noUnusedLocals`, `noUnusedParameters`, and any other relaxed strict settings
2. **Re-enable** `noUnusedLocals` and `noUnusedParameters` (or equivalent)
3. **Fix all resulting compile errors** — remove unused imports, variables, and parameters across the codebase
4. **Verify build passes** with the stricter config

---

## Execution Order

| Priority | Phase | Est. Time | Status |
|----------|-------|-----------|--------|
| 0 | Integrations page refresh fix | 10 min | ✅ Done |
| 1 | Jobber voice testing | 1-2 hrs | 🟡 Ready to test |
| 2 | HCP adapter testing | 2-3 hrs | ⬜ Blocked on API key |
| 3 | Google Calendar re-test | 30 min | ⬜ Pending |
| 4 | Square Bookings integration | 2-3 hrs | ⬜ Pending |
| 5 | HCP API key frontend | 2-3 hrs | ⬜ Pending |
| 6 | Landing page cleanup | 1-2 hrs | ⬜ Pending |
| 7 | Landing page background video | 1-2 hrs | ⬜ Pending (Storyblocks) |
| 8 | Frontend TS config audit | 30-60 min | ⬜ Pending |

**Total estimated**: 9-14 hours (multi-session)

---

## Notes
- HCP testing is blocked on getting an API key ($99/mo Max plan). If we can't get it tonight, defer to tomorrow.
- Square Bookings may require a Square developer account / sandbox setup.
- All fs-* Python tools share the same `fs_helpers.py` pattern — adding new platforms requires zero Python changes (the adapter resolves server-side).
- The `setup-voice-scenario.sh` script works for any platform since it calls the unified `/internal/tools/fs/*` endpoints.
