# Plan: Triage Logic Enhancement + Tool Call State Management Rewrite

**Created:** Feb 26, 2026
**Scope:** Two independent features that can be implemented in parallel or sequentially.

---

## Feature 1: Triage Logic — Probing Vague Service Requests

### Problem

When a caller says something vague like "drain cleaning" or "I need plumbing help," the agent just says "ok" and moves on without gathering useful detail. The business owner then receives a bare-bones call summary with no context about the actual issue, urgency, or scope.

### Current State

- **Field service integrations (Jobber/HCP)** already have a "SYMPTOM TRIAGE — GATHERING DETAILS" section in `src/utils.ts` (lines 1693-1699) that instructs the agent to ask 1-2 follow-up questions about symptoms, duration, what they've tried, and affected area. This works well.
- **Google Calendar** and **No Integration** modes have **NO triage instructions**. The agent collects intake data (name, address, email) and books/submits, but never probes about the service need.
- The call summary generated from the transcript naturally reflects this gap — if the caller said "drain cleaning" and the agent said "ok", the summary just says "caller requested drain cleaning."

### Proposed Solution

Add a cross-integration **"SERVICE DETAIL TRIAGE"** section to the system prompt that applies to **all integration modes** (not just field service). This section instructs the agent to ask brief follow-up questions when the caller's service description is vague.

### Implementation

**File:** `src/utils.ts` — `generateSystemPrompt()` function

**Change:** Add a new `triageSection` variable that's included in the final prompt for ALL integration modes, inserted after the services section and before the workflow section.

```typescript
// New triage section — applies to ALL integration modes
const triageSection = `
SERVICE DETAIL TRIAGE — GATHERING USEFUL CONTEXT
When a caller describes their issue or service need, ask brief follow-up questions to capture useful detail for the business team. This makes the call summary significantly more valuable. Don't interrogate — keep it conversational and limit to 1-2 follow-ups based on what's missing:
- **What's happening?** If the request is vague (e.g., "drain cleaning", "plumbing help", "AC repair"), get the specific symptom: "Can you tell me a bit more about what's going on? For example, is the drain completely blocked, or is it draining slowly?"
- **How long / How urgent?** "How long has this been going on?" or "Is this something urgent, or more of a when-you-get-a-chance situation?" — helps the team prioritize.
- **Affected area?** "Is it just in one area, or multiple spots?" — helps scope the job.
- **What have you tried?** Only ask if relevant (e.g., for troubleshooting-type issues): "Have you tried anything so far?"

**WHEN TO PROBE vs WHEN NOT TO:**
- ✅ PROBE: Caller says "I need drain cleaning" → ask what's happening (slow drain? backup? smell?)
- ✅ PROBE: Caller says "plumbing help" → ask what specifically they need help with
- ✅ PROBE: Caller says "AC repair" → ask what the AC is doing (not cooling? making noise? leaking?)
- ❌ DON'T PROBE: Caller already gave detail ("My kitchen sink is backed up and overflowing onto the floor") → move to intake
- ❌ DON'T PROBE: Caller wants info only ("What are your hours?" / "Do you serve my area?")
- ❌ DON'T PROBE: Safety emergency (gas leak, flooding) → follow safety protocol immediately

Include all gathered details in the service description when saving caller information or creating service requests. The more context the business team has, the better they can prepare.
`;
```

**Where to insert in the final prompt assembly:**

The triage section should be added to the prompt for ALL integration modes. Currently:
- Field service (Jobber/HCP): Already has its own triage section in `workflowSection` — **replace** the existing "SYMPTOM TRIAGE" block with the new shared one (or keep both, since the FS version also covers commercial vs residential)
- Google Calendar: Add after `servicesSection`, before `workflowSection`
- No Integration: Add after `servicesSection`, before `workflowSection`
- Square Bookings: Add after `servicesSection`, before `workflowSection`

### Effort

- ~1-2 hours (prompt change + testing)
- Low risk — purely additive prompt instruction
- Test by calling with vague requests ("drain cleaning", "plumbing help", "AC issue") and verify the agent probes

### Verification

- Console mode test: Say "I need drain cleaning" — agent should ask a follow-up like "Can you tell me more about what's happening?"
- Console mode test: Say "My kitchen sink is backed up and overflowing" — agent should NOT probe further (already detailed)
- Check that the call summary includes the gathered details

---

## Feature 2: Tool Call State Management Rewrite

### Problem

Tool calls are currently appended to the `CallRecord.toolCalls` JSON column mid-conversation via HTTP POST (`/internal/call-records/append-tool-call`), then **overwritten** at end-of-call by the final `upload_call_data()` payload. This is:

1. **Redundant** — the final upload overwrites all incremental appends anyway
2. **Noisy** — each tool call fires an HTTP request to the Node API during the conversation
3. **Risk of inconsistency** — if the session ends abnormally, the incremental data is incomplete; if it ends normally, the incremental data is discarded

### Current Architecture

```
During call:
  on_function_tools_executed event fires
    → Appends to in-memory function_calls_tracker list
    → Fires asyncio.create_task(append_tool_call(room_name, call_data))
      → HTTP POST to /internal/call-records/append-tool-call
        → Node API reads existing toolCalls from DB, pushes new one, saves

End of call:
  on_session_end callback fires
    → Extracts function_calls_list from tracker (or session report fallback)
    → Calls upload_call_data(function_calls=function_calls_list)
      → HTTP POST to /internal/call-records/upload-data
        → Node API: updateData.toolCalls = functionCalls  ← OVERWRITES all incremental data
```

