# Production Issues Investigation & Proposals

**Date:** February 27, 2026  
**Status:** Investigation complete — ready for implementation

---

## Issue 1: S3 Audio Egress Failure

### Symptoms

The most recent call (`cmm36ubye002bpw01y51nc0ln`) shows:
- Egress started successfully (`EGRESS_ACTIVE`)
- Polled 10 times (2s intervals = 20s total wait), never reached `EGRESS_COMPLETE`
- Gave up → fell through to Method 2 → picked up the **local temp file** path `/tmp/tmpl2owiaic/audio.ogg`
- That local `/tmp` path was stored as `recordingUrl` in the CallRecord
- Frontend displays the unusable `/tmp` path

### Root Cause

**The egress is still actively recording when we start polling.** The room is still open (participant hasn't fully disconnected yet, or the egress service is still finalizing the file upload to S3). Our 20-second polling window (10 × 2s) is not enough for the egress to finish encoding + uploading.

The fallback logic (Method 2) then finds `audio_recording_path` in the session report, which is always the **local agent temp file** — never an S3 URL. This gets stored as the `recordingUrl`, which is completely wrong for production.

### What LiveKit Docs Say

From `/deploy/observability/data/`:
- **LiveKit Cloud automatically records audio** and uploads to Cloud for playback in Agent Insights — no custom egress needed for basic audio recording.
- For **custom S3 egress**, the docs show starting a `RoomCompositeEgressRequest` at agent join time (which we do correctly).
- The docs do **not** show polling — they assume the egress completes with the room lifecycle.

From `/transport/media/ingress-egress/egress/composite-recording/`:
- RoomComposite egress is **tied to room lifecycle** — when all participants leave, recording stops automatically.
- Audio-only composite supports **dual channel recording** to separate agent from caller audio.

### Proposed Fix

#### A. Stop the egress explicitly before polling

Instead of just polling, **stop the egress** when the call ends, then poll for completion:

```python
# In session_end handler, BEFORE polling:
lkapi = api.LiveKitAPI()
await lkapi.egress.stop_egress(api.StopEgressRequest(egress_id=egress_id))
# THEN poll for EGRESS_COMPLETE
```

This triggers the egress service to finalize the file and upload to S3. Polling after an explicit stop should resolve within a few seconds.

#### B. Increase poll timeout + exponential backoff

Change from 10 × 2s (20s) to 15 × 3s (45s) with exponential backoff. Some egress uploads (especially longer calls) take longer.

#### C. Never store `/tmp` paths as recording URLs

Add a guard: if the resolved URL doesn't start with `http://`, `https://`, or `s3://`, do NOT store it. Log a warning instead. This prevents the frontend from ever showing a broken local path.

```python
# In Method 2 fallback:
if audio_recording_path and not audio_recording_path.startswith(('/tmp', '/var')):
    audio_recording_url = audio_recording_path
```

#### D. Fallback: upload the local file to S3 manually

If the egress truly fails but we have a local `/tmp` file, upload it to S3 ourselves using boto3 as a last resort. The Node API `upload-data` endpoint already has this logic for non-S3 URLs (it calls `uploadRecordingToS3`), but the Python agent sends the raw path before the Node API can do anything useful with it.

```python
# In Method 2, if we have a /tmp path:
if audio_recording_path and os.path.exists(audio_recording_path):
    # Upload to S3 directly from the agent
    import boto3
    s3 = boto3.client('s3')
    s3_key = f"recordings/{room_name}.ogg"
    s3.upload_file(audio_recording_path, aws_bucket, s3_key)
    audio_recording_url = f"https://{aws_bucket}.s3.{aws_region}.amazonaws.com/{s3_key}"
```

### Recommended Implementation Order

1. **C** (guard against `/tmp` paths) — immediate, prevents broken URLs
2. **A** (explicit `stop_egress`) — fixes the root cause
3. **B** (longer timeout) — safety net
4. **D** (manual S3 upload fallback) — last resort for edge cases

---

## Issue 2: Transcript Stored as Raw String

### Current State

**Python agent** (`server.py:224-277`) builds the transcript as:
```
Assistant: Hello, thanks for calling...
User: Yeah, I was wondering...
Assistant: I'm sorry, but...
```

This raw string is sent to `POST /internal/call-records/upload-data` and stored directly in `CallRecord.transcript` (Prisma `String?` field).

**Frontend** has `parseTranscript()` duplicated in **4 files** that parse this string back into `{ role, content }[]`:
- `DashboardPage.tsx` (line 622)
- `CallerDetailPage.tsx` (line 111)
- `CallbacksPage.tsx` (line 98)
- `CallRecordDetailPage.tsx` (line 104)

Each has slightly different parsing logic (some handle `Agent:`, `Caller:`, `Customer:` prefixes; others don't). This is fragile.

### Proposed Fix

#### A. Store structured JSON in a new column

Add a `transcriptMessages` JSON column to `CallRecord`:

```prisma
model CallRecord {
  // existing
  transcript          String?    // keep for backward compat / search
  transcriptMessages  Json?      // new: structured array
}
```

The structured format:
```json
[
  { "role": "assistant", "content": "Hello, thanks for calling...", "timestamp": 1772180503.7 },
  { "role": "user", "content": "Yeah, I was wondering...", "timestamp": 1772180507.2 },
  ...
]
```

#### B. Build structured transcript in Python agent

In `server.py`, build both the raw string (for backward compat/search) AND the structured array from `history_items`:

```python
transcript_messages = []
for item in history_items:
    if item.get('type') == 'message':
        role = item.get('role', 'unknown')
        content = # ... existing extraction logic ...
        if content:
            transcript_messages.append({
                "role": role,
                "content": content,
                "timestamp": item.get('timestamp')  # if available
            })

# Send both to the API
payload["transcript"] = "\n".join(transcript_parts)  # keep raw string
payload["transcriptMessages"] = transcript_messages    # add structured
```

#### C. Update Node API to accept and store both

In `POST /internal/call-records/upload-data`, accept `transcriptMessages` and store it:

```typescript
if (transcriptMessages !== undefined) {
  updateData.transcriptMessages = transcriptMessages;
}
```

#### D. Update frontend to prefer structured data

In the calls API response, return `transcriptMessages` alongside `transcript`. Frontend pages use `transcriptMessages` if available, falling back to `parseTranscript(transcript)` for old records:

```tsx
const messages = call.transcriptMessages ?? parseTranscript(call.transcript);
```

Consolidate the 4 duplicated `parseTranscript` functions into a single shared utility in `src/lib/transcript-utils.ts`.

#### E. Prisma migration

```sql
ALTER TABLE "CallRecord" ADD COLUMN "transcriptMessages" JSONB;
```

### Files to Change

| Layer | File | Change |
|-------|------|--------|
| Python agent | `server.py` | Build `transcript_messages` array alongside raw string |
| Python agent | `api_client.py` | Add `transcriptMessages` to upload payload |
| Node API | `src/server.ts` (~10234) | Accept and store `transcriptMessages` |
| Node API | `src/contracts/internal-api.contract.ts` | Add `transcriptMessages` to schema |
| Node API | Calls list endpoint | Return `transcriptMessages` in response |
| Prisma | `schema.prisma` | Add `transcriptMessages Json?` to CallRecord |
| Frontend | `src/lib/transcript-utils.ts` | New shared `parseTranscript()` utility |
| Frontend | `DashboardPage.tsx` | Use structured data, remove local `parseTranscript` |
| Frontend | `CallerDetailPage.tsx` | Use structured data, remove local `parseTranscript` |
| Frontend | `CallbacksPage.tsx` | Use structured data, remove local `parseTranscript` |
| Frontend | `CallRecordDetailPage.tsx` | Use structured data, remove local `parseTranscript` |

---

## Issue 3: `collect_email` Tool Failure (GetEmailTask)

### Symptoms

```json
{
  "name": "collect_email",
  "output": "Could not collect email address: 'AgentSession' object has no attribute 'chat_ctx'. Ask the caller to try again.",
  "is_error": false
}
```

The `GetEmailTask` tried to access `context.session.chat_ctx` which doesn't exist as a direct attribute on `AgentSession`.

Despite this, `submit_intake_answers` succeeded at collecting the email (`alex@sikand.org`) because the **main agent** (not the sub-task) was able to collect it through normal conversation.

### Analysis of GetEmailTask

From the LiveKit source code (`livekit/agents/beta/workflows/email_address.py`):

- **Beta quality** — in `livekit.agents.beta.workflows`
- It's an `AgentTask` (sub-agent) that takes over the conversation temporarily
- Has its own internal tools: `update_email_address`, `confirm_email_address`, `decline_email_capture`
- Handles voice-to-text normalization (dot → `.`, at → `@`, spelled letters, etc.)
- The `chat_ctx` parameter is **optional** — if omitted, runs with empty context

**The error** `'AgentSession' object has no attribute 'chat_ctx'` indicates a version mismatch. Our `collect_email.py` passes `chat_ctx=context.session.chat_ctx`, but in the installed SDK version, the session object uses a different attribute name (likely `context.session.chat_context` or the property was renamed).

### Our collect_email.py Implementation

```python
result = await GetEmailTask(
    chat_ctx=context.session.chat_ctx,
    extra_instructions="After capturing the email, read it back to the caller once to confirm.",
)
```

### Do We Need GetEmailTask?

**Pros of keeping GetEmailTask:**
- Handles noisy voice-to-text normalization (dot, underscore, dash, at → symbols)
- Recognizes spelled-out patterns ("j-o-h-n at gmail dot com")
- Built-in email validation regex
- Handles confirmation flow automatically

**Cons:**
- **Beta** — API is unstable (we hit a breaking change)
- Creates a sub-agent that briefly takes over the conversation — can be jarring
- Our `submit_intake_answers` already collects email just fine through normal conversation
- The main agent's LLM (GPT-4.1) already handles email normalization reasonably well
- Adds complexity for marginal benefit

### Recommendation: Drop GetEmailTask, use submit_intake_answers

The main agent already successfully collected the email in this call despite `collect_email` failing. The `submit_intake_answers` tool accepts an `email` parameter directly. The system prompt already instructs the agent to collect email during intake.

**Proposed changes:**

1. **Remove `collect_email` tool** from `tools/collect_email.py` and `tools/__init__.py`
2. **Remove `collect-email` from server.ts** tool registration (Node API side)
3. **Update system prompt** to remove references to the `collect_email` tool — the agent should ask for the email directly and pass it to `submit_intake_answers`
4. **Update test mocks** in `conftest.py` to remove `collect_email` mock
5. **Update test prompts** in `prompts.py` to reflect the agent asking for email directly

**Alternative (if we want to keep voice normalization):** Fix the `chat_ctx` attribute error by removing the `chat_ctx` parameter (let GetEmailTask run with empty context), or pin the SDK version. But this doesn't address the fundamental fragility of depending on a beta API.

### Files to Change

| File | Change |
|------|--------|
| `livekit-python/tools/collect_email.py` | Delete or keep as dead code |
| `livekit-python/tools/__init__.py` | Remove `collect_email` import and registration |
| `livekit-python/server.py` | Remove `collect-email` from tool list |
| `src/server.ts` | Remove `collect-email` from tool names sent to agent |
| `src/utils.ts` | Update prompt to not reference collect_email tool |
| `livekit-python/tests/conftest.py` | Remove `collect_email` mock tool |
| `livekit-python/tests/prompts.py` | Update email collection instructions |

---

## Issue 4: Frontend Tool Call Logo Rendering

### Current State

In both `DashboardPage.tsx` and `CallerDetailPage.tsx`, tool calls show logos based on type:

| Tool | Logo | Status |
|------|------|--------|
| Google Calendar tools | Google Calendar icon | ✅ Working |
| `validate_address` | Google Maps icon | ✅ Working |
| `fs_*` (field service) | Jobber/HCP icon | ✅ Working |
| `submit_intake_answers` | CallSaver logo | ✅ Working |
| `request_callback` | CallSaver logo | ✅ Working |
| `transfer_call` | CallSaver logo | ✅ Working |
| **`collect_email`** | No logo | ❌ Missing |
| **`end_call`** | No logo | ❌ Missing |

The `isCallSaverNativeTool()` function in `tool-call-formatters.tsx` (line 265) only checks for:
- `submit_intake_answers` / `submit-intake-answers`
- `request_callback` / `request-callback`
- `transfer_call` / `transfer-call`

It does **not** include `collect_email`, `end_call`, or `warm_transfer`.

### Proposed Fix

Update `isCallSaverNativeTool()` in `src/lib/tool-call-formatters.tsx`:

```tsx
export const isCallSaverNativeTool = (functionName: string | undefined): boolean => {
  return (
    isSubmitIntakeTool(functionName) ||
    isRequestCallbackTool(functionName) ||
    isTransferCallTool(functionName) ||
    isCollectEmailTool(functionName) ||
    isEndCallTool(functionName) ||
    isWarmTransferTool(functionName)
  );
};
```

Add the missing helper functions:

```tsx
export const isCollectEmailTool = (functionName: string | undefined): boolean => {
  if (!functionName) return false;
  const name = functionName.toLowerCase();
  return name === 'collect_email' || name === 'collect-email';
};

export const isEndCallTool = (functionName: string | undefined): boolean => {
  if (!functionName) return false;
  const name = functionName.toLowerCase();
  return name === 'end_call' || name === 'end-call';
};

export const isWarmTransferTool = (functionName: string | undefined): boolean => {
  if (!functionName) return false;
  const name = functionName.toLowerCase();
  return name === 'warm_transfer' || name === 'warm-transfer';
};
```

Also add display names to the `TOOL_NAME_MAP` in both `DashboardPage.tsx` and `CallerDetailPage.tsx`:

```tsx
'collect_email': 'Collect Email',
'collect-email': 'Collect Email',
'end_call': 'End Call',
'end-call': 'End Call',
'warm_transfer': 'Warm Transfer',
'warm-transfer': 'Warm Transfer',
```

**Note:** If we drop `collect_email` (Issue 3), we can skip adding that one, but `end_call` and `warm_transfer` should still be added regardless.

### Files to Change

| File | Change |
|------|--------|
| `src/lib/tool-call-formatters.tsx` | Add `isCollectEmailTool`, `isEndCallTool`, `isWarmTransferTool`; update `isCallSaverNativeTool` |
| `src/pages/DashboardPage.tsx` | Add display names to `toolNameMap` |
| `src/pages/CallerDetailPage.tsx` | Add display names to `TOOL_NAME_MAP` |

---

## Summary & Priority

| # | Issue | Severity | Effort | Recommendation |
|---|-------|----------|--------|----------------|
| 1 | S3 egress failure → `/tmp` path stored | **Critical** | Medium | Guard against `/tmp` paths immediately; add explicit `stop_egress`; increase timeout |
| 2 | Transcript as raw string | Medium | Medium | Add `transcriptMessages` JSON column; build structured data in Python; consolidate frontend parsers |
| 3 | `collect_email` / GetEmailTask failure | **High** | Low | Drop GetEmailTask entirely; rely on `submit_intake_answers` for email collection |
| 4 | Missing tool logos | Low | Low | Add `end_call`, `collect_email`, `warm_transfer` to `isCallSaverNativeTool()` |
