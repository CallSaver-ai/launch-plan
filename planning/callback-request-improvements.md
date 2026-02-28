# Callback Request Improvements Plan

**Date:** February 27, 2026
**Status:** Planning
**Related files:**
- `~/callsaver-api/prisma/schema.prisma` — CallbackRequest model
- `~/callsaver-api/livekit-python/tools/request_callback.py` — Python tool
- `~/callsaver-api/livekit-python/tools/__init__.py` — Tool registration + ToolContext
- `~/callsaver-api/src/server.ts` — `/internal/callback-request` (create), `/internal/agent-config` (prompt injection), `/me/callback-requests` (list/get/patch)

---

## 1. Current State Analysis

### 1.1 CallbackRequest Prisma Model

```prisma
model CallbackRequest {
  id           String      @id @default(uuid())
  locationId   String      @map("location_id")
  callRecordId String?     @map("call_record_id")
  callerPhone  String      @map("caller_phone")
  callerName   String?     @map("caller_name")     ← snapshot field (redundant)
  callerId     String?     @map("caller_id")        ← FK value exists, but NO relation defined
  reason       String
  summary      String?
  priority     String      @default("normal")
  status       String      @default("pending")       ← "pending" | "completed" | "cancelled"
  completedAt  DateTime?   @map("completed_at")
  completedBy  String?     @map("completed_by")
  notes        String?
  createdAt    DateTime    @default(now()) @map("created_at")
  updatedAt    DateTime    @updatedAt @map("updated_at")
  callRecord   CallRecord? @relation(fields: [callRecordId], references: [id])
  location     Location    @relation(fields: [locationId], references: [id], onDelete: Cascade)
  // ❌ NO relation to Caller — callerId is stored but not a Prisma relation
}
```

**Problems identified:**
1. `callerName` is a snapshot field — same anti-pattern we just eliminated from CallRecord
2. `callerId` is stored as a raw string with no Prisma relation to `Caller`
3. No `Caller.callbackRequests` inverse relation exists on the Caller model
4. No uniqueness/dedup constraint — multiple pending callback requests per caller are allowed

### 1.2 Python Tool (`request_callback.py`)

The `request_callback` tool:
- Accepts: `reason`, `caller_name` (optional, from LLM), `summary` (optional), `priority`
- Sends to API: `locationId`, `roomName`, `callerPhone`, `callerName`, `reason`, `summary`, `priority`
- Does **NOT** send `callerId` (even though `ToolContext` now has `call_record_id`)
- Does **NOT** check for existing pending callback requests
- Always creates a **new** callback request — no update capability

### 1.3 Node API Endpoint (`POST /internal/callback-request`)

The endpoint:
- Resolves `callRecordId` from `roomName` (LiveKit room lookup)
- Resolves `callerName` and `callerId` from Caller record by phone+org lookup
- Always creates a new `CallbackRequest` — no dedup check
- Sends push notification to business owner

### 1.4 Agent Config / System Prompt Injection

The `/internal/agent-config` endpoint builds `callerInfo` for the system prompt with:
- Name, phone number, email
- Addresses (CallerAddress records or FSM properties)
- Recent call summary + tool calls
- Calendar events (if Google Calendar connected)
- **❌ NO callback request information** — the agent has no idea if the caller already has a pending callback

### 1.5 Frontend

- `GET /me/callback-requests` — Lists all callback requests with status/priority filters
- `GET /me/callback-requests/:id` — Get single callback request
- `PATCH /me/callback-requests/:id` — Update status/notes (used by business owner to mark complete/cancel)
- `CallbacksPage.tsx` — Displays callback requests with call record details
- `callerName` on CallbackRequest is displayed directly (snapshot, not from Caller join)

---

## 2. Requirements

### 2.1 Agent Awareness of Pending Callbacks
The voice agent must be informed of any **pending** callback requests for the current caller, injected into the system prompt alongside existing caller info. The agent should be able to say things like "I see you already have a callback request pending" and act accordingly.

### 2.2 One Pending Callback Per Caller
Enforce that only one `pending` callback request can exist per caller at a time. If the agent tries to create a second one, the system should update the existing one instead.

### 2.3 Update Existing Callback Requests
The agent should be able to update the reason/summary of an existing pending callback request if the caller provides additional context on a subsequent call.

### 2.4 Proper Caller ↔ CallbackRequest Linkage
- Add a proper Prisma relation between `Caller` and `CallbackRequest` (FK + inverse)
- Derive `callerName` from the Caller join (same pattern as CallRecord)
- Stop writing the `callerName` snapshot field on creation

---

## 3. Proposed Design

### 3.1 Schema Changes (Migration 041)

**Add Caller ↔ CallbackRequest relation:**

```prisma
model CallbackRequest {
  // ... existing fields ...
  callerId     String?     @map("caller_id")
  // ADD: Proper relation to Caller
  caller       Caller?     @relation(fields: [callerId], references: [id])
  // ... existing relations ...
}

model Caller {
  // ... existing fields/relations ...
  callbackRequests  CallbackRequest[]   // ADD: inverse relation
}
```

