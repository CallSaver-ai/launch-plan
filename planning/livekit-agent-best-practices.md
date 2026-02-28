# LiveKit Agent Best Practices — Tool Interruptions, Verbal Feedback & Workflows

**Date:** February 26, 2025
**Status:** Recommendations (ready for implementation)
**Sources:** [LiveKit Agents Docs — Tool definition and use](https://docs.livekit.io/agents/logic/tools/), [External data and RAG](https://docs.livekit.io/agents/logic/external-data/), [Agent speech and audio](https://docs.livekit.io/agents/multimodality/audio/), [Tasks and task groups](https://docs.livekit.io/agents/logic/tasks/), [Workflows](https://docs.livekit.io/agents/logic/workflows/)

---

## 1. Tool Interruptions

### What LiveKit Says

> By default, tools **can be interrupted** if the user speaks. When interrupted, the tool's `asyncio.Task` is **cancelled** and the function call is removed from history.

Use `ctx.disallow_interruptions()` at the start of any tool that performs a **write operation or mutation**. If the user speaks mid-write, the cancellation could leave data in a partial state (e.g., customer created but property not linked).

**Read-only / idempotent tools** (check availability, get customer, list events) should remain interruptible — if the user corrects themselves mid-lookup, the cancellation is harmless and the agent can retry with the corrected input.

### Current State — All Integrations

#### ✅ Field Service Tools (Jobber / HCP) — Already Protected

All 11 write tools already call `ctx.disallow_interruptions()`:

| Tool | File | Protected |
|---|---|---|
| `fs_create_customer` | `fs_customer.py` | ✅ |
| `fs_update_customer` | `fs_customer.py` | ✅ |
| `fs_create_property` | `fs_property.py` | ✅ |
| `fs_create_service_request` | `fs_service_request.py` | ✅ |
| `fs_submit_lead` | `fs_service_request.py` | ✅ |
| `fs_create_assessment` | `fs_assessment.py` | ✅ |
| `fs_cancel_assessment` | `fs_assessment.py` | ✅ |
| `fs_reschedule_assessment` | `fs_assessment.py` | ✅ |
| `fs_create_appointment` | `fs_scheduling.py` | ✅ |
| `fs_reschedule_appointment` | `fs_scheduling.py` | ✅ |
| `fs_cancel_appointment` | `fs_scheduling.py` | ✅ |

#### ❌ Google Calendar Tools — NOT Protected

| Tool | File | Write? | Protected |
|---|---|---|---|
| `google_calendar_create_event` | `google_calendar_create_event.py` | ✅ Write | ❌ **Missing** |
| `google_calendar_cancel_event` | `google_calendar_cancel_event.py` | ✅ Write | ❌ **Missing** |
| `google_calendar_update_event` | `google_calendar_update_event.py` | ✅ Write | ❌ **Missing** |
| `google_calendar_check_availability` | `google_calendar_check_availability.py` | Read-only | N/A — leave interruptible |
| `google_calendar_list_events` | `google_calendar_list_events.py` | Read-only | N/A — leave interruptible |

#### ❌ Shared Tools — NOT Protected

| Tool | File | Write? | Protected |
|---|---|---|---|
| `submit_intake_answers` | `submit_intake_answers.py` | ✅ Write | ❌ **Missing** |
| `request_callback` | `request_callback.py` | ✅ Write | ❌ **Missing** |
| `transfer_call` | `transfer_call.py` | ✅ Write (SIP REFER) | ❌ **Missing** |
| `validate_address` | `validate_address.py` | Read-only | N/A — leave interruptible |

### Action Items

Add `ctx.disallow_interruptions()` as the first line inside the `try` block of each missing write tool. This is a one-line change per tool:

```python
# Example fix for google_calendar_create_event
try:
    ctx.disallow_interruptions()  # ← Add this line
    tool_context = None
    ...
```

**Files to update:**
1. `tools/google_calendar_create_event.py`
2. `tools/google_calendar_cancel_event.py`
3. `tools/google_calendar_update_event.py`
4. `tools/submit_intake_answers.py`
5. `tools/request_callback.py`
6. `tools/transfer_call.py`

**Effort:** ~15 minutes. One-line change per file.

---

## 2. Verbal Feedback for Long-Running Tool Calls

### What LiveKit Says

From the [External data and RAG](https://docs.livekit.io/agents/logic/external-data/) docs:

> Use Agent speech to provide verbal feedback to the user during a long-running tool call. The update is dynamically generated based on the query, and could be spoken only if the call takes longer than a specified timeout.

During a tool call, the caller hears **silence**. For calls that take 2+ seconds, this feels like the agent has frozen. A brief verbal update ("Just a moment while I get that set up for you...") dramatically improves the experience.

### `session.say()` vs `session.generate_reply()`

These are the two ways to make the agent speak during a tool call. They serve different purposes:

| | `session.say()` | `session.generate_reply()` |
|---|---|---|
| **What it speaks** | A **fixed, predefined string** you provide | A **dynamically generated** response from the LLM based on instructions |
| **LLM involved?** | ❌ No — goes straight to TTS | ✅ Yes — LLM generates text, then TTS synthesizes |
| **Latency** | Lower — skips LLM round-trip | Higher — requires LLM inference + TTS |
| **Added to chat context?** | ✅ Yes by default (`add_to_chat_ctx=True`) | ✅ Yes (the generated text is added, not the instructions) |
| **Use case** | Predictable status messages: "One moment please...", "Let me check on that..." | Dynamic, context-aware responses: "I'm looking up availability for next Tuesday..." |
| **`allow_interruptions`** | Configurable (default `True`) | Configurable (default `True`) |
| **Returns** | `SpeechHandle` | `SpeechHandle` |

**Recommendation for our use case:** Use `session.say()` for verbal feedback during tool calls. The messages are predictable ("Just a moment while I set that up...") and don't need LLM generation. This avoids the extra latency of an LLM round-trip while the actual tool call is in flight.

Use `session.generate_reply()` only when the verbal update should be **context-aware** (e.g., "I'm looking up availability for your plumbing repair on Tuesday morning..." where the content depends on what the caller just said).

### Recommended Pattern

```python
import asyncio

async def _maybe_say_status(session, message: str, work_task: asyncio.Task, timeout: float = 2.0):
    """Speak a status update if the tool call takes longer than timeout seconds."""
    await asyncio.sleep(timeout)
    if not work_task.done():
        await session.say(message, allow_interruptions=False)
```

Usage inside a tool:

```python
@function_tool()
async def google_calendar_create_event(ctx: RunContext, ...):
    ctx.disallow_interruptions()
    
    # Start the actual API call
    api_task = asyncio.create_task(_do_api_call(...))
    
    # If it takes > 2s, speak a status update
    status_task = asyncio.create_task(
        _maybe_say_status(ctx.session, "Just a moment while I book that for you...", api_task, timeout=2.0)
    )
    
    result = await api_task
    status_task.cancel()
    return result
```

### Which Tools Should Have Verbal Feedback

Prioritized by typical latency and user impact:

#### All Integrations (Shared Tools)

| Tool | Typical Latency | Verbal Update Message | Priority |
|---|---|---|---|
| `submit_intake_answers` | 0.5–1.5s | Usually fast enough — skip | Low |
| `request_callback` | 1–2s | "Let me set up a callback for you..." | Medium |
| `transfer_call` | 1–3s | Already uses `session.say()` for transfer message | ✅ Done |

#### Google Calendar

| Tool | Typical Latency | Verbal Update Message | Priority |
|---|---|---|---|
| `google_calendar_create_event` | 1–3s | "Just a moment while I book that appointment for you..." | **High** |
| `google_calendar_check_availability` | 1–3s | "Let me check what times are available..." | **High** |
| `google_calendar_update_event` | 1–2s | "One moment while I update your appointment..." | Medium |
| `google_calendar_cancel_event` | 1–2s | "Let me cancel that appointment for you..." | Medium |

#### Jobber / HCP (Field Service)

| Tool | Typical Latency | Verbal Update Message | Priority |
|---|---|---|---|
| `fs_create_service_request` | 2–4s | "Let me get that service request set up for you..." | **High** |
| `fs_submit_lead` | 2–3s | "One moment while I submit your information..." | **High** |
| `fs_create_customer` | 1–2s | "Let me get you set up in our system..." | Medium |
| `fs_create_property` | 1–2s | "Adding your service address..." | Medium |
| `fs_check_availability` | 1–3s | "Let me check what times are available..." | **High** |
| `fs_create_appointment` | 2–3s | "Booking that appointment for you now..." | **High** |
| `fs_reschedule_appointment` | 1–2s | "Let me reschedule that for you..." | Medium |
| `fs_create_assessment` | 1–2s | "Setting up your assessment..." | Medium |

**Effort:** ~1–2 hours. Create a shared `_maybe_say_status` helper in `tools/helpers.py` and add it to the high-priority tools first.

---

## 3. Tasks / Task Groups / Workflows

### What LiveKit Says

| Construct | Purpose | Lifetime |
|---|---|---|
| **Agent** | Long-lived conversational control, instructions, tools | Persists across session |
| **Task** (`AgentTask`) | Short-lived discrete operation with typed result (e.g., collect email, get consent) | Runs to completion, returns typed result |
| **TaskGroup** | Ordered multi-step flow with regression support (user can go back and correct earlier steps) | Coordinates multiple Tasks sequentially |
| **Tool** | Model-driven side effect (API call, handoff) | Single invocation |

Key guidance from the docs:

> "Use **tasks** for discrete operations that must complete before continuing the conversation (for example, consent collection, data capture, or verification)."

> "**Task groups** let you build complex, user-friendly workflows that mirror real conversational behavior — where users might need to revisit or correct earlier steps without losing context."

> ⚠️ `TaskGroup` is currently in `livekit.agents.beta.workflows` — the API might change in a future release.

### How Our Workflows Map to These Constructs

#### New Caller — No Integration / Google Calendar

Current approach: Single agent with system prompt instructions, sequential tool calls.

**TaskGroup equivalent:**

```
TaskGroup:
  1. CollectNameTask         → result: { name, firstName, lastName }
  2. CollectAddressTask      → result: { address, validated: bool }
  3. CollectEmailTask        → result: { email }  (already using GetEmailTask)
  4. CollectServiceDetailsTask → result: { serviceType, description, urgency }
  (GCal only)
  5. BookAppointmentTask     → result: { eventId, dateTime }
```

**Benefit:** If the caller says "actually, my name is spelled differently" during step 3, the TaskGroup automatically regresses to step 1 without complex prompt engineering. All tasks share conversation context.

#### New Caller — Jobber / HCP

Current approach: 7+ sequential fs-* tool calls orchestrated purely by the system prompt. This is the most complex workflow and the one most prone to LLM missteps (wrong IDs, skipped steps).

**TaskGroup equivalent:**

```
TaskGroup:
  1. LookupCustomerTask      → check if returning caller (fs-get-customer-by-phone)
  2. CreateCustomerTask       → create in Jobber/HCP (fs-create-customer)
  3. CollectAddressTask       → validate + create property (validate-address → fs-create-property)
  4. CollectServiceDetailsTask → service type, description, urgency
  5. CreateServiceRequestTask → submit to platform (fs-create-service-request)
  (If auto-schedule)
  6. CheckAvailabilityTask    → find open slots (fs-check-availability)
  7. BookAssessmentTask       → schedule assessment
```

**Benefit:** Shared context means IDs (customer_id, property_id) flow naturally between tasks without the LLM needing to remember them. Regression support means the caller can correct their address at step 5 without starting over.

#### Returning Caller — All Integrations

Current approach: Caller info injected into prompt, agent decides between re-use existing info vs update.

**Agent handoff equivalent:**

```
EntryAgent:
  → fs-get-customer-by-phone or check caller info
  → If returning caller: handoff to ReturningCallerAgent (has existing context)
  → If new caller: handoff to NewCallerAgent (starts intake TaskGroup)
```

**Benefit:** Separate agents with different instructions and tool sets for new vs returning callers, instead of one massive prompt trying to handle both paths.

### Should We Migrate Now?

**Honest assessment: Not yet for full TaskGroup migration, but start with targeted improvements.**

| Factor | Assessment |
|---|---|
| **TaskGroup stability** | Still in `beta.workflows` — API may change |
| **Current approach working?** | Mostly yes, but Jobber/HCP 7-step flow occasionally has LLM missteps |
| **Risk of migration** | Medium — requires restructuring all tool calls into Task classes |
| **GetEmailTask** | Already integrated correctly as a standalone AgentTask inside a function tool — this is the right pattern |

### Recommended Phased Approach

**Phase 1 (Now):** Apply interruption protection + verbal feedback improvements. These are quick wins that improve reliability and UX without architectural changes.

**Phase 2 (Short-term):** Continue using `GetEmailTask` as a model for standalone tasks. Consider creating similar standalone tasks for other discrete operations:
- `GetAddressTask` (collect + validate address)
- `GetNameTask` (collect + confirm name spelling)

These can be used inside `@function_tool` wrappers the same way `collect_email` works today.

**Phase 3 (When TaskGroup leaves beta):** Migrate the Jobber/HCP intake workflow first — it has the highest complexity (7 steps) and would benefit most from:
- Automatic regression support
- Shared context for IDs across steps
- Typed results flowing between tasks

The new/returning caller branching maps naturally to separate Agents with handoff based on `fs-get-customer-by-phone` result.

**Phase 4 (Future):** Migrate GCal and No Integration workflows to TaskGroup. These are simpler (3–5 steps) and work reasonably well with the current prompt-driven approach, so they're lower priority.

---

## 4. Implementation Checklist

### P0 — Tool Interruption Protection (~15 min)

- [ ] `tools/google_calendar_create_event.py` — add `ctx.disallow_interruptions()`
- [ ] `tools/google_calendar_cancel_event.py` — add `ctx.disallow_interruptions()`
- [ ] `tools/google_calendar_update_event.py` — add `ctx.disallow_interruptions()`
- [ ] `tools/submit_intake_answers.py` — add `ctx.disallow_interruptions()`
- [ ] `tools/request_callback.py` — add `ctx.disallow_interruptions()`
- [ ] `tools/transfer_call.py` — add `ctx.disallow_interruptions()`

### P1 — Verbal Feedback for Long-Running Tools (~1–2 hours)

- [ ] Create shared `_maybe_say_status()` helper (e.g., in `tools/helpers.py` or `tools/feedback.py`)
- [ ] Add verbal feedback to `google_calendar_create_event` (high priority)
- [ ] Add verbal feedback to `google_calendar_check_availability` (high priority)
- [ ] Add verbal feedback to `fs_create_service_request` (high priority)
- [ ] Add verbal feedback to `fs_submit_lead` (high priority)
- [ ] Add verbal feedback to `fs_check_availability` (high priority)
- [ ] Add verbal feedback to `fs_create_appointment` (high priority)
- [ ] Add verbal feedback to remaining medium-priority tools

### P2 — TaskGroup Design (Design Only)

- [ ] Monitor `livekit.agents.beta.workflows.TaskGroup` API stability
- [ ] Design Jobber/HCP intake TaskGroup (7-step flow)
- [ ] Design new vs returning caller Agent handoff pattern
- [ ] Prototype with a single integration before full rollout
