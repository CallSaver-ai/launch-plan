# Google Calendar Integration Test Plan

## Mock vs Real API Decision

**Recommendation: Mock tools (same pattern as existing tests)**

### Why mocking is the right approach

These pytest tests verify **agent behavioral compliance** — does the LLM follow the system prompt correctly given a set of tools? The mock tools already capture the correct interface (tool names, parameters, return shapes). The LLM doesn't know the difference.

Real GCal API calls would add:
- **Auth maintenance**: Pipedream access tokens expire; we'd need a dedicated test Google account, token refresh logic, and `.env` management for CI
- **State pollution**: Every test run creates/cancels real calendar events that need cleanup
- **Flakiness**: Network errors, rate limits, Google API outages would cause false failures
- **Cost**: Real API calls are slower and hit quota
- **Redundancy**: The backend GCal endpoints (`server.ts` lines 11626–13050) are already tested via `testing/test-availability-and-scheduling.sh` and manual QA

Real API integration tests belong in a separate test suite (e.g., `tests/integration/`) if ever needed. The behavioral pytest suite should stay fast, deterministic, and cheap.

---

## Guiding Principle: Test Prompts Must Mirror Production

**Test prompts in `prompts.py` must structurally match what `generateSystemPrompt()` in `utils.ts` produces in production.** If a section is present in the production prompt for a given integration type, the corresponding test prompt must include it. Otherwise we're testing against a prompt the agent will never actually see, which means passing tests don't prove anything about real-world behavior.

---

## Production Prompt Architecture: "None" vs "Google Calendar"

Source: `generateSystemPrompt()` in `src/utils.ts` (lines 1094–2205).

The production prompt is assembled in three layers:

### Layer 1 — Shared header (IDENTICAL for all integration types)

These sections appear in the exact same form for none, gcal, jobber, and hcp:

| Section | Content |
|---|---|
| **YOU ARE** | Voice persona + business name |
| **AGENT MINDSET** | "Make callers feel cared for" |
| **PRIMARY OBJECTIVE** | Answer questions, triage safety, confirm before ending |
| **Agent Identity** | `promptFragments.agent_identity` (from prompt-fragments.json) |
| **NAME COLLECTION & HANDLING** | Spelling request, first-name-only rule, full name in records only |
| **CALL TRANSFERS** | No verbal announcement before transfer |
| **CALLER INFORMATION & PERSONALIZATION** | `{{callerName}}`, `{{callerEmail}}`, `{{callerAddress}}`, `{{recentCallSummary}}`, `{{recentCallToolCalls}}`, `{{callerCalendarEvents}}` — includes GCal tool-call reference examples but is present for ALL types |
| **BUSINESS OVERVIEW** | Name + summary |
| **HOURS** | From `googlePlaceDetails.hours` |
| **Time context** | `injectedTimeToken` for "are you open now?" |
| **Customer context** | Customer phone number |
| **AREAS SERVED** | From `locationServiceAreas` with county expansion |
| **PAYMENT METHODS** | From `googlePlaceDetails.business.paymentOptions` |
| **SERVICE DETAIL TRIAGE** | When to probe (vague) vs skip probing (detailed) |

### Layer 2 — Integration-specific sections (set via `switch (integrationType)`)

Only **two variables** differ between integration types: `servicesSection` and `workflowSection`.

#### `servicesSection` — IDENTICAL for none and gcal

Both use the same static service list from `locationServices` with the same "HOW TO PRESENT SERVICES — CRITICAL" rules. (Jobber/HCP differ because they use `fs_get_services` tool instead.)

#### `workflowSection` — THE MAJOR DIFFERENCE

**None (default case)** — ~15 lines:
```
📋 INTAKE MODE
This business does not have a scheduling integration connected.
Your role is to collect information and answer questions.

BUSINESS HOURS: [businessHoursText]

YOUR WORKFLOW:
1. Answer questions about business, services, hours, service areas.
2. Collect info via intake questions above.
3. Submit using submit_intake_answers tool.
4. Let caller know team will follow up.

- You do NOT have access to scheduling or calendar tools.
- If caller asks to book: "I'd be happy to take your info and have someone reach out to schedule."
- "Just leave a message": Take message → request_callback → "Someone will get back to you."
```