**Add unique constraint for one-pending-per-caller:**

We can't use a simple `@@unique([callerId, status])` because:
- A caller can have multiple `completed` or `cancelled` requests (that's fine)
- We only want to enforce uniqueness for `pending` status

Options:
1. **Partial unique index** (Postgres-specific): `CREATE UNIQUE INDEX ... WHERE status = 'pending'`
2. **Application-level enforcement** in the API endpoint (upsert logic)

**Recommendation:** Use **both** — application-level upsert for the happy path, plus a partial unique index as a safety net.

```sql
-- Migration 041
-- Add Caller ↔ CallbackRequest FK constraint (column already exists, just needs the constraint)
ALTER TABLE "callback_requests"
  ADD CONSTRAINT "callback_requests_caller_id_fkey"
  FOREIGN KEY ("caller_id") REFERENCES "callers"("id") ON DELETE SET NULL;

-- Partial unique index: only one pending callback per caller
CREATE UNIQUE INDEX "callback_requests_caller_id_pending_unique"
  ON "callback_requests" ("caller_id")
  WHERE status = 'pending';
```

**Drop `callerName` snapshot column:**

Not yet — we'll keep the column for now since it has a different lifecycle than CallRecord names. The `callerName` on CallbackRequest also captures the name the caller gave *during that specific call* (which may differ from their Caller record name, e.g., a spouse calling). We can derive from the join on read but keep the write for now.

**Decision:** Keep `callerName` column but derive display name from Caller join in API responses. Update the value on creation (for audit trail), but prefer the join for display.

### 3.2 Agent Config: Inject Pending Callbacks into System Prompt

**In `/internal/agent-config` (server.ts), after building callerInfo:**

When we have a `callerId`, query for pending callback requests:

```typescript
// After caller lookup (~line 8994)
if (caller) {
  // Fetch pending callback requests for this caller
  const pendingCallbacks = await prisma.callbackRequest.findMany({
    where: {
      callerId: caller.id,
      status: 'pending',
    },
    select: {
      id: true,
      reason: true,
      summary: true,
      priority: true,
      createdAt: true,
    },
    orderBy: { createdAt: 'desc' },
    take: 1, // Should only be one due to constraint, but defensive
  });

  callerInfo.pendingCallbackRequest = pendingCallbacks[0] || null;
}
```

**In system prompt injection (~line 9224):**

Add a new section after the existing caller info:

```typescript
if (callerInfo?.pendingCallbackRequest) {
  const cb = callerInfo.pendingCallbackRequest;
  const cbDate = new Date(cb.createdAt).toLocaleString('en-US', {
    timeZone: timezone,
    weekday: 'long', month: 'long', day: 'numeric',
    hour: 'numeric', minute: 'numeric', hour12: true
  });

  const callbackSection = `\n\n📋 PENDING CALLBACK REQUEST:
This caller has an existing callback request that has not yet been completed:
- Reason: ${cb.reason}
- Summary: ${cb.summary || 'No summary provided'}
- Priority: ${cb.priority}
- Created: ${cbDate}
- Callback ID: ${cb.id}

**IMPORTANT — CALLBACK HANDLING**:
- Acknowledge the pending callback naturally: e.g., "I see you have a pending callback request from ${cbDate}."
- If the caller wants to add more details or change the reason, use the request_callback tool — it will UPDATE the existing request instead of creating a new one.
- If the caller says they already got a call back, let them know and proceed with their current need.
- Do NOT create a duplicate callback request. The system will automatically update the existing one.`;

  systemPrompt = systemPrompt + callbackSection;
}
```

### 3.3 API Endpoint: Upsert Instead of Always Create

**Modify `POST /internal/callback-request` to upsert:**

After resolving `callerId` (~line 12996), check for existing pending callback:

```typescript
// Check for existing pending callback for this caller
let existingPending = null;
if (resolvedCallerId) {
  existingPending = await prisma.callbackRequest.findFirst({
    where: {
      callerId: resolvedCallerId,
      status: 'pending',
    },
  });
}

if (existingPending) {
  // UPDATE existing pending callback request
  const updatedCallback = await prisma.callbackRequest.update({
    where: { id: existingPending.id },
    data: {
      // Update fields that may have changed
      reason,
      summary: summary || existingPending.summary,
      priority: priority !== 'normal' ? priority : existingPending.priority,
      callRecordId: callRecordId || existingPending.callRecordId,
      callerName: resolvedCallerName || existingPending.callerName,
    },
  });

  console.log(`📞 Updated existing callback request: ${updatedCallback.id}`);

  // Don't re-send push notification for updates (business already notified)

  return res.json({
    success: true,
    callbackRequestId: updatedCallback.id,
    updated: true,
    message: 'Existing pending callback request updated',
  });
}

// Otherwise, create new callback request (existing logic)
const callbackRequest = await prisma.callbackRequest.create({ ... });
```

**Response shape change:** Add `updated: boolean` so the Python tool can differentiate:
- `updated: false` → new callback created
- `updated: true` → existing pending callback updated

### 3.4 Python Tool: Updated Response Handling

**Modify `request_callback.py`** to handle the upsert response:

```python
result = response.json()
if result.get("success"):
    callback_id = result.get("callbackRequestId", "")
    was_updated = result.get("updated", False)

    if was_updated:
        return "I've updated your existing callback request with the new information. Someone from our team will call you back as soon as possible."
    else:
        return "I've noted your request. Someone from our team will call you back as soon as possible. Is there anything else I can help you with in the meantime?"
```

No new tool needed — the existing `request_callback` tool calls the same endpoint, which now handles upsert logic server-side. This is simpler than adding a separate `update_callback` tool because:
- The agent doesn't need to know the callback ID
- The server resolves the caller and finds the pending request automatically
- Fewer tool calls = less latency

### 3.5 API Responses: Derive callerName from Caller Join

**In `GET /me/callback-requests` (list endpoint):**

Add `caller` join to the query and derive `callerName`:

```typescript
const callbackRequests = await prisma.callbackRequest.findMany({
  where,
  include: {
    callRecord: { ... },
    caller: {                    // ADD
      select: {
        name: true,
        firstName: true,
        lastName: true,
        phoneNumber: true,
      },
    },
  },
});

// In response mapping:
callerName: cbr.caller?.name || cbr.callerName || null,
```

Same pattern for `GET /me/callback-requests/:id`.

---

## 4. Files to Change

| Layer | File | Change |
|-------|------|--------|
| Prisma | `schema.prisma` | Add `caller` relation on CallbackRequest, add `callbackRequests` on Caller |
| Migration | `041_callback_request_caller_relation/` | Add FK constraint + partial unique index |
| Node API | `src/server.ts` (`/internal/agent-config`) | Query pending callbacks, inject into system prompt |
| Node API | `src/server.ts` (`POST /internal/callback-request`) | Add upsert logic — update existing pending instead of creating duplicate |
| Node API | `src/server.ts` (`GET /me/callback-requests`) | Add caller join, derive callerName |
| Node API | `src/server.ts` (`GET /me/callback-requests/:id`) | Add caller join, derive callerName |
| Python | `livekit-python/tools/request_callback.py` | Handle `updated` response flag, adjust confirmation message |

---

## 5. Implementation Phases

### Phase 1: Schema + Relation (Migration 041)
1. Add `caller Caller? @relation(...)` to CallbackRequest model
2. Add `callbackRequests CallbackRequest[]` to Caller model
3. Write migration SQL: FK constraint + partial unique index
4. Run `prisma generate` + `prisma migrate deploy`

### Phase 2: Upsert Logic in API
1. Modify `POST /internal/callback-request` to check for existing pending callback
2. If found: update it, return `updated: true`
3. If not: create new (existing logic), return `updated: false`
4. Update Python tool response handling

### Phase 3: System Prompt Injection
1. In `/internal/agent-config`, query `CallbackRequest` where `callerId = caller.id AND status = 'pending'`
2. Add pending callback info to `callerInfo` object
3. Inject callback handling instructions into system prompt

### Phase 4: Derive callerName from Join
1. Add caller join to `GET /me/callback-requests` and `GET /me/callback-requests/:id`
2. Derive `callerName` from `caller?.name` (with fallback to snapshot)

---

## 6. Edge Cases

### Caller calls before callback is completed
- Agent sees pending callback in system prompt
- Acknowledges it: "I see you have a pending callback request..."
- If caller wants to update details → tool call → upsert updates existing
- If caller says they got a callback → business owner should mark it completed in dashboard

### Caller has no callerId (unknown caller)
- No dedup possible without callerId
- Falls through to "create new" path (existing behavior)
- Once caller is identified (e.g., via phone + org lookup), callerId is resolved

### Multiple locations
- The partial unique index is on `caller_id` only
- A caller could theoretically have pending callbacks at different locations
- This is acceptable — they're separate businesses with separate callback queues

### Business owner cancels callback, caller calls again
- Cancelled callback is not `pending`, so agent won't see it
- Agent can create a fresh pending callback — no conflict

### Race condition: two simultaneous calls from same caller
- Partial unique index prevents duplicate pending inserts at DB level
- Second insert would fail → catch → return existing pending callback
- Extremely unlikely edge case for phone calls

---

## 7. Testing Scenarios

1. **New caller, first callback** → creates new pending callback, agent gets confirmation
2. **Returning caller with pending callback** → system prompt shows callback info, agent acknowledges
3. **Caller updates pending callback** → tool call → upsert updates existing, returns "updated" message
4. **Callback completed by business** → next call shows no pending callback
5. **Callback cancelled** → next call shows no pending callback, agent can create new one
6. **Unknown caller (no callerId)** → creates callback without dedup, resolves on subsequent call
