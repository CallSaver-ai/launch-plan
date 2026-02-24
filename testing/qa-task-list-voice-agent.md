# Voice Agent & Web App QA Test List

> Created: Feb 16, 2026  
> Scope: End-to-end validation of voice agent behavior and web app configuration propagation

---

## Infrastructure & Logging

| # | Test Item | Status | Notes |
|---|-----------|--------|-------|
| 1 | **LiveKit Egress to S3** | 🟡 IN PROGRESS | ✅ Audio correctly streams to `callsaver-sessions-{env}` bucket (verified: file exists). **PENDING**: CORS configuration needed for web app playback. Current error: "No 'Access-Control-Allow-Origin' header" when fetching from `staging.app.callsaver.ai`. **AD-HOC FIX (Applied manually — NOT in CDK yet)**: Apply CORS via AWS CLI to both buckets. Save the following as `cors.json`: `{"CORSRules": [{"AllowedOrigins": ["https://*.callsaver.ai"], "AllowedMethods": ["GET", "HEAD"], "AllowedHeaders": ["*"], "MaxAgeSeconds": 3600}]}` then run: `aws s3api put-bucket-cors --bucket callsaver-sessions-staging --cors-configuration file://cors.json` and `aws s3api put-bucket-cors --bucket callsaver-sessions-production --cors-configuration file://cors.json`. Verify with: `aws s3api get-bucket-cors --bucket callsaver-sessions-staging`. Using wildcard `*.callsaver.ai` covers all subdomains: `staging.app`, `app`, `staging.api`, `api`. CORS does not weaken `blockPublicAccess` — it only adds response headers on cross-origin requests to resources the requester already has access to (via presigned URLs). **⚠️ CDK FOLLOW-UP REQUIRED**: The ad-hoc CLI change will be **overwritten** on next CDK deploy of the Storage stack because CDK manages this bucket. Must add `cors` property to the `s3.Bucket` constructor in `infra/cdk/lib/storage-stack.ts:39-52` before next CDK deploy: `cors: [{ allowedOrigins: ['https://*.callsaver.ai'], allowedMethods: [s3.HttpMethods.GET, s3.HttpMethods.HEAD], allowedHeaders: ['*'], maxAge: 3600 }]`. |

---

## Dashboard & Analytics

| # | Test Item | Status | Notes |
|---|-----------|--------|-------|
| 2 | **Appointments Booked Statistic** | 🔴 ACTIVE BUG | Dashboard shows "0" after voice agent books Google Calendar appointment. **ROOT CAUSE**: The `/me/stats` endpoint (`server.ts:4713-4728`) counts `prisma.appointment.count()` — querying the `Appointment` model in the database. But the `google-calendar-create-event` endpoint (`server.ts:10582-11005`) only creates a Google Calendar event via the API and **NEVER creates an `Appointment` record** in the database. There is no `prisma.appointment.create()` call anywhere in the create-event flow. The `Appointment` model (`prisma/schema.prisma:138-160`) has fields like `customerName`, `customerPhone`, `address`, `date`, `time`, `service`, `description`, `urgency`, `locationId`, `callRecordId`, `externalId`, `platform` — all the data needed is available in the create-event endpoint. **FIX**: After successfully creating the Google Calendar event (`server.ts:10975`), add a `prisma.appointment.create()` call to persist the appointment in the database. Map fields: `customerName` from `summary`, `customerPhone` from `callerPhoneNumber`, `address` from `eventLocation`, `date` from `startDateTime`, `time` from formatted start time, `service` from `summary`, `description` from `description`, `urgency` = 'normal', `locationId`, `callRecordId` from the call record lookup, `externalId` = Google Calendar `eventId`, `platform` = 'google-calendar', `status` = 'scheduled'. Wrap in try/catch so a DB failure doesn't break the calendar event creation. Also need to create Appointment records when events are created via future booking adapters (Jobber, Square, etc.). |

---

## Voice Agent Tools & Data Collection

| # | Test Item | Status | Notes |
|---|-----------|--------|-------|
| 3 | **submit_intake_answers Tool Failure** | ⬜ TODO | Tool call is failing. Check LiveKit agent logs for error details. Verify endpoint `/api/internal/submit-intake` is reachable from agent. Check payload structure matches expected schema. |
| 4 | **Required Intake: Caller Name** | � CODE COMPLETE | Agent skips name question even though it's first in intake questions array. **ROOT CAUSE**: Returning caller logic in `src/utils.ts:1224-1227` skips name if `isReturningCaller === true` AND `callerName` is truthy. Problem: `isReturningCaller` is set just by finding a `CallerProfile` record, even if name is missing/invalid (e.g., phone number stored as name, or caller hung up before providing name). **FIX**: Change skip condition to only skip if name actually exists and is valid. Replace `if (q.type === 'name' && isReturningCaller && callerName)` with `if (q.type === 'name' && callerName && callerName.length >= 2)`. This ensures we always ask for name if it doesn't exist, regardless of returning caller status. Keep it simple - no complex validation needed. |

---

## Web App UI / Voice Agent Integration