**Google Calendar** — ~130 lines covering:
```
📅 CALENDAR MANAGEMENT
You have access to Google Calendar tools...

⚠️ CRITICAL TIMEZONE INFORMATION
- Business operates in [timezone]
- MANDATORY: Always pass timeZone parameter to every tool call

APPOINTMENT DURATION & SPACING
- Default: [X] minutes, Buffer: [Y] minutes

BUSINESS HOURS + CRITICAL VALIDATION
- MUST check time is within hours BEFORE calling check_google_calendar_availability
- If outside hours → suggest alternative, do NOT call tool

AVAILABILITY CHECKING
- Use check_google_calendar_availability ONLY after hours validation
- ISO 8601 with timezone for startDateTime/endDateTime
- NEXT/FIRST AVAILABLE: check → speak date/time → WAIT for explicit confirmation

CREATING APPOINTMENTS
- REQUIRED INFO: name, street address, city
- SERVICE AREA VALIDATION before booking
- ADDRESS CONFIRMATION: read back, spell if unclear, ask caller to confirm
- EMAIL: confirm existing or collect new (required for reminders)
- EXPLICIT CONFIRMATION before creating event
- Summary includes caller name + service type

CANCELLING APPOINTMENTS
- Need dateTime, optionally summary
- SECURITY: phone number must match appointment owner
- Confirm cancellation

RESCHEDULING APPOINTMENTS
- Need originalDateTime, newStartDateTime, newEndDateTime
- SECURITY: phone number verification
- If conflicts → suggest alternatives

UPDATING APPOINTMENT DETAILS
- Need eventId + one of: newAddress, attendees, summary, description
- SECURITY: phone number verification
- WHEN TO USE: change service type, add services, change address, update email
- WHEN NOT TO USE: time change (→ reschedule), cancel (→ cancel tool)

LISTING APPOINTMENTS
- Automatic phone number matching
- Present chronologically

CALENDAR BEST PRACTICES
- Confirm before creating/modifying
- Avoid repetitive phrases
```

### Layer 3 — Shared footer (IDENTICAL for all integration types)

These sections appear after the integration-specific block:

| Section | Content |
|---|---|
| **BUSINESS SCOPE** | From `organizationCategories` — out-of-scope handling |
| **POLICIES** | Estimate policy, diagnostic fee, financing info |
| **TRUST & CREDENTIALS** | Licensed, insured, guarantees |
| **VALUE PROPOSITIONS** | "Why choose us" |
| **PROPERTY TYPES** | "We serve: residential, commercial" |
| **intakeSectionDynamic** | Intake steps + saving caller info + address protocol (see below) |
| **SAFETY RULES** | `promptFragments.safety_rules` |
| **ESCALATION RULES** | `promptFragments.escalation_rules` |
| **GUARDRAILS** | No price invention, concise, clarify |
| **BRANDS** | "We commonly work with [brands]..." |
| **PROMOTIONS** | Current promotions + when-to-mention rules |
| **FAQ** | Q&A pairs, "use when relevant, don't read as list" |
| **CLOSING** | Must call `request_callback` before `end_call` if info collected |
| **ADDITIONAL STYLE** | Voice & behavior, phone/address pronunciation, price pronunciation, email spelling |

### `intakeSectionDynamic` — Structurally identical, with GCal-specific email behavior

This section is composed of three sub-parts, all gated on `!isFieldServiceIntegration` (true for both none and gcal):

1. **`intakeStepsSection`** — Generated from `locationIntakeQuestions` array. Produces numbered steps (Name → Address → Email → Preferred Time → Custom). **Identical structure** for none and gcal.

2. **`savingCallerInfoSection`** — "📤 SAVING CALLER INFORMATION — MANDATORY". Always present for non-FS integrations. **Two GCal-specific differences**:
   - Email field note: `isGoogleCalendar ? '— **REQUIRED** so appointment confirmation and reminders can be sent via email' : ''`
   - Email flow step: `isGoogleCalendar ? ' for appointment reminders' : ''`

3. **`addressCollectionProtocol`** — Detailed address collection, validation, and confirmation protocol. **Identical** for none and gcal.

### Summary: ALL differences between "none" and "gcal" in production

There are exactly **4 differences**. Everything else is identical.

#### Difference 1: Tools registered (`getLiveKitToolsForLocation` in server.ts:8846–9060)

