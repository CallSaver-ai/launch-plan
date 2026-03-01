# No Integration vs Google Calendar — Full Delta

This document compares the "No Integration" path and the "Google Calendar" integration path in the CallSaver system prompt generation (`utils.ts` → `generateSystemPrompt`) and tool registration (`server.ts` → `getLiveKitToolsForLocation`).

## 1. Available Tools

| Tool | No Integration | Google Calendar |
|---|---|---|
| `validate-address` | ✅ | ✅ |
| `submit-intake-answers` | ✅ | ✅ |
| `request-callback` | ✅ | ✅ |
| `transfer-call` / `warm-transfer` | ✅ (Path B only) | ✅ (Path B only) |
| `google-calendar-check-availability` | ❌ | ✅ |
| `google-calendar-create-event` | ❌ | ✅ |
| `google-calendar-cancel-event` | ❌ | ✅ |
| `google-calendar-update-event` | ❌ | ✅ |
| `google-calendar-list-events` | ❌ | ✅ |

**5 GCal-exclusive tools.** Both paths share `validate-address`, `submit-intake-answers`, `request-callback`, and transfer tools.

## 2. Workflow Section (the big prompt difference)

### No Integration — `📋 INTAKE MODE`

```
This business does not have a scheduling integration connected.
Your role is to collect information and answer questions.

YOUR WORKFLOW:
1. Answer the caller's questions about the business, services, hours, and service areas.
2. Collect their information via the intake questions above.
3. Submit the collected information using submit_intake_answers.
4. Let the caller know the team will follow up with them.

- You do NOT have access to scheduling or calendar tools.
- If caller asks to book: "I'd be happy to take down your information and
  have someone from the team reach out to schedule that for you."
- "Just leave a message": Take message → request_callback → "someone will get back to you"
```

### Google Calendar — `📅 CALENDAR MANAGEMENT`

A ~130-line section covering 7 sub-workflows:

- **Timezone** — mandatory `timeZone` param on every tool call, injected from location settings
- **Duration & Spacing** — `defaultAppointmentMinutes`, `bufferMinutes` (auto-enforced)
- **Business Hours Validation** — must check hours BEFORE calling check-availability
- **Availability Checking** — ISO 8601 format, "next available" flow with explicit confirmation
- **Creating Appointments** — requires name + address + city (service area) + email + time confirmation before `create_event`
- **Cancelling** — security: phone number matching, empathetic tone
- **Rescheduling** — `originalDateTime` + `newStartDateTime` + `newEndDateTime`, phone verification
- **Updating Details** — change address/email/summary/description without changing time
- **Listing Events** — auto-uses caller phone, chronological display
- **Best Practices** — avoid repetitive phrases, confirm before modifying

## 3. Email Collection

| Aspect | No Integration | Google Calendar |
|---|---|---|
| **Required?** | Optional — "If the caller declines, that is okay — move on." | **REQUIRED** — "This is REQUIRED so appointment confirmation and reminders can be sent via email — do not skip this step." |
| **Source** | `intakeQuestions` array (email type) | Same array, but `isGoogleCalendar` flag forces required behavior |
| **In saving section** | `email: The caller's email address` | `email: The caller's email address — **REQUIRED** so appointment confirmation and reminders can be sent via email` |

Set in `getIntakeTypeInstructions` (utils.ts:1201) and `savingCallerInfoSection` (utils.ts:1350) via the `isGoogleCalendar` conditional.

## 4. Scheduling Configuration (injected in `server.ts`)

| Aspect | No Integration | Google Calendar |
|---|---|---|
| **Section** | Not injected | `SCHEDULING CONFIGURATION` block |
| **Duration** | N/A | `defaultAppointmentMinutes` from location settings (default 60) |
| **Buffer** | N/A | `bufferMinutes` from location settings (default 0) |
| **Business hours source** | `googlePlaceDetails` → `formatHours()` in base prompt only | Same source but ALSO injected into `SCHEDULING CONFIGURATION` with day-by-day breakdown |
| **Hours validation rule** | N/A (no scheduling tools) | "MUST check if requested time falls within business hours BEFORE calling check-availability" |
| **Duration tool usage** | N/A | "You can specify `start_date_time` and `duration_minutes` (recommended) OR both `start_date_time` and `end_date_time`" |

## 5. Services Section

**Identical** between the two paths — both use `defaultServiceLines` from `location.services` with the same "HOW TO PRESENT SERVICES — CRITICAL" instructions.

## 6. Shared Sections (identical in both paths)

All of these are the same regardless of integration:

- Agent identity, mindset, primary objective
- Name collection & handling (spelling, first-name-only)
- Caller information & personalization (returning caller context, address instructions)
- Areas served + service area handling
- Triage section (symptom follow-ups)
- Address collection protocol (when `intakeQuestions` has address type)
- Intake steps (dynamic from `intakeQuestions`)
- Saving caller info (submit_intake_answers — mandatory)
- Trust & credentials, value props, property types
- Policies, promotions, FAQ, brands
- Business scope (from organization categories)
- Safety rules, escalation rules, guardrails
- Closing section (request_callback before end_call)
- Voice & behavior style

## 7. Testable Deltas (what to focus on)

Based on the above, here are the **GCal-specific behaviors** worth testing that don't exist in No Integration:

### High Priority (core GCal functionality)

1. **Check availability before booking** — agent uses `check_availability` with correct timezone
2. **Business hours validation** — agent rejects out-of-hours requests WITHOUT calling check_availability
3. **Create event with required fields** — summary, startDateTime, endDateTime/duration_minutes, timezone
4. **Email is REQUIRED** — agent must collect email, cannot skip it
5. **Duration communicated correctly** — agent uses configured default (not assumed 60 min)
6. **Buffer is automatic** — agent does NOT manually add buffer time to appointments
7. **Address + service area validation before booking** — same as no-integration, but gates event creation

### Medium Priority (returning caller / management flows)

8. **Cancel event** — security via phone matching, empathetic confirmation
9. **Reschedule event** — check availability for new time, phone verification
10. **Update event details** — change address/email/summary without changing time
11. **List events** — chronological display when asked "what do I have scheduled?"
12. **Returning caller skips intake** — uses pre-loaded name/email/address, no re-collection

### Low Priority (edge cases)

13. **"Next available" flow** — find first open slot within hours, wait for explicit confirmation
14. **Timezone always passed** — every GCal tool call includes `timeZone` param
15. **"Just leave a message"** → still uses `request_callback` (same as no-integration)
16. **No scheduling tools messaging** — no-integration says "I'll have someone reach out to schedule"; GCal never says this

### Already Covered by Existing Tests (`test_gcal_integration.py`)

Most of items 1–12 are already covered by the 32 tests. Items **10 (update details)**, **13 (next available)**, and **14 (timezone param)** are not yet tested.