| # | Test Item | Status | Notes |
|---|-----------|--------|-------|
| 5 | **Call Transcript Scrollable Container** | ⬜ TODO | Transcript stretches infinitely. Wrap in container with `max-height` and `overflow-y: auto`. Check component at `src/components/call-transcript/` or similar. |
| 6 | **First Call Email Timestamp** | � CODE COMPLETE | Email shows 10:54 AM instead of 2:54 PM (8 hours off = UTC displayed as local). **ROOT CAUSE**: `first-call-celebration.ts:46-53` uses `toLocaleString('en-US', {...})` with NO `timeZone` option — defaults to server timezone (UTC on ECS). The `callTime` Date object is correct (UTC), but formatting doesn't convert to location timezone. **FIX**: Pass `location.timezone` through the job data (`FirstCallEmailJobData` in `queues.ts:1370`) and add `timeZone: locationTimezone` to the `toLocaleString` options. Currently `callTime` is queued at `server.ts:9406` from `updatedCallRecord.startedAt` but no timezone is passed. Need: (1) Add `timezone` field to `FirstCallEmailJobData`, (2) Pass `location.timezone` when queuing at `server.ts:9399`, (3) Use it in `first-call-celebration.ts:46`: `options.callTime.toLocaleString('en-US', { timeZone: options.timezone, ... })`. |
| 7 | **Appointment Timezone Handling** | � CODE COMPLETE | 3 PM Pacific booked as 11 PM (8 hours off = UTC). **ROOT CAUSE**: The LLM generates `startDateTime` in ISO 8601 format (e.g., `2026-02-16T15:00:00Z`) — the `Z` suffix means UTC. The create-event tool description says "ISO 8601 format (e.g., 2025-11-06T10:00:00Z)" which encourages the LLM to use UTC `Z` suffix. The backend at `server.ts:10620` does `const tz = timeZone \|\| location.timezone \|\| 'UTC'` and has `formatDateTimeWithTimezone()` but this only applies to bare datetime strings without offset — if the LLM sends `Z` suffix, it's treated as UTC. **FIX**: Two-pronged: (1) Update tool description to say "use timezone offset, not Z" (e.g., `2025-11-06T10:00:00-08:00`), (2) In system prompt, explicitly tell agent to use the location timezone offset when constructing datetime params for calendar tools. Also consider server-side fix: if datetime has `Z` suffix but `timeZone` param is set, re-interpret as local time in that timezone. |
| 8 | **Background Noise Toggle** | ⬜ TODO | Toggle in Location settings should enable/disable background noise track. Verify toggle saves to DB (`Location.backgroundNoiseEnabled`), and agent reads this setting on session start to mix audio track. |
| 9 | **Intake Question Ordering** | ⬜ TODO | Re-ordering questions in web UI should reflect in agent's question sequence. **HOW IT WORKS**: (1) UI updates `location.intakeQuestions` array order in DB, (2) `regenerateAgentPrompt()` called automatically (`server.ts:4178`), (3) `generateIntakeSteps()` iterates array in order (`utils.ts:1223`), building "Step 1", "Step 2", etc., (4) New prompt stored in `agent.systemPrompt`. **CRITICAL**: Agent must fetch fresh prompt on next call - if Python agent caches prompt or doesn't reload between calls, reordering won't take effect until agent restart. **Test**: (1) Reorder questions in UI, (2) Verify DB update + prompt regeneration in logs, (3) Make test call immediately (no restart), (4) Confirm agent asks in new order. |
| 10 | **Service Availability Filtering** | ⬜ TODO | Agent should decline services not in `Location.services` (preset + custom). Test: (a) Remove "Teeth Whitening" from UI, ask agent to book it—should decline. (b) Add custom service "Invisalign Consult", verify agent recognizes it. |
| 11 | **Service Area Validation (Counties & Cities)** | � CODE COMPLETE | Agent relies on LLM knowledge to determine which cities belong to a county — prone to errors. **ROOT CAUSE**: `location.serviceAreas` is a `string[]` like `["San Diego", "San Diego County"]`. These are passed as `locationServiceAreas` to `generateSystemPrompt()` (`utils.ts:1066,1089`), formatted via `formatList()` (`utils.ts:1354`), and injected verbatim into the `AREAS SERVED` section (`utils.ts:1562-1563`). The prompt tells the agent to "check if the city is in the business's service areas" but when a county like "San Diego County" is listed, the LLM must guess which cities belong to it. **FIX**: Expand counties to explicit city lists at prompt generation time. See item 23 for implementation details. |
| 12 | **Service Area Rejection Behavior Modes** | ⬜ TODO | Two modes: (a) Hard reject—decline booking entirely, (b) Soft reject—allow booking but continue collecting info. Verify both pathways work based on `Location.serviceAreaRejectionMode` setting. |
| 13 | **Appointment Duration & Buffer Time** | � CODE COMPLETE | **HOW IT'S STORED**: Appointment settings live in `location.settings` (JSON field) under two inconsistent keys: (a) `settings.appointmentSettings.defaultMinutes` / `bufferMinutes` — written by the general location update endpoint (`server.ts:4099-4114`), (b) `settings.appointmentDuration.defaultMinutes` / `bufferMinutes` — written by the dedicated `PATCH /me/locations/:locationId/appointment-duration` endpoint (`server.ts:4359-4385`). The reader `getDefaultAppointmentDuration()` (`server.ts:10557-10562`) only checks `settings.appointmentDuration.defaultMinutes` (key b), so settings saved via the general endpoint (key a) are IGNORED. **DURATION STATUS**: ✅ Partially working. The create-event backend (`server.ts:10656-10668`) uses `getDefaultAppointmentDuration()` as fallback when LLM doesn't provide `endDateTime` or `durationMinutes`. The prompt (`utils.ts:1600-1612`) tells the agent the default duration. But the LLM always sends explicit `endDateTime` (required param in tool), so the fallback rarely triggers. **BUFFER STATUS**: ❌ Not implemented. Buffer time (`bufferMinutes`) is stored but NEVER read or applied anywhere. Neither the check-availability endpoint (`server.ts:10395-10550`) nor the create-event endpoint applies buffer time. The check-availability endpoint passes the exact `startDateTime`/`endDateTime` from the LLM to Google's freeBusy API with no buffer padding. **FIX**: (1) Fix key inconsistency: update `getDefaultAppointmentDuration()` to check BOTH `settings.appointmentDuration` and `settings.appointmentSettings`, (2) Add `getBufferMinutes(location)` helper, (3) In check-availability endpoint, expand the freeBusy query window by `bufferMinutes` on each side (e.g., if buffer=15min and checking 2-3pm, query 1:45-3:15pm), (4) In create-event endpoint, validate that the new event doesn't overlap with existing events + buffer, (5) Inject buffer info into prompt so agent knows to space appointments. **FUTURE-PROOFING**: For Jobber and other booking tools, the buffer/duration logic should be in a shared utility, not hardcoded in the Google Calendar endpoint. Create `src/utils/appointment-settings.ts` with `getAppointmentDuration(location)` and `getBufferMinutes(location)` that all booking adapters can use. |

---

## Call Transfer & Callback Flows

| # | Test Item | Status | Notes |
|---|-----------|--------|-------|
| 14 | **Call Transfer Number** | ⬜ TODO | (a) Verify agent can transfer to number set during onboarding. (b) **Feature gap**: Allow updating transfer number outside onboarding flow—add UI in Location Settings → Transfer Number field with save action. |
| 15 | **Callback Request Logging** | ⬜ TODO | When transfers disabled (`allowTransfers: false`), agent should create `CallbackRequest` record. Verify: (a) record saved to DB with caller info, (b) appears in web app UI callback requests list, (c) status tracking (pending, completed). |

---

## Knowledge Base & Prompt Behavior