| Tool | None | GCal |
|---|---|---|
| `validate-address` | ✅ | ✅ |
| `submit-intake-answers` | ✅ | ✅ |
| `request-callback` | ✅ | ✅ |
| `EndCallTool` | ✅ | ✅ |
| `google-calendar-check-availability` | ❌ | ✅ |
| `google-calendar-create-event` | ❌ | ✅ |
| `google-calendar-cancel-event` | ❌ | ✅ |
| `google-calendar-update-event` | ❌ | ✅ |
| `google-calendar-list-events` | ❌ | ✅ |

**Note on `request-callback`**: It is intentionally present for GCal. It's registered based on onboarding path (Path A/B), NOT integration type. It serves real purposes even with scheduling available: info-only calls, no-availability scenarios, "just leave a message", out-of-scope work, safety/emergency follow-up, and caller preference for callbacks over self-service booking. The shared CLOSING section also requires `request_callback` before `end_call` when caller info was collected — this applies to GCal too.

#### Difference 2: `workflowSection` in system prompt

- **None**: 📋 INTAKE MODE (~15 lines) — "no scheduling tools available", collect info, submit, let caller know team will follow up
- **GCal**: 📅 CALENDAR MANAGEMENT (~130 lines) — timezone rules, business hours validation before tool calls, availability checking, creating/cancelling/rescheduling/updating/listing appointments, phone number security, appointment duration + buffer, calendar best practices

#### Difference 3: Email requirement in `intakeSectionDynamic` (utils.ts:1201, 1350)

Two `isGoogleCalendar` conditionals:
- **None**: `"If the caller declines, that is okay — move on"`
- **GCal**: `"**REQUIRED** so appointment confirmation and reminders can be sent via email — do not skip this step"`

#### Difference 4: `{{callerCalendarEvents}}` injection (server.ts:9281–9310, utils.ts:3069–3076)

- **None**: `{{callerCalendarEvents}}` placeholder exists in the shared prompt but is replaced with `"No existing appointments found."` (never populated)
- **GCal**: At call start, `fetchCallerCalendarEvents()` (server.ts:11431–11533) queries Google Calendar API for events matching the caller's phone number via `sharedExtendedProperty` (last 30 days → next 90 days). Events are formatted as human-readable strings with internal event IDs and injected into the prompt. Example: `- Plumbing Repair on Monday, March 3, 2026, 10:00 AM to 11:00 AM at 123 Oak St (Internal ID: abc123 — do NOT share with caller)`

The prompt instructions for using these events (utils.ts:2142–2148) tell the agent to: reference appointments naturally, use event IDs for cancel/reschedule, NEVER trust verbally-provided event IDs (security guardrail), and present appointments chronologically.

### Key takeaway

The **4 differences** are: (1) 5 additional GCal scheduling tools, (2) `workflowSection` (15 lines → 130 lines), (3) email required vs optional, (4) real calendar events injected into prompt. Everything else — services, policies, trust, brands, promotions, FAQ, safety, escalation, guardrails, identity, triage, closing, style, `request-callback` tool — is assembled from the exact same shared code and is identical.

### Implications for test prompts

The test `GCAL_PROMPT` in `prompts.py` must reflect all 4 differences:
1. **Tools**: `TOOLS_GCAL` in `conftest.py` already includes mock GCal tools ✅
2. **Workflow section**: The test prompt's "INTAKE & BOOKING FLOW" section covers this partially, but should be expanded to match the production ~130-line workflow (timezone, hours validation, security, etc.)
3. **Email required**: The test prompt mentions this ✅
4. **Calendar events injection**: For returning caller tests, inject a formatted event list into the test prompt (currently NOT done — gap). New callers should get `"No existing appointments found."`

---

## Critical Finding: Test GCal Prompt Missing Shared Sections

**The test `GCAL_PROMPT` in `prompts.py` is significantly thinner than the production GCal prompt.** It only includes:
- `BUSINESS_INFO`, `AGENT_IDENTITY_RULES`, `SAFETY_RULES`, `END_CALL_RULES`
- `EMAIL_COLLECTION_RULES`, `ESCALATION_RULES`
- Booking workflow instructions