### Key Discovery: `session.history` Contains Everything

From the LiveKit Agents SDK, `session.history.items` contains the full conversation including tool calls:

```python
for item in session.history.items:
    if item.type == "function_call":
        # item.name, item.arguments
    elif item.type == "function_call_output":
        # item.name, item.output, item.is_error
```

The `ctx.make_session_report()` also includes `chat_history.items` with the same data. **The current code already falls back to this** (lines 260-266 in `server.py`) but prefers the manual tracker.

### Proposed Solution

**Remove mid-call appending entirely.** Use `session.history` at end-of-call as the single source of truth.

### Implementation Plan

#### Step 1: Python Agent — Remove `append_tool_call` calls

**File:** `livekit-python/server.py`

In the `on_function_tools_executed` handler (~line 1435-1437):

```python
# REMOVE this line:
asyncio.create_task(append_tool_call(room_name, call_data))
```

Keep the rest of the handler (tool-specific metadata extraction like `available`, `eventMetadata`, tool failure → auto-transfer). The `function_calls_tracker` list stays — it enriches tool calls with metadata that `session.history` doesn't have (like `available` for calendar checks and `eventMetadata` for calendar updates/cancels).

#### Step 2: Python Agent — Enrich tracker from `session.history` at end-of-call

**File:** `livekit-python/server.py` — `on_session_end` callback

The current extraction logic (lines 215-266) already handles this. No changes needed — it prefers `function_calls_tracker` (which has the enriched metadata) and falls back to `session.history` items.

#### Step 3: Node API — Remove `append-tool-call` endpoint

**File:** `src/server.ts` — lines 10059-10091

Remove (or deprecate with a 410 Gone response) the `/internal/call-records/append-tool-call` endpoint. It will no longer be called.

#### Step 4: Python Agent — Remove `append_tool_call` import

**File:** `livekit-python/api_client.py` — lines 173-199

Remove the `append_tool_call()` function entirely (or keep as dead code temporarily).

**File:** `livekit-python/server.py` — import line

Remove `append_tool_call` from the import statement.

#### Step 5: Frontend — No Changes Required

The frontend reads `callRecord.toolCalls` which is a JSON array. The `ToolCall` interface in `tool-call-formatters.tsx` expects:

```typescript
interface ToolCall {
  name: string;
  call_id: string;
  is_error: boolean;
  arguments: Record<string, unknown>;
  output: string;
  available?: boolean;
  eventMetadata?: Record<string, unknown>;
}
```

This shape is produced by the `function_calls_tracker` in the Python agent, which is what gets sent in the final `upload_call_data()` call. Since we're keeping the tracker (just removing the mid-call HTTP appends), the data shape doesn't change. **No frontend changes needed.**

### What About Abnormal Session Termination?

If the Python agent crashes before `on_session_end` runs:
- **Before this change:** Incremental appends would have partial tool calls in the DB
- **After this change:** No tool calls in the DB until `on_session_end` completes

Mitigation options:
1. **Accept the tradeoff** — abnormal terminations are rare, and the partial data from incremental appends was incomplete anyway (missing later tool calls, no final transcript/usage/recording)
2. **Add a periodic flush** — instead of per-tool-call HTTP posts, batch-flush every 60s (lower overhead, still provides some safety net). Not recommended unless data loss becomes a real issue.
3. **LiveKit Cloud Insights** — tool calls are already captured in LiveKit Cloud's Agent Insights timeline, providing a backup source even if our DB misses them.

**Recommendation:** Option 1 (accept the tradeoff). The incremental data was being overwritten anyway, so removing it doesn't change the normal-case behavior. For crashes, LiveKit Cloud Insights provides a backup.

### Effort

- ~2-3 hours
- Low risk — removing code is simpler than adding it
- The final `upload_call_data()` path is unchanged, so all normal-case behavior is preserved

### Files Modified

| File | Change | Risk |
|------|--------|------|
| `livekit-python/server.py` | Remove `asyncio.create_task(append_tool_call(...))` line + remove import | Low |
| `livekit-python/api_client.py` | Remove `append_tool_call()` function | Low |
| `src/server.ts` | Remove `/internal/call-records/append-tool-call` endpoint | Low |
| Frontend | **No changes** | None |

### Verification

- Make a test call on staging → verify tool calls appear in the dashboard after call ends
- Verify no 404s in agent logs (the append-tool-call endpoint is gone)
- Verify the tool call data shape in the DB matches what the frontend expects
- Verify the Recent Call cards and Call History cards render tool calls correctly

---

## Implementation Order

These two features are independent and can be done in either order:

| Order | Feature | Effort | Deploy |
|-------|---------|--------|--------|
| 1 | **Triage Logic** (prompt change) | 1-2 hours | Node API only (prompt generation) |
| 2 | **State Management** (remove mid-call appends) | 2-3 hours | Python agent + Node API |

**Total effort: ~3-5 hours**

The triage logic is lower risk and higher immediate value (every call becomes more informative), so it's recommended to do first. The state management rewrite is a clean simplification that reduces HTTP traffic during calls and eliminates a redundant code path.