| # | Test Item | Status | Notes |
|---|-----------|--------|-------|
| 16 | **FAQ Awareness** | ⬜ TODO | Agent should answer FAQ questions configured in UI (`Location.faqs` array with question/answer pairs). Test common questions: "What are your hours?", "Do you take insurance?" Verify agent responds with configured answers, not hallucinated. |
| 17 | **Promotions Awareness** | ⬜ TODO | Agent should mention active promotions from `Location.promotions` (code, description, valid dates). Test: "Do you have any current deals?" Agent should mention valid promotions. |
| 18 | **Silence Detection & "Are You Still There?"** | � CODE COMPLETE | After 7 seconds silence, agent prompts "Are you still there?" correctly. **BUG**: After final silence prompt, agent says it's hanging up and LEAVES the LiveKit room, but the phone call itself is NOT terminated. Caller can still speak but gets no response. **SOLUTION**: Per LiveKit docs, to end a call for all participants, use `delete_room` API. If only the agent session ends, user continues hearing silence. Implement: `await api.room.delete_room(api.DeleteRoomRequest(room=room_name))` after goodbye message. |
| 19 | **Maximum Call Duration** | ⬜ TODO | Set `Location.maxCallDurationMinutes` to short value (e.g., 2 min) for testing. Verify agent ends call gracefully at limit with reason `max_duration_reached`. Increase to production value (e.g., 10 min) after test passes. |
| 20 | **End Call Reason Tracking** | ⬜ TODO | Ensure `CallSession.endReason` is correctly set for all scenarios: `transferred`, `caller_hung_up`, `agent_hung_up`, `silence_timeout`, `max_duration_reached`, `booking_completed`, `callback_requested`. Check call log UI displays these correctly. |
| 21 | **Address Confirmation Phrasing** | � CODE COMPLETE | Agent says "does that LOOK good to you?" after validating address — inappropriate for a phone call (no visuals). Prompt says "Does that sound correct to you?" (`utils.ts:1143,1202`) and tool response says "Please confirm this address is correct" (`server.ts:9720-9726`), so prompt engineering is fine. **ROOT CAUSE**: LLM is paraphrasing rather than using the suggested phrasing. **FIX**: Strengthen the prompt instruction at `utils.ts:1181` to add: `- **IMPORTANT - PHONE CALL CONTEXT**: You are on a PHONE CALL. Never use visual language like "look", "see", or "view" when asking for confirmation. Always use audio-appropriate language: "Does that sound right?", "Does that sound correct?", "Is that right?"` |
| 23 | **County-to-City Expansion in Service Areas** | � CODE COMPLETE | When `location.serviceAreas` contains county entries (e.g., "San Diego County"), expand them to explicit city lists in the prompt so the LLM doesn't have to guess. **IMPLEMENTATION**: In `generateSystemPrompt()` (`utils.ts`), before the `AREAS SERVED` section is built at line 1354, process `locationServiceAreas` to detect county entries (suffix " County"), strip the suffix, call `getCitiesByCounty()` from `@mardillu/us-cities-utils` (already installed, `package.json:105`), and replace the county entry with the list of city names. **Detailed steps**: (1) Import `getCitiesByCounty` in `utils.ts` (already imported as `getCities` in `server.ts:44` — need to also import `getCitiesByCounty`), (2) Add a helper function `expandServiceAreasWithCities(areas: string[]): string` that iterates `locationServiceAreas`, detects entries ending in " County", calls `getCitiesByCounty(countyName)` to get `UsCity[]`, extracts `.name` from each, deduplicates, and builds a formatted string like: `Cities: San Diego, Chula Vista, Oceanside, ... (San Diego County)\nCities: Los Angeles, Long Beach, ... (Los Angeles County)\nSan Jose` (non-county entries pass through as-is), (3) Replace `const areas = formatList(locationServiceAreas)` at line 1354 with `const areas = expandServiceAreasWithCities(locationServiceAreas)`, (4) The `AREAS SERVED` section at line 1562 already uses `${areas}` so no template change needed. **IMPORTANT**: Keep `location.serviceAreas` in DB unchanged (still stores "San Diego County") — expansion is prompt-generation-time only. Frontend/backend service area selection logic stays as-is. **Prompt regeneration**: `regenerateAgentPrompt()` and `setupLocationPrompt()` both pass `locationServiceAreas` to `generateSystemPrompt()`, so the expansion will automatically apply when prompts are regenerated. **Edge cases**: (1) If `getCitiesByCounty()` returns empty for an unrecognized county, fall back to the original county string, (2) Deduplicate cities that appear in multiple counties, (3) Cap the list if a county has hundreds of cities (e.g., top 50 by population or just list all — prompt length tradeoff). |
| 24 | **Google Calendar Cancellation Fails Silently** | � CODE COMPLETE | Agent tells caller the appointment was cancelled, but the Google Calendar event is NOT actually deleted. The cancel tool call also doesn't appear in the UI. **NOTE**: Node agent has been removed (archived in git history Feb 16, 2026); only the Python agent (`livekit-python/`) is used. **ROOT CAUSES**: (1) **Backend cancel endpoint may fail silently**: The cancel endpoint (`server.ts:11007+`) calls Google Calendar API via Nango proxy — if the event ID is wrong, the OAuth connection expired, or the calendar ID is incorrect, it returns an error response. The Python agent's tool wrapper receives this error but the LLM may still tell the caller "your appointment has been cancelled" because the error message is conversational. (2) **Tool call not appearing in UI**: The Python agent (`livekit-python/server.py:1281-1396`) tracks tool calls via `function_tools_executed` event handler (including `is_error`, `output`, `call_id`, `arguments`) and uploads via `upload_call_data()` at session end. If the cancel tool call was attempted, it should appear in the DB. Investigate whether the cancel tool was actually invoked or if the agent hallucinated the cancellation without calling the tool. Also check if the call ended abnormally before `upload_call_data()` ran (tool calls only upload at session end). **FIX**: (A) Add server-side logging: when cancel endpoint is called, log the event ID, calendar ID, and result to CallRecord immediately (don't wait for session end). (B) Ensure cancel tool returns a clearly structured error so the LLM knows cancellation failed. (C) Consider uploading tool calls incrementally (after each tool execution) rather than only at session end, to prevent data loss if the session ends abnormally. |
| 25 | **CallerDetailPage Missing Tool Call Display** | 🟡 IMPROVEMENT | The CallerDetailPage (`callsaver-frontend/src/pages/CallerDetailPage.tsx:449-573`) shows call history with transcript and recording collapsibles, but has **no tool call section at all** — unlike DashboardPage which has full tool call rendering with `safeParseToolCalls()`, `formatToolCallInput()`, `formatToolCallOutput()`, error badges, Google Calendar icons, etc. (`DashboardPage.tsx:1107-1374`). The CallRecordDetailPage (`CallRecordDetailPage.tsx:407-429`) has a tool calls collapsible but only shows a placeholder message ("Tool calls data available. Full tool call display can be added here if needed."). **FIX**: (A) Extract the tool call rendering from DashboardPage's `CallRow` component into a shared `<ToolCallsSection>` component, (B) Use it in CallerDetailPage's call history items, (C) Replace CallRecordDetailPage's placeholder with the same shared component. All three pages should show identical tool call rendering with error indicators, Google Calendar icons, and formatted input/output. |
| 26 | **AppointmentsPage Shows All Calendar Events, Not Just Agent-Booked** | 🔴 ACTIVE BUG | The AppointmentsPage (`callsaver-frontend/src/pages/AppointmentsPage.tsx`) renders `<CalendarEvents>` without a `phoneNumber` prop, which calls `GET /me/calendar/events` (`server.ts:5316-5569`). This endpoint fetches **all events** from the linked Google Calendar with no filtering — it calls the Google Calendar API with only `timeMin`, `timeMax`, `singleEvents`, `orderBy`, and `maxResults` params. Personal events (doctor appointments, birthdays, etc.) appear alongside field service dispatch appointments booked by the agent. **CONTRAST**: The `GET /me/calendar/events/by-phone/:phoneNumber` endpoint (`server.ts:5572+`) correctly uses `sharedExtendedProperty=callerPhoneNumber={phone}` to filter to only agent-booked events for a specific caller. The `fetchCallerCalendarEvents()` function (`server.ts:10182-10281`) also uses this same `sharedExtendedProperty` filter. **WHAT METADATA EXISTS**: When the agent creates events via `POST /internal/tools/google-calendar-create-event` (`server.ts:10925-10948`), it already sets `extendedProperties.shared.callerPhoneNumber` and `extendedProperties.shared.callerId`. This metadata is the key to distinguishing agent-booked events from personal ones. **PROPOSED SOLUTION**: (1) **Add `source=callsaver` to extendedProperties.shared** when creating events (`server.ts:10929`). Add `sharedProperties.source = 'callsaver';` alongside `callerPhoneNumber` and `callerId`. This is a simple one-line addition. (2) **Add backend filtering**: Add a `source` query param to `GET /me/calendar/events`. When `source=callsaver`, add `sharedExtendedProperty: 'source=callsaver'` to the Google Calendar API request params (same pattern as the by-phone endpoint). Default behavior (no `source` param) returns all events for backward compatibility. (3) **Frontend: default to agent-booked only on AppointmentsPage**: In `CalendarEvents` component (`calendar-events.tsx:93`), add a `sourceFilter` prop (default: `'callsaver'` for AppointmentsPage, `'all'` for CallerDetailPage). Pass `source=callsaver` query param to the API when filtering. (4) **Optional toggle**: Add an "All Events / Agent Booked" toggle on AppointmentsPage (similar to the upcoming/past toggle on CallerDetailPage) for users who want to see everything. (5) **Backfill**: Existing agent-booked events won't have `source=callsaver` yet. As a fallback, events with `extendedProperties.shared.callerPhoneNumber` set can be treated as agent-booked (since only the agent sets this property). The filtering logic should be: `sharedExtendedProperty: 'source=callsaver'` OR `sharedExtendedProperty: 'callerPhoneNumber=*'` (note: Google Calendar API doesn't support wildcard on extended properties, so the fallback would need to be done client-side by checking if `extendedProperties.shared.callerPhoneNumber` exists on each event). **IMPLEMENTATION PRIORITY**: Step 1 is critical and trivial (one line). Step 2 is the backend filter. Step 3+4 is the frontend. Step 5 is the backfill/fallback logic. |
| 27 | **Appointment Ownership Scoping — Callers Should Only Cancel/Reschedule Their Own Appointments** | 🟡 SECURITY REVIEW | **CURRENT STATE — WHAT'S ALREADY IN PLACE**: The system has a multi-layered approach to scoping appointment access to the calling phone number. Here is a comprehensive overview: **(1) PROMPT-LEVEL SCOPING (Soft Guard)**: At call start, `POST /internal/agent-config` (`server.ts:8597-8619`) fetches the caller's calendar events via `fetchCallerCalendarEvents()` (`server.ts:10182-10281`). This function uses Google Calendar API's `sharedExtendedProperty=callerPhoneNumber={normalizedPhone}` filter to return ONLY events tagged with the caller's phone number. The results are injected into the system prompt as `{{callerCalendarEvents}}` (`utils.ts:1546-1552, 2622-2629`). The prompt instructs the agent: "Use the correct event ID from the list when updating or canceling appointments" and "Always use the event ID from {{callerCalendarEvents}} when updating or canceling - do NOT ask the caller for the event ID" (`utils.ts:1548-1551`). This means the LLM only *sees* the caller's own events and their IDs. **(2) LIST-EVENTS TOOL (Soft Guard)**: The `google-calendar-list-events` tool (`server.ts:11386-11510`) also uses `sharedExtendedProperty=callerPhoneNumber={normalizedPhone}` to return only the caller's events. If the caller asks "what appointments do I have?", the tool only returns their own. **(3) BACKEND OWNERSHIP VALIDATION (Hard Guard)**: All mutation endpoints enforce ownership at the API level: **Cancel** (`server.ts:11007-11140`): Fetches the event from Google Calendar, extracts `extendedProperties.shared.callerPhoneNumber`, normalizes both phone numbers, and compares. Returns 403 "You can only cancel your own appointments" if mismatch. Falls back to legacy `validateEventIdOwnership()` (`utils/eventId.ts:90-111`) which extracts phone digits from the event ID format `p{phone_digits}{random_suffix}`. If neither validation method works, returns 403 "Unable to verify appointment ownership." If no `roomName`/caller phone is available, returns 400 "Caller context is required." **Update/Reschedule** (`server.ts:11143-11380`): Identical ownership validation pattern — fetches event, checks `extendedProperties.shared.callerPhoneNumber`, compares with caller's phone, returns 403 on mismatch. Same fallback to legacy event ID validation. **(4) EVENT CREATION TAGGING**: When the agent creates events (`server.ts:10925-10948`), it stores `callerPhoneNumber` (E.164 normalized) and `callerId` (Prisma CUID) in `extendedProperties.shared`. This is the foundation that makes all the above filtering and validation work. **GAPS AND RISKS IDENTIFIED**: (A) **LLM can hallucinate event IDs**: Even though the prompt only shows the caller's events, the LLM could theoretically fabricate or guess an event ID (e.g., from conversation context or a previous call's tool output). The backend hard guard catches this, but the error message "You can only cancel your own appointments" could confuse the caller if the LLM tried an invalid ID. (B) **Legacy events without extendedProperties**: Events created before the `extendedProperties.shared.callerPhoneNumber` feature was added won't have this metadata. The fallback to `validateEventIdOwnership()` only works for events with the custom `p{phone}{suffix}` ID format — but custom event IDs are currently DISABLED (`server.ts:10900-10908`), so Google generates random IDs. This means legacy events with Google-generated IDs and no extendedProperties will ALWAYS fail ownership validation (403). (C) **No `source=callsaver` tag yet**: As noted in item 26, events don't yet have a `source=callsaver` extended property. Adding this (item 26b) would further strengthen the ability to distinguish agent-created events. (D) **Prompt injection risk**: If a caller verbally provides an event ID during the call (e.g., "cancel event abc123"), the LLM might use that ID instead of the one from `{{callerCalendarEvents}}`. The backend hard guard protects against this, but the prompt could be strengthened to explicitly say "NEVER use an event ID provided verbally by the caller — only use IDs from the {{callerCalendarEvents}} list or from tool call responses." **PROPOSED IMPROVEMENTS**: (1) **Strengthen prompt guardrail** (`utils.ts:1546-1552`): Add explicit instruction: "NEVER accept or use an event ID spoken by the caller. Only use event IDs from the {{callerCalendarEvents}} list or from previous tool call responses in this conversation." (2) **Add `source=callsaver` to event creation** (same as item 26b — one-line fix at `server.ts:10929`). (3) **Log ownership validation failures**: When a 403 is returned from cancel/update endpoints, log the attempted event ID, the caller's phone, and the event's stored phone for debugging. Currently the error is returned but not logged with detail. (4) **Consider re-enabling custom event IDs**: The `generateEventId()` function (`utils/eventId.ts:38-57`) generates IDs in format `p{phone_digits}{12_char_suffix}` which embeds the caller's phone. This was disabled due to Google Calendar API "Invalid resource id value" errors, but could be revisited as a defense-in-depth measure. (5) **Backfill existing events**: For events created before `extendedProperties` was added, consider a one-time migration script that matches events to callers (by summary/description containing caller name, or by cross-referencing with CallRecord tool calls) and patches `extendedProperties.shared.callerPhoneNumber` onto them via Google Calendar API PATCH. |
| 22 | **Wrong Date/Day Announced** | � CODE COMPLETE | Agent said "today is Friday" when it was Monday. **ROOT CAUSE**: Legacy VAPI template token system. Stored `agent.systemPrompt` contains `{{"now" \| date: "%A, %B %d, %Y, %I:%M %p", "America/Los_Angeles"}}` which `processLiquidDateFilters()` (`server.ts:8334`) tries to resolve at call-start. If the token was already resolved to a literal date when the prompt was regenerated (e.g., on a Friday), the regex won't match and the stale date persists. The explicit `CURRENT DATE AND TIME CONTEXT` block (`server.ts:8650-8668`) IS correct but the LLM may follow the stale inline date instead. **FIX**: Remove VAPI token system entirely (we no longer use VAPI). (1) In `generateSystemPrompt()` (`utils.ts:1404`), replace `injectedTimeToken` with a simple placeholder `{{CURRENT_DATE_TIME}}`, (2) At call-start in `/internal/agent-config` (`server.ts:8640`), replace placeholder with `new Date().toLocaleString('en-US', { timeZone: location.timezone, ... })`, (3) Delete `processLiquidDateFilters()` and `formatDateTimeWithStrftime()` (`server.ts:8327-8426`) — dead VAPI code, (4) Keep the explicit `CURRENT DATE AND TIME CONTEXT` block as safety net. Also update `setupLocationPrompt()` and `regenerateAgentPrompt()` in `prompt-setup.ts` to stop generating VAPI-format `injectedTimeToken`. |

---

## Technical Details: Intake Question Injection

### How Intake Questions Flow into System Prompt

**1. Data Storage** (`Location.intakeQuestions` JSON field)
```typescript
[
  { id: UUID, type: 'name', label: 'Name', required: true },
  { id: UUID, type: 'address', label: 'Address', required: true },
  { id: UUID, type: 'email', label: 'Email', required: false }
]
```

**2. Prompt Generation** (`src/utils.ts:1217-1256`)
- `generateIntakeSteps()` iterates `locationIntakeQuestions` array **in order**
- For each question:
  - Gets prompt text: `question.promptText || getDefaultIntakePrompt(question.type)`
  - Gets type-specific instructions: `getIntakeTypeInstructions(question)`
  - Builds numbered step: `**Step ${stepNum} - ${label.toUpperCase()}** (required/optional): ${prompt}${instructions}`

**3. Returning Caller Logic** (`src/utils.ts:1224-1227`)
```typescript
// CRITICAL: This can cause questions to be skipped incorrectly
if (q.type === 'name' && isReturningCaller && callerName) {
  continue; // Skips name question if caller has name on file
}
```

**4. Final Prompt Injection** (`src/utils.ts:1258-1270`)
```
INTAKE & BOOKING NORTH STAR
- **INTAKE PROCESS**: Follow this exact order. Do NOT proceed to next step until complete.

**Step 1 - NAME** (required): May I get your name? Please spell your first and last name.
   Ask the customer to spell both their first and last name...

**Step 2 - ADDRESS** (required): What's the service address?
   - **CRITICAL**: Do NOT ask for ZIP code...
   [detailed validation instructions]

**Step 3 - EMAIL** (optional): What email should we send confirmation to?
   Always ask them to spell their email address...
```

**5. Prompt Storage & Retrieval**
- Generated prompt stored in `agent.systemPrompt` (database)
- When UI updates intake questions → `regenerateAgentPrompt()` called automatically
- Python agent must fetch fresh prompt on each call (no caching)

**6. Common Issues**
- **Name skipped**: `isReturningCaller=true` + `callerName` contains phone number or garbage data
- **Wrong order**: Prompt not regenerated after reordering, or agent cached old prompt
- **Questions ignored**: Agent using stale prompt from previous session

---

## Quick Reference: Key Files

| Component | Path |
|-----------|------|
| Cal Booking Pipeline | `src/services/cal-booking-pipeline.ts` |
| LiveKit Agent (Python) | `livekit-python/` directory |
| LiveKit Agent Session / Hangup Logic | `livekit-python/agent.py` or session manager |
| Intake Submission Endpoint | `src/api/internal/submit-intake.ts` or similar |
| Email Service | `src/services/email/` |
| Location Settings UI | `src/app/(dashboard)/settings/location/` |
| Call Transcript UI | `src/components/call-transcript/` |
| Dashboard Stats | `src/app/(dashboard)/dashboard/page.tsx` |

---

## Task Audit & Phased Implementation Plan

> **Updated: Feb 16, 2026**
> Audit of all QA tasks — which have proposed solutions, which need investigation, and a phased implementation approach to batch related code changes.

### A. Tasks WITH Proposed Solutions (Ready to Implement)

| # | Task | Type | Solution Location |
|---|------|------|-------------------|
| 2 | Appointments Booked shows 0 | Backend code | Add `prisma.appointment.create()` after Google Calendar event creation |
| 4 | Name not collected before booking | Backend code (1-line) | Fix skip condition in `utils.ts:1224` — check `callerName.length >= 2` |
| 6 | Email timestamp 8hr off | Backend code | Pass `location.timezone` through `FirstCallEmailJobData`, use in `toLocaleString` |
| 7 | Appointment timezone 8hr off | Backend + prompt | Update tool description to use TZ offset not `Z`; add server-side re-interpretation |
| 11 | Service area county validation | Backend code | Expand counties to city lists at prompt generation time (same as 23) |
| 13a | Appointment settings key inconsistency | Backend code (small) | Update `getDefaultAppointmentDuration()` to check both keys |
| 13b | Buffer time not implemented | Backend code | Add `getBufferMinutes()` helper, expand freeBusy query window |
| 18 | Silence doesn't terminate call | Python agent code | Use `api.room.delete_room()` after goodbye message |
| 21 | "Does that LOOK good" phrasing | Prompt change (1-line) | Add phone-call-context instruction to `utils.ts:1181` |
| 22 | Wrong date/day announced | Backend code | Remove VAPI token system, use `{{CURRENT_DATE_TIME}}` placeholder |
| 23 | County-to-city expansion | Backend code | `expandServiceAreasWithCities()` helper in `utils.ts` (same as 11) |
| 24 | Calendar cancellation fails silently | Backend + Python agent | Server-side logging, structured error responses, incremental upload |
| 25 | CallerDetailPage missing tool calls | Frontend code | Extract shared `<ToolCallsSection>` component from DashboardPage |
| 25b | CallRecordDetailPage placeholder | Frontend code | Replace placeholder with shared component (same as 25) |
| 26 | AppointmentsPage shows all events | Backend + frontend | `source=callsaver` tag + backend filter + frontend toggle |
| 26b | Add `source=callsaver` to events | Backend code (1-line) | `sharedProperties.source = 'callsaver'` at `server.ts:10929` |
| 26c | Add `source` filter to GET endpoint | Backend code | Add `sharedExtendedProperty` filter to `/me/calendar/events` |
| 26d | Agent Booked / All Events toggle | Frontend code | Add toggle to AppointmentsPage `CalendarEvents` component |
| 27a | Reject verbally-provided event IDs | Prompt change (1-line) | Add instruction to `utils.ts:1546-1552` |
| 27b | Log ownership validation failures | Backend code (small) | Add detailed logging at 403 responses in cancel/update endpoints |

### B. Tasks WITHOUT Proposed Solutions (Need Investigation or Manual QA)

#### Manual QA Checks (No Code Changes — Just Test & Verify)

| # | Task | What to Do |
|---|------|------------|
| 8 | Background Noise Toggle | Toggle setting in UI, make test call, verify background audio plays/stops |
| 9 | Intake Question Ordering | Reorder in UI, make test call, verify agent asks in new order |
| 10 | Service Availability Filtering | Remove a service in UI, ask agent to book it, verify decline |
| 12 | Service Area Rejection Modes | Test hard reject vs soft reject behavior with out-of-area city |
| 15 | Callback Request Logging | Trigger callback flow, verify DB record + UI display |
| 16 | FAQ Awareness | Configure FAQs in UI, ask agent FAQ questions, verify answers |
| 17 | Promotions Awareness | Configure promotions in UI, ask agent about deals, verify mentions |
| 19 | Maximum Call Duration | Set short duration, verify agent ends call gracefully at limit |
| 20 | End Call Reason Tracking | Test all end-call scenarios, verify correct reason codes in DB + UI |
| 27 | Appointment Ownership Scoping | Test cancel/reschedule with different caller phones, verify 403s |

#### Need Investigation (May or May Not Need Code Changes)

| # | Task | What's Missing |
|---|------|----------------|
| 1 | LiveKit Egress S3 CORS | Add `cors` config to S3 bucket in CDK `storage-stack.ts` — wildcard `*.callsaver.ai` |
| 3 | submit_intake_answers failing | Need to check agent logs for error details — root cause unknown |
| 5 | Transcript scrollable container | Need to find the component and add `max-height` + `overflow-y: auto` |
| 14 | Call Transfer Number | Need to verify current transfer works + add UI field for post-onboarding update |
| 24b | Incremental tool call upload | Architecture decision — may be complex Python agent change |
| 27c | Backfill legacy event metadata | One-time migration script — low priority |

---

### Phased Implementation Plan

> **Goal**: Group related tasks into phases so multiple issues are fixed in a single Cascade session, saving prompt credits. Each phase touches the same files/areas of the codebase.

#### Phase 1: Timezone & Date Fixes (Critical — 3 bugs, same root cause family)
**Items**: 6, 7, 22
**Files touched**: `server.ts` (agent-config, create-event, email queueing), `utils.ts` (prompt generation), `queues.ts`, `first-call-celebration.ts`
**Why group**: All three bugs stem from timezone mishandling. Item 22 (wrong day) and 7 (appointment 8hr off) both involve the system prompt and tool datetime formatting. Item 6 (email 8hr off) is the same UTC-vs-local bug in a different place. Fixing all three together ensures consistent timezone handling across the entire call lifecycle.
**Estimated scope**: ~50-80 lines changed across 4 files

#### Phase 2: Prompt Engineering Fixes (Quick wins — all in `utils.ts`)
**Items**: 4, 21, 23/11, 27a
**Files touched**: `utils.ts` only
**Why group**: All are prompt generation changes in the same file. Item 4 is a 1-line condition fix. Item 21 is adding a phone-call-context instruction. Item 23/11 is the county-to-city expansion. Item 27a is adding an event ID guardrail instruction. All are in `generateSystemPrompt()` or `generateIntakeSteps()`.
**Estimated scope**: ~30-50 lines changed in 1 file

#### Phase 3: Google Calendar Event Metadata & Filtering
**Items**: 26b, 26c, 26d, 2, 27b
**Files touched**: `server.ts` (create-event, GET events, cancel/update endpoints), frontend `calendar-events.tsx`, `use-calendar-events.ts`, `AppointmentsPage.tsx`
**Why group**: All involve Google Calendar event metadata and how events are stored/filtered/displayed. Item 26b (add `source=callsaver`) is prerequisite for 26c (backend filter) and 26d (frontend toggle). Item 2 (create Appointment record) also happens in the create-event flow. Item 27b (log ownership failures) is a small addition to the cancel/update endpoints in the same file.
**Estimated scope**: ~80-120 lines changed across 4-5 files

#### Phase 4: Frontend Tool Call Display (All frontend, shared component)
**Items**: 25, 25b
**Files touched**: `callsaver-frontend/src/components/` (new shared component), `CallerDetailPage.tsx`, `CallRecordDetailPage.tsx`, `DashboardPage.tsx` (extract from)
**Why group**: Both tasks are about extracting tool call rendering into a shared component and using it in 3 pages. Pure frontend refactor.
**Estimated scope**: ~150-200 lines (new component + 3 page modifications)

#### Phase 5: Python Agent Reliability
**Items**: 18, 24
**Files touched**: `livekit-python/server.py`
**Why group**: Both involve the Python agent's session lifecycle. Item 18 (call termination) requires `delete_room` API call at session end. Item 24 (cancel tool visibility) involves ensuring tool calls are properly tracked and uploaded. Both touch the session end handler and tool execution handler in `server.py`.
**Estimated scope**: ~30-50 lines in 1 file

#### Phase 6: Appointment Duration & Buffer Time
**Items**: 13a, 13b
**Files touched**: `server.ts` (settings reader, check-availability, create-event)
**Why group**: Both are about appointment settings. 13a (key inconsistency) must be fixed before 13b (buffer implementation) since buffer reads from the same settings object.
**Estimated scope**: ~40-60 lines in 1 file

#### Phase 7: Investigation & Smaller Fixes
**Items**: 1, 3, 5, 14
**Files touched**: CDK `storage-stack.ts` (item 1), agent logs (item 3), frontend component (item 5), location settings UI (item 14)
**Why group**: Items 3, 5, 14 need investigation first. Item 1 (S3 CORS) has a proposed solution now — add `cors` config with `allowedOrigins: ['https://*.callsaver.ai']` to the session bucket in `storage-stack.ts:39-52`, then CDK deploy. Can be done alongside investigating the other items.
**Estimated scope**: Item 1 is ~5 lines in CDK + deploy. Items 3, 5, 14 are TBD after investigation.

#### Phase 8: Manual QA Pass (No Code — Just Testing)
**Items**: 8, 9, 10, 12, 15, 16, 17, 19, 20, 27
**What to do**: Make test calls exercising each feature. Log pass/fail. Some may reveal new bugs that get added to the task list.
**Prerequisite**: Phases 1-6 should be deployed first so you're testing the fixed codebase.

#### Deferred (Low Priority)
**Items**: 24b (incremental tool upload), 27c (backfill legacy events)
**Why defer**: 24b is an architecture change that may not be needed if Phase 5 fixes the immediate issue. 27c is a one-time migration script for old data.

---

### Phase Priority & Recommended Order

| Order | Phase | Impact | Effort |
|-------|-------|--------|--------|
| 1st | **Phase 1: Timezone Fixes** | 🔴 Critical — 3 user-facing bugs | Medium |
| 2nd | **Phase 2: Prompt Fixes** | 🔴 High — 4 issues, all quick | Low |
| 3rd | **Phase 3: Calendar Metadata** | 🔴 High — appointments UX | Medium |
| 4th | **Phase 5: Python Agent** | 🔴 High — call termination + tool tracking | Low-Medium |
| 5th | **Phase 6: Duration/Buffer** | 🟡 Medium — scheduling accuracy | Medium |
| 6th | **Phase 4: Frontend Tool Calls** | 🟡 Medium — debugging visibility | Medium |
| 7th | **Phase 7: Investigation** | 🟡 Medium — mixed bag | TBD |
| 8th | **Phase 8: Manual QA** | ✅ Validation | No code |

---

### Manual QA Verification Tests (Per Phase)

> Run these tests after implementing each phase to confirm fixes work correctly.
> **Prerequisites**: Access to staging environment, a test phone number, and the staging web app at `staging.app.callsaver.ai`.

#### Phase 1 QA: Timezone & Date Fixes (Items 6, 7, 22)

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|----------|
| **1.1 — Agent says correct day** | Make a test call. Ask the agent "What day is it today?" or wait for it to mention the date naturally. | Agent says the correct current day of the week and date in the location's timezone (not a stale cached date). | |
| **1.2 — Appointment booked at correct time** | Call agent, book an appointment for "3 PM tomorrow". Check the Google Calendar event. | Event start time is 3:00 PM in the location's timezone (e.g., `15:00:00-08:00` for Pacific), NOT 3:00 AM or 11:00 PM. | |
| **1.3 — Appointment time spoken correctly** | After booking, listen to the agent's confirmation of the appointment time. | Agent says "3 PM" (or whatever was requested), not a UTC-converted time. | |
| **1.4 — First call email timestamp** | Trigger a first call celebration email (new caller's first call). Check the email received. | Email shows the correct local time (e.g., "2:54 PM" not "10:54 AM" or "6:54 AM"). Timezone matches the location's configured timezone. | |
| **1.5 — VAPI tokens removed** | Check the system prompt in agent logs for a test call. | No `{{"now" \| date: ...}}` VAPI tokens present. Should see `{{CURRENT_DATE_TIME}}` placeholder resolved to actual date, or the `CURRENT DATE AND TIME CONTEXT` block with correct date. | |

#### Phase 2 QA: Prompt Engineering Fixes (Items 4, 21, 23/11, 27a)

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|----------|
| **2.1 — Name collected for new caller** | Call from a new phone number (no caller record). Listen for name question. | Agent asks for the caller's name and asks them to spell it, even if a partial/garbage name was stored from a previous abandoned call. | |
| **2.2 — Name skipped for returning caller with valid name** | Call from a phone number that has a valid name on file (e.g., "John Smith"). | Agent greets by name ("Good afternoon John") and does NOT ask "What's your name?" | |
| **2.3 — No visual language** | Call agent, go through address validation flow. Listen to confirmation phrasing. | Agent says "Does that sound correct?" or "Is that right?" — NEVER "Does that look good?" or "Does that look right?" | |
| **2.4 — County expanded to cities** | Configure a location with service area "San Diego County". Make a test call and say you're in "Chula Vista". | Agent recognizes Chula Vista as within the service area (San Diego County) without hesitation. Does not say "I'm not sure if we serve that area." | |
| **2.5 — Out-of-area city rejected** | Same location with "San Diego County". Say you're in "San Francisco". | Agent politely declines: "I'm sorry, but it looks like we don't currently serve that area." | |
| **2.6 — Event ID guardrail** | During a call, verbally say "Can you cancel event ID abc123xyz?" | Agent should NOT use the verbally-provided ID. Should instead reference the caller's events from `{{callerCalendarEvents}}` or say it can't find a matching appointment. | |

#### Phase 3 QA: Google Calendar Event Metadata & Filtering (Items 26b, 26c, 26d, 2, 27b)

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|----------|
| **3.1 — `source=callsaver` on new events** | Book an appointment via the agent. Use Google Calendar API or Google Calendar UI to inspect the event's extended properties. | Event has `extendedProperties.shared.source = "callsaver"` alongside `callerPhoneNumber` and `callerId`. | |
| **3.2 — AppointmentsPage shows only agent-booked** | Create a personal event directly in Google Calendar (e.g., "Doctor Appointment"). Then book an event via the agent. Go to AppointmentsPage in the web app. | Only the agent-booked event appears by default. Personal "Doctor Appointment" does NOT appear. | |
| **3.3 — All Events toggle** | On AppointmentsPage, toggle to "All Events" mode. | Both the agent-booked event and the personal "Doctor Appointment" now appear. Toggle back to "Agent Booked" — personal event disappears again. | |
| **3.4 — Appointments Booked stat** | Book an appointment via the agent. Go to Dashboard and check the "Appointments Booked" statistic. | Count increments by 1 (no longer stuck at 0). | |
| **3.5 — Ownership validation logging** | Call from phone A, book an appointment. Call from phone B, try to cancel phone A's appointment (provide the event details verbally). Check server logs. | Server logs show detailed 403 with: attempted event ID, caller B's phone, event's stored phone (caller A). Agent tells caller B it can't verify ownership. | |
| **3.6 — No street view / map for events without address** | Toggle to "All Events" on AppointmentsPage. Ensure a personal/virtual event without a location is visible (e.g., a Google Meet event or "Team Standup" with no address). | Event card shows summary, time, and description but NO street view image, NO 3D Map button, NO Street View button. The location pin row is also hidden. Only events with a physical address show map UI. **NOTE**: Already guarded in code (`calendar-events.tsx:607,734,756` all check `event.location &&`). This test confirms the guards work in practice. | |

#### Phase 4 QA: Frontend Tool Call Display (Items 25, 25b)

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|----------|
| **4.1 — DashboardPage tool calls** | Make a call that triggers tool calls (book appointment, validate address). Go to Dashboard, find the call, click "Show Tool Calls". | Tool calls display with icons (Google Calendar, Google Maps), formatted input/output, and error badges if any. Same as before (regression check). | |
| **4.2 — CallerDetailPage tool calls** | Navigate to the caller's detail page (click on caller name or phone). Find the call in call history. | Tool calls section is visible with same rendering as DashboardPage — icons, formatted I/O, error badges. Previously this was completely missing. | |
| **4.3 — CallRecordDetailPage tool calls** | Navigate to the individual call record detail page. | Tool calls section shows full rendering (not the old placeholder "Tool calls data available. Full tool call display can be added here if needed."). | |
| **4.4 — Error tool call display** | If you have a call with a failed tool call (e.g., failed cancellation), check all three pages. | Failed tool call shows red border, red text, and "Error" badge consistently across all three pages. | |

#### Phase 5 QA: Python Agent Reliability (Items 18, 24)

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|----------|
| **5.1 — Silence terminates call** | Call the agent, then go completely silent for ~30 seconds (past all silence prompts). | After final "Are you still there?" prompt and goodbye message, the phone call actually disconnects. Caller hears dial tone / call ended, NOT continued silence. | |
| **5.2 — Tool calls appear after normal call** | Make a call, trigger some tool calls (check availability, book appointment). Hang up normally. Check the call record in the web app. | All tool calls appear in the call record with correct `name`, `arguments`, `output`, and `is_error` fields. | |
| **5.3 — Tool calls appear after abnormal end** | Make a call, trigger a tool call, then hang up abruptly mid-conversation (don't wait for goodbye). Check the call record. | Tool calls still appear in the call record (not lost due to session ending before upload). | |
| **5.4 — Cancel tool call visibility** | Call agent, book an appointment, then call back and cancel it. Check the call record for the cancellation call. | Cancel tool call appears in the tool calls list with the event ID, result (success or error), and `is_error` flag. | |

#### Phase 6 QA: Appointment Duration & Buffer Time (Items 13a, 13b)

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|----------|
| **6.1 — Default duration from settings** | Set default appointment duration to 45 minutes in location settings. Book an appointment via agent without specifying duration. Check Google Calendar event. | Event duration is 45 minutes (not the old default of 60). | |
| **6.2 — Settings key consistency** | Set duration via the general location update endpoint. Then read it back via `getDefaultAppointmentDuration()`. | Same value returned regardless of which endpoint wrote it (both `appointmentSettings` and `appointmentDuration` keys work). | |
| **6.3 — Buffer time enforced** | Set buffer time to 15 minutes. Book appointment A at 2:00-3:00 PM. Try to book appointment B at 3:00 PM (no buffer). | Agent says 3:00 PM is not available (buffer conflict). Suggests 3:15 PM or later. | |
| **6.4 — Buffer time in availability check** | Set buffer to 15 min. Have an existing event at 2:00-3:00 PM. Ask agent to check availability at 3:00 PM. | Agent reports 3:00 PM as unavailable due to buffer. 3:15 PM or later is available. | |

#### Phase 7 QA: Investigation & Smaller Fixes (Items 1, 3, 5, 14)

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|----------|
| **7.1 — S3 CORS / Recording playback** | Go to a call record in the web app that has an audio recording. Click play. | Audio plays in the browser without CORS errors in the console. Works on both `staging.app.callsaver.ai` and `app.callsaver.ai`. | |
| **7.2 — submit_intake_answers** | Make a call that triggers intake question collection. Check if intake answers are saved. | Intake answers are stored in the database (no tool call errors in agent logs). | |
| **7.3 — Transcript scrollable** | Open a call with a long transcript (5+ minutes). Check the transcript display. | Transcript is contained within a scrollable area with a max height. Does not stretch the page infinitely. | |
| **7.4 — Transfer number update** | Go to Location Settings, find the transfer number field, change it, save. Make a test call and trigger a transfer. | Call transfers to the newly configured number (not the old onboarding number). | |

#### Phase 8 QA: Manual Feature Verification (Items 8, 9, 10, 12, 15, 16, 17, 19, 20, 27)

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|----------|
| **8.1 — Background noise toggle** | Enable background noise in location settings. Make a test call. | Subtle office ambience / keyboard sounds audible during the call. Disable toggle, make another call — no background noise. | |
| **8.2 — Intake question ordering** | Reorder intake questions in UI (e.g., move email before address). Make a test call. | Agent asks for email before address (matching the new order). | |
| **8.3 — Service availability filtering** | Remove a service from the location (e.g., "Teeth Whitening"). Ask agent to book it. | Agent declines: "I don't see that as one of our available services" or similar. | |
| **8.4 — Service area rejection modes** | Set rejection mode to "hard reject". Call from out-of-area city. Then switch to "soft reject" and repeat. | Hard: Agent declines booking entirely. Soft: Agent notes the area concern but continues collecting info. | |
| **8.5 — Callback request logging** | Trigger a callback request (say "I want to speak to a manager" on a Path A location). Check web app. | Callback request record appears in the UI with caller info, reason, and pending status. | |
| **8.6 — FAQ awareness** | Configure FAQ: "Do you take insurance?" → "Yes, we accept most major insurance providers." Ask agent the question. | Agent responds with the configured answer, not a hallucinated one. | |
| **8.7 — Promotions awareness** | Configure a promotion: "SPRING20 — 20% off first service". Ask agent "Do you have any deals?" | Agent mentions the SPRING20 promotion with correct details. | |
| **8.8 — Maximum call duration** | Set max duration to 2 minutes. Make a test call and keep talking. | Agent gracefully ends the call at ~2 minutes with a reason like "I want to be respectful of your time" and `end_call_reason: max_duration_reached`. | |
| **8.9 — End call reason tracking** | Test multiple end scenarios: (a) caller hangs up, (b) agent ends call after booking, (c) silence timeout, (d) max duration. Check call records. | Each call record has the correct `endCallReason` value: `caller_hung_up`, `booking_completed`, `silence_timeout`, `max_duration_reached`. | |
| **8.10 — Appointment ownership** | Call from phone A, book appointment. Call from phone B, ask to cancel "my appointment" (but phone B has none). | Agent says no appointments found for this phone number. Does NOT expose or cancel phone A's appointment. | |

---

## Test Execution Log

| Date | Tester | Items Tested | Results |
|------|--------|--------------|---------|
| Feb 16, 2026 | Cascade | Phase 1: Items 6, 7, 22 — Code Complete | **Item 22**: Removed VAPI LiquidJS token system from `utils.ts`, `prompt-setup.ts`, `server.ts`. Replaced with `{{CURRENT_DATE_TIME}}` placeholder resolved at call-start via `resolveCurrentDateTimePlaceholder()`. Removed `Liquid` import. **Item 7**: Updated Python tool docstring to use timezone offset (not Z). Added server-side Z-suffix stripping in create-event endpoint — uses `resolvedStartDateTime`/`resolvedEndDateTime` throughout. **Item 6**: Added `timezone` field to `FirstCallEmailJobData`, passed `location.timezone` when queueing, used in `toLocaleString()` in email template. **PENDING QA**: Tests 1.1–1.5. |
| Feb 16, 2026 | Cascade | Phase 2: Items 4, 21, 23/11, 27a — Code Complete | **Item 4**: Fixed caller name skip condition in `utils.ts:1226` — changed from `isReturningCaller && callerName` to `callerName && callerName.length >= 2`. Removes dependency on `isReturningCaller` flag. **Item 21**: Added phone call context rule to `VOICE & BEHAVIOR` section in `utils.ts` — "Never use visual language like look, see, or view". **Item 23/11**: Added `expandServiceAreasWithCities()` helper in `utils.ts` that detects county entries, calls `getCitiesByCounty()`, and expands to explicit city lists. Imported `getCitiesByCounty` from `@mardillu/us-cities-utils`. **Item 27a**: Added event ID guardrail to prompt — "NEVER use an event ID that the caller provides verbally." **PENDING QA**: Tests 2.1–2.6. |
| Feb 16, 2026 | Cascade | Phase 5: Items 18, 24 — Code Complete | **Item 18**: Already implemented — `delete_room` call exists at `server.py:1486` in silence detection path. All termination paths (silence, max duration mode 1/2) use `delete_room`. **Item 24**: Added incremental tool call uploads — new `append_tool_call()` in `api_client.py`, new `POST /internal/call-records/append-tool-call` endpoint in `server.ts`, called via `asyncio.create_task()` after each tool execution in `on_function_tools_executed` handler. Cancel tool already returns clear error messages. **PENDING QA**: Tests 5.1–5.4. |
| Feb 16, 2026 | Cascade | Phase 6: Items 13a, 13b — Code Complete | **Item 13a**: Fixed `getDefaultAppointmentDuration()` in `server.ts` to check both `settings.appointmentDuration` and `settings.appointmentSettings` keys. Changed default from 90 to 60 minutes. **Item 13b**: Added `getBufferMinutes()` helper (checks both keys). Applied buffer in check-availability endpoint — expands freeBusy query window by `bufferMinutes` on each side. Added `APPOINTMENT DURATION & SPACING` section to prompt with dynamic `defaultAppointmentMinutes` and `bufferMinutes`. Passed both values from all 3 call sites: `setupLocationPrompt()`, `regenerateAgentPrompt()`, `generateSystemPromptForLocation()`. **PENDING QA**: Tests 6.1–6.4. |

---

## Bug/Issue Tracker

| # | Item | Severity | Assigned | Issue Link | Status |
|---|------|----------|----------|------------|--------|
| 2 | Appointments Booked shows 0 | 🔴 High | | | Open |
| 3 | submit_intake_answers failing | 🔴 High | | | Open |
| 4 | Name not collected before booking | 🔴 High | | | Open |
| 6 | Email timestamp shows UTC instead of location timezone | � High | | | Open |
| 7 | Appointment booked at wrong time (UTC vs Pacific, 8hr offset) | 🔴 High | | | Open |
| 14b | Can't update transfer number post-onboarding | 🟡 Medium | | | Open |
| 18 | Silence detection doesn't terminate call (agent leaves room, call continues) | 🔴 High | | | Open |
| 21 | Agent says "does that LOOK good" on phone call (visual language) | 🟡 Medium | | | Open |
| 22 | Agent announces wrong day of week (stale date in stored prompt) | 🔴 High | | | Open |
| 11 | Service area county validation relies on LLM guessing cities | 🔴 High | | | Open |
| 13a | Appointment settings key inconsistency (appointmentSettings vs appointmentDuration) | 🟡 Medium | | | Open |
| 13b | Buffer time between appointments not implemented | 🔴 High | | | Open |
| 23 | County-to-city expansion needed in prompt generation | 🟡 Medium | | | Open |
| 24 | Google Calendar cancellation fails silently, tool calls may not upload if session ends abnormally | 🔴 High | | | Open |
| 24b | Tool calls only uploaded at session end — consider incremental upload | � Medium | | | Open |
| 25 | CallerDetailPage missing tool call display section | 🟡 Medium | | | Open |
| 25b | CallRecordDetailPage tool calls section is placeholder only | 🟡 Medium | | | Open |
| 26 | AppointmentsPage shows all Google Calendar events, not just agent-booked | 🔴 High | | | Open |
| 26b | Add `source=callsaver` to extendedProperties.shared on event creation (one-line fix) | 🔴 High | | | Open |
| 26c | Add `source` filter param to GET /me/calendar/events endpoint | 🟡 Medium | | | Open |
| 26d | Add Agent Booked / All Events toggle on AppointmentsPage | 🟡 Medium | | | Open |
| 27 | Appointment ownership scoping review — callers can only modify their own appointments | 🟡 Medium | | | Open |
| 27a | Strengthen prompt to reject verbally-provided event IDs | 🟡 Medium | | | Open |
| 27b | Log ownership validation failures with detail (event ID, caller phone, event phone) | 🟡 Medium | | | Open |
| 27c | Backfill extendedProperties on legacy events without caller metadata | 🟢 Low | | | Open |