**Missing from test GCal prompt** (all present in production for GCal):
- `PROMOTIONS` — production has discountsSection
- `FAQ_SECTION` — production has faqSection
- `BRANDS_SECTION` — production has brandsSection
- `POLICIES_SECTION` — production has policiesBlock
- `TRUST_SECTION` — production has trustSection
- `GUARDRAILS` block — production has explicit "no price invention" rules
- `TRIAGE` section — production has service detail triage rules
- `NAME_COLLECTION_RULES` — production has spelling + first-name-only rules
- `CALLER_PERSONALIZATION` — production has `{{callerCalendarEvents}}` usage
- `CLOSING` section — production requires `request_callback` before `end_call`
- `COMMS_STYLE` — production has phone/email pronunciation rules

Meanwhile, the Jobber/HCP test prompts include most of these. The test GCal prompt should be brought to parity.

**Impact**: `test_business_content.py` parametrizes promos/FAQ/brands/policies/trust tests for `FS_MODES` only (not GCal) — precisely because the GCal test prompt lacks those sections. In production, GCal agents DO have all those sections and must handle them correctly.

**Fix required**: Rebuild `GCAL_PROMPT` in `prompts.py` to include all shared sections that production includes, matching the Layer 1 → Layer 2 → Layer 3 structure documented above. Then expand `test_business_content.py` to include GCal in its parametrize modes.

---

## Existing GCal Coverage Audit

### Already covered (20 tests across existing files):

| Test File | Test | Coverage |
|---|---|---|
| `test_integration_flows.py` | `TestGoogleCalendar::test_full_booking_asks_for_time` | GCAL-NC-1: After intake → asks for preferred time |
| `test_integration_flows.py` | `TestGoogleCalendar::test_outside_business_hours_no_tool_call` | GCAL-NC-3: 8 PM → reject without calling tool |
| `test_integration_flows.py` | `TestGoogleCalendar::test_closed_day_rejection` | GCAL-NC-4: Sunday → closed, suggest Monday |
| `test_integration_flows.py` | `TestSafetyHazards::test_gas_leak_stops_workflow[gcal]` | Gas leak → evacuate + 911 |
| `test_integration_flows.py` | `TestSafetyHazards::test_co_alarm_stops_workflow[gcal]` | CO alarm → evacuate + 911 |
| `test_endcall.py` | `test_endcall_after_booking[gcal]` | End call after booking confirmed |
| `test_endcall.py` | `test_endcall_after_callback[gcal]` | End call after callback request |
| `test_endcall.py` | `test_endcall_after_area_rejection[gcal]` | End call after out-of-area |
| `test_endcall.py` | `test_endcall_after_cancel_gcal` | End call after cancellation (GCal-specific) |
| `test_endcall.py` | `test_endcall_after_info_only[gcal]` | End call after info-only Q&A |
| `test_endcall.py` | `test_endcall_after_safety[gcal]` | End call after safety hazard |
| `test_email_collection.py` | `test_email_gcal_required` | CROSS-EMAIL-2: Email required for reminders |
| `test_email_collection.py` | `test_email_gcal_declined` | CROSS-EMAIL-3: Decline email → proceed |
| `test_email_collection.py` | `test_email_returning_caller_on_file[gcal]` | Returning caller email on file → no re-ask |
| `test_email_collection.py` | `test_email_returning_caller_missing` | GCal missing email → asks for it |
| `test_scheduling_advanced.py` | `test_next_available_appointment` | GCAL-NC-6: Next available → check + wait |
| `test_scheduling_advanced.py` | `test_next_available_waits_for_confirmation` | No auto-create without confirmation |
| `test_scheduling_advanced.py` | `test_change_service_type_on_event` | GCAL-RC-6: Change service → update, not reschedule |
| `test_scheduling_advanced.py` | `test_add_service_to_event` | GCAL-RC-7: Add service to existing event |
| `test_scheduling_advanced.py` | `test_gcal_returning_caller_references_context` | CROSS-CONTEXT-1: Returning caller personalization |

### Also already covered via ALL_MODES parametrize (GCal included automatically):

| Test File | Test | Category |
|---|---|---|
| `test_agent_identity.py` | `test_identity_direct_question[gcal]` | AI disclosure when asked |
| `test_agent_identity.py` | `test_someone_else_on_phone[gcal]` | "I'm not [Name]" correction |
| `test_escalation_and_triage.py` | `test_escalation_angry_caller[gcal]` | Angry → immediate escalation |
| `test_escalation_and_triage.py` | `test_escalation_demands_discount[gcal]` | Discount demand → defer |
| `test_escalation_and_triage.py` | `test_triage_vague_request_probing[gcal]` | Vague → probe |
| `test_escalation_and_triage.py` | `test_triage_detailed_request_no_probing[gcal]` | Detailed → skip probe |
| `test_escalation_and_triage.py` | `test_path_b_transfer_for_speak_to_someone[gcal]` | Path B transfer |
| `test_escalation_and_triage.py` | `test_path_b_prefers_callback[gcal]` | Path B callback |
| `test_business_content.py` | `test_are_you_open_now[gcal]` | "Are you open now?" |
| `test_custom_intake.py` | `test_intake_gcal` | Custom intake before booking |
| `test_custom_intake.py` | `test_no_custom_questions[gcal]` | No custom Qs → skip |
| `test_guardrails_edge_cases.py` | `test_gcal_cannot_cancel_others_events` | Can't cancel unowned events |

### Gap Analysis — File by File

#### `test_none_intake_pipeline.py` (12 tests, ALL none-only — MAJOR GAP)

This file tests the complete intake pipeline with tool call verification. GCal has its own pipeline (booking instead of callback) that needs equivalent coverage:

| None Test | GCal Equivalent Needed | Why Different |
|---|---|---|
| `test_name_spelling_requested` | **YES** | Same behavior expected — verify with GCal prompt |
| `test_validate_address_called` | **YES** | GCal requires address validation before booking |
| `test_submit_intake_answers_called` | **YES** | GCal should still call submit_intake_answers |
| `test_request_callback_after_intake` | **NO** (GCal books instead) | GCal creates calendar event, not callback |
| `test_full_intake_pipeline` | **YES — as full booking pipeline** | Equivalent: name → address → email → availability → create event |
| `test_custom_intake_answers_submitted` | **YES** | Custom answers should work alongside GCal booking |
| `test_address_out_of_area_after_validation` | **YES** | Must decline BEFORE checking availability |
| `test_preferred_time_asked` | **YES** (scheduling instead of preferred time) | GCal asks for specific time, then checks availability |
| `test_callback_offered_before_hangup` | **NO** (GCal confirms booking) | GCal confirms the event instead |
| `test_email_asked_during_intake` | **YES** | Email is REQUIRED for GCal reminders — even more critical |
| `test_first_name_only_acknowledgment` | **YES** | Same rule: first name only in conversation |
| `test_preferred_time_is_about_visit` | **YES** (variant) | GCal asks about appointment time, not callback time |

#### `test_business_content.py` (11 tests, ALL FS_MODES-only — GAP for GCal)

These tests only run for Jobber/HCP because the GCal test prompt lacks content sections:

| FS-Only Test | GCal Equivalent Needed | Notes |
|---|---|---|
| `test_promo_caller_asks_about_deals` | **YES** | Production GCal prompt has promotions |
| `test_promo_not_mentioned_when_rushed` | **YES** | Same rule applies |
| `test_faq_configured_question` | **YES** | Production GCal prompt has FAQ |
| `test_faq_unconfigured_question` | **YES** | Must defer, not hallucinate |
| `test_brands_listed_brand` | **YES** | Production GCal prompt has brands |
| `test_brands_unlisted_brand` | **YES** | Must not refuse, defer to team |
| `test_policy_estimate_free` | **YES** | Production GCal prompt has policies |
| `test_policy_financing` | **YES** | GreenSky info should be in prompt |
| `test_trust_licensed_insured` | **YES** | Production GCal prompt has trust section |
| `test_payment_methods` | **YES** | Same behavior |
| `test_why_choose_us` | **YES** | Value props should be in prompt |

#### `test_agent_identity.py` (2 tests none-only — GAP)

| None-Only Test | GCal Equivalent Needed | Notes |
|---|---|---|
| `test_identity_no_unprompted_disclosure` | **YES** | Verify no "I'm an AI" during normal GCal greeting |
| `test_identity_no_disclosure_during_intake` | **YES** | Verify no disclosure during GCal intake + booking flow |

#### `test_intake_ordering.py` (4 tests, ALL none-only — GAP)

| None-Only Test | GCal Equivalent Needed | Notes |
|---|---|---|
| `test_email_at_slot_3` | **YES** | GCal: email at slot 3 AND required for reminders |
| `test_default_order_custom_before_ptime` | **YES** | GCal: custom Qs before scheduling |
| `test_ptime_first_ordering` | **Not critical** | GCal always asks preferred time before check_availability |
| `test_name_always_first` | **YES** | Name must be first even if caller volunteers address |

#### `test_escalation_and_triage.py` (2 tests FS_MODES-only — partial gap)

| FS-Only Test | GCal Equivalent Needed | Notes |
|---|---|---|
| `test_triage_commercial_vs_residential` | **Optional** | GCal prompt doesn't include COMMERCIAL_RESIDENTIAL — production might depending on config |
| `test_multiple_services_one_request` | **YES** | Caller asks for "plumbing and HVAC" — should combine into one booking |

#### `test_guardrails_edge_cases.py` (4 tests FS_MODES/none-only — partial gap)

| Test | GCal Equivalent Needed | Notes |
|---|---|---|
| `test_no_time_preference` (FS) | **YES** | "Anytime works" with GCal — agent should check availability |
| `test_no_separate_create_assessment` (FS) | N/A | FS-specific |
| `test_no_duplicate_customer` (FS) | N/A | FS-specific (GCal doesn't create customers) |
| `test_greeting_no_duplicate_words` (none) | **YES** | Verify time-of-day greeting works with GCal prompt |

---

## Test Plan: New `test_gcal_integration.py`

All tests use mock tools from `conftest.py` (`TOOLS_GCAL`). Organized by priority.

### P0 — Critical (must pass before deploy)

#### 1. `TestGCalIntakePipeline` (mirrors `test_none_intake_pipeline.py`)

**`test_name_spelling_requested`** — Agent asks caller to spell their name
- Same pattern as none: "My name is John Smith" → agent asks for spelling
- Assert: Agent requests spelling or acknowledges name

**`test_validate_address_called`** — validate_address tool fires when address provided
- Provide name + address → agent should call `validate_address`
- Assert: `contains_function_call(name="validate_address")`

**`test_submit_intake_answers_called`** — submit_intake_answers fires during intake
- Walk through name → address → email flow
- Assert: `submit_intake_answers` called across turns

**`test_full_booking_pipeline`** — End-to-end: triage → name → address → email → availability → create event
- Turn 1: "My kitchen faucet is dripping" (detailed — skip probe)
- Turn 2: "John Smith, J-O-H-N S-M-I-T-H"
- Turn 3: "123 Oak Street in San Jose"
- Turn 4: "Yes, that's correct"
- Turn 5: "john@example.com"
- Turn 6: "How about Tuesday at 10 AM?"
- Turn 7: "Yes, that works"
- Assert: Both `submit_intake_answers` AND `google_calendar_create_event` fired across conversation

**`test_address_out_of_area_blocks_booking`** — Out-of-area → decline, NO availability check
- Provide name + Sacramento address → validate_address returns out-of-area
- Assert: Agent declines. No `google_calendar_check_availability` or `google_calendar_create_event`

**`test_email_asked_during_intake`** — Agent proactively asks for email
- Walk through name + address without volunteering email
- Assert: Agent asks for email (required for GCal reminders)

**`test_first_name_only_acknowledgment`** — First name only in conversation
- "My name is Alex Sikand, A-L-E-X S-I-K-A-N-D"
- Assert: Response does NOT contain "Alex Sikand" — only "Alex"

**`test_intake_before_scheduling`** — Agent collects info BEFORE checking availability
- "I need HVAC repair, can I get Tuesday at 2 PM?"
- Assert: Agent asks for name/address first. No `google_calendar_check_availability` in first turn

#### 2. `TestGCalBusinessInfo`

**`test_services_listed`** — "What services do you offer?" → lists from prompt
**`test_business_hours`** — "What are your hours?" → correct hours (Mon–Fri 8–5, Sat 9–1)
**`test_areas_served`** — "Do you serve San Jose?" → yes
**`test_out_of_area`** — "Do you serve Sacramento?" → no

#### 3. `TestGCalBusinessHoursValidation`

**`test_reject_after_hours`** — "Can I book 8 PM?" → reject, suggest within hours
**`test_reject_before_hours`** — "Can I book 6 AM?" → reject, suggest 8 AM opening
**`test_reject_sunday`** — "Can I book Sunday?" → closed, suggest Monday
**`test_saturday_hours`** — "What about Saturday at noon?" → Saturday 9–1, noon is OK
**`test_saturday_after_close`** — "Saturday at 3 PM?" → reject, Saturday closes at 1 PM

### P1 — Important (scheduling nuances + content sections)

#### 4. `TestGCalReturningCaller`

**`test_returning_caller_greets_by_name`** — Pre-loaded caller info → greets by name, no re-ask for name/email/address
**`test_returning_caller_reschedule`** — "I need to reschedule" → identifies event → checks availability → calls `google_calendar_update_event`
**`test_returning_caller_cancel`** — "Cancel my appointment" → identifies event → calls `google_calendar_cancel_event` → confirms
**`test_returning_caller_list_events`** — "What do I have scheduled?" → calls `google_calendar_list_events` → presents chronologically
**`test_returning_caller_address_confirmation`** — Confirms existing address before booking new appointment ("I have your address as [address]. Is that correct?")
**`test_returning_caller_new_service_request`** — Returning caller + new service → skips name/email, confirms address, proceeds to booking

#### 5. `TestGCalEdgeCases`

**`test_no_time_preference_anytime`** — "Anytime works" → checks availability, presents options (not arbitrary pick)
**`test_multiple_services_single_booking`** — "I need plumbing and HVAC" → combines into one appointment summary
**`test_address_confirmation_before_event`** — Agent confirms address before `google_calendar_create_event`
**`test_just_leave_a_message`** — "Can I just leave a message?" → takes message, calls `request_callback`
**`test_no_premature_endcall_during_booking`** — "Actually, one more thing" after booking → agent handles follow-up, does NOT end call

#### 6. `TestGCalContentSections` (requires `GCAL_PROMPT_FULL`)

These tests verify business content handling with a GCal prompt that includes all production content sections.

**`test_promo_caller_asks_about_deals`** — "Any specials?" → mentions a promotion
**`test_promo_not_during_intake`** — During intake flow → does NOT mention promotions
**`test_faq_configured_question`** — "Do you charge for estimates?" → "Free, no obligation"
**`test_faq_unconfigured_question`** — "24-hour emergency?" → defers to team, no hallucination
**`test_brands_listed`** — "Do you work on Rheem?" → confirmed
**`test_brands_unlisted_no_refusal`** — "Do you work on Noritz?" → doesn't refuse, defers
**`test_policy_estimate_free`** — "Diagnostic fee?" → free, no fee
**`test_policy_financing`** — "Financing?" → GreenSky, $1,000+
**`test_trust_licensed_insured`** — "Licensed and insured?" → yes, license #, background-checked
**`test_cancellation_policy`** — "Cancellation policy?" → 2 hours before

#### 7. `TestGCalIntakeOrdering`

**`test_email_at_slot_3`** — After name + address, next question is email (not custom Qs or scheduling)
**`test_name_always_first`** — Caller volunteers address but not name → agent asks for name first
**`test_custom_questions_before_scheduling`** — With custom intake enabled: custom Qs asked BEFORE checking availability

### P2 — Nice-to-have (guardrails + edge cases)

#### 8. `TestGCalGuardrails`

**`test_no_price_invention`** — "How much for a custom remodel?" → doesn't make up price, defers
**`test_ai_no_unprompted_disclosure`** — During normal greeting → no "I'm an AI" or "as a virtual assistant"
**`test_ai_no_disclosure_during_booking`** — Through multi-turn booking → never discloses AI status unprompted
**`test_safety_overrides_scheduling`** — "I smell gas, but can we still book?" → safety first, no booking
**`test_reschedule_security_no_unowned_event`** — Returning caller tries to reschedule event they don't own → denied
**`test_greeting_no_duplicate_words`** — Time-of-day greeting doesn't duplicate ("Good morning, morning Alex")

#### 9. `TestGCalCustomIntake`

**`test_custom_intake_with_booking`** — Custom questions (referral source, pets) asked alongside booking flow
**`test_custom_intake_skip_question`** — Caller says "skip" → agent moves on without looping
**`test_custom_intake_returning_caller_skip_known`** — Returning caller with info on file → skips known Qs

---

## Implementation Approach

### File structure
```
tests/
├── test_gcal_integration.py      # NEW — all GCal-specific tests from this plan
├── conftest.py                   # Existing — may add make_gcal_agent() helper
├── prompts.py                    # ADD GCAL_PROMPT_FULL with all content sections
└── ...                           # Existing test files unchanged
```

### Prompt changes required in `prompts.py`

#### 1. Add `GCAL_PROMPT_FULL` — mirrors production completeness

```python
GCAL_PROMPT_FULL = f"""You are a professional AI receptionist for a home services business with Google Calendar scheduling.

{BUSINESS_INFO}

{AGENT_IDENTITY_RULES}

{SAFETY_RULES}

{END_CALL_RULES}

{EMAIL_COLLECTION_RULES}

{PROMOTIONS}

{FAQ_SECTION}

{BRANDS_SECTION}

{POLICIES_SECTION}

{TRUST_SECTION}

{ESCALATION_RULES}

INTAKE & BOOKING FLOW (new callers):
[... same as existing GCAL_PROMPT booking flow ...]

EMAIL IS REQUIRED for Google Calendar bookings — explain it's needed for appointment reminders.
"""
```

#### 2. Add `make_gcal_agent()` helper in conftest or test file

```python
def make_gcal_returning_caller_agent(llm, *, caller_block: str) -> Agent:
    """Create a GCal agent with returning caller info injected."""
    prompt = GCAL_PROMPT_FULL + "\n\n" + caller_block
    return Agent(instructions=prompt, llm=llm, tools=TOOLS_GCAL)
```

### Mock tool enhancements

The existing mock tools in `conftest.py` are sufficient. No changes needed — `TOOLS_GCAL` already includes:
- `validate_address`, `submit_intake_answers`, `request_callback`
- `google_calendar_check_availability`, `google_calendar_create_event`
- `google_calendar_update_event`, `google_calendar_cancel_event`, `google_calendar_list_events`
- `EndCallTool`

### Execution

```bash
# Run only GCal integration tests
cd ~/callsaver-api/livekit-python
source .venv/bin/activate
pytest tests/test_gcal_integration.py -v

# Run with verbose LLM output for debugging
LIVEKIT_EVALS_VERBOSE=1 pytest tests/test_gcal_integration.py -v -s

# Run a specific test class
pytest tests/test_gcal_integration.py::TestGCalIntakePipeline -v

# Run a single test
pytest tests/test_gcal_integration.py::TestGCalBusinessHoursValidation::test_reject_sunday -v

# Run ALL GCal tests (new file + existing parametrized)
pytest tests/ -k "gcal" -v
```

### Test count summary

| Priority | Class | Tests |
|---|---|---|
| P0 | TestGCalIntakePipeline | 8 |
| P0 | TestGCalBusinessInfo | 4 |
| P0 | TestGCalBusinessHoursValidation | 5 |
| P1 | TestGCalReturningCaller | 6 |
| P1 | TestGCalEdgeCases | 5 |
| P1 | TestGCalContentSections | 10 |
| P1 | TestGCalIntakeOrdering | 3 |
| P2 | TestGCalGuardrails | 6 |
| P2 | TestGCalCustomIntake | 3 |
| **Total** | | **50 tests** |

Plus ~12 existing tests already parametrized with `[gcal]` = **~62 total GCal coverage**.

### Estimated cost
- ~50 new tests × 2-4 LLM calls each × gpt-4o-mini pricing
- Estimated: **$0.15–0.60 per full suite run**

### Estimated effort
- P0 tests (17 tests): ~3-4 hours
- P1 tests (24 tests): ~3-4 hours
- P2 tests (9 tests): ~1-2 hours
- `prompts.py` changes: ~30 minutes
- Total: **7-10 hours**

### Priority order for implementation
1. **`prompts.py` changes** — Add `GCAL_PROMPT_FULL` (prerequisite for content tests)
2. `TestGCalIntakePipeline` (P0) — validates the core intake + booking flow with tool call assertions
3. `TestGCalBusinessHoursValidation` (P0) — validates hours enforcement before tool calls
4. `TestGCalBusinessInfo` (P0) — validates prompt knowledge
5. `TestGCalReturningCaller` (P1) — validates personalization + event management
6. `TestGCalEdgeCases` (P1) — validates scheduling nuances
7. `TestGCalContentSections` (P1) — validates FAQ/promotions/brands/policies/trust with GCal prompt
8. `TestGCalIntakeOrdering` (P1) — validates slot ordering
9. `TestGCalGuardrails` (P2) — validates safety/identity
10. `TestGCalCustomIntake` (P2) — validates custom question integration
