# Caller Data Architecture: Issues, Analysis, and Design Plan

> **Created**: Feb 27, 2026  
> **Status**: Planning (not yet implemented)  
> **Related**: `docs/plans/RETURNING_CALLER_AND_MULTI_ADDRESS_PLAN.md`

---

## Table of Contents

1. [Active Bugs](#1-active-bugs)
2. [Architecture Analysis: Address Data](#2-architecture-analysis-address-data)
3. [Architecture Analysis: Name Data](#3-architecture-analysis-name-data)
4. [Multi-Address Flow by Platform](#4-multi-address-flow-by-platform)
5. [Proposed Design: Single Source of Truth](#5-proposed-design-single-source-of-truth)
6. [Implementation Plan](#6-implementation-plan)

---

## 1. Active Bugs

### Bug 1: `callerAddress` is null on CallRecord

**Symptom**: The CallerDetails page shows the address correctly (from `CallerAddress` table), and the `submit_intake_answers` tool reports success, but the calls endpoint returns `callerAddress: null`.

**Root cause**: The `submit_intake_answers` Python tool has `call_record_id` as an **LLM-provided parameter**. The LLM has no way to know the call record ID, so it never passes it:

```json
{
    "name": "submit_intake_answers",
    "arguments": {
        "name": "Alex Sikand",
        "address": "2101 Vine Hill Road, Santa Cruz, 95065"
    }
}
```

In the backend (`/internal/intake-answers`), the `CallRecord.callerAddress` field is only set when `callRecordId` is provided:

```typescript
// server.ts ~line 10928
if (callRecordId) {
  const callRecordUpdate: any = { callerId: caller.id };
  if (addressResult) {
    callRecordUpdate.callerAddress = addressResult.address;
  }
  await prisma.callRecord.updateMany({
    where: { id: callRecordId, locationId },
    data: callRecordUpdate,
  });
}
```

No `callRecordId` → the address is saved to `CallerAddress` table but never written to `CallRecord.callerAddress`.

**Fix**: Store `callRecordId` in `ctx.proc.userdata` after `log_call_start` returns it. Have the `submit_intake_answers` tool automatically include it from ToolContext — don't rely on the LLM.

**Files**:
- `livekit-python/server.py` — store callRecordId in ToolContext after log_call_start
- `livekit-python/tools/__init__.py` — add `call_record_id` to `ToolContext` dataclass
- `livekit-python/tools/submit_intake_answers.py` — auto-include callRecordId from ToolContext

---

### Bug 2: `successEvaluation` is null on CallRecord

**Symptom**: Call summary is populated but `successEvaluation` is null.

**Root cause (immediate)**: The summarization queue worker generates both `summary` and `successEvaluation`. If the evaluation LLM call throws (caught silently), `successEvaluation` stays null while `summary` still gets set.

**Root cause (critical, post-deploy)**: The summarization job is queued from `upload-data` using the raw `transcript` string:

```typescript
// server.ts ~line 10362
if (transcript && transcript.trim() && !updatedCallRecord.summary) {
  await callSummarizationQueue.add('summarize-call', {
    callRecordId: updatedCallRecord.id,
    transcript: transcript,
    endedReason: endedReason || null,
  });
}
```

We recently refactored `upload-data` to use `transcriptMessages` (structured array) instead of `transcript` (raw string). After deploy, `transcript` will be `undefined`, the condition `transcript && transcript.trim()` will be false, and **the summarization job will never be queued**. Both `summary` AND `successEvaluation` will be null for all future calls.

**Fix**: Convert `transcriptMessages` array to a string for the summarization queue, or update the worker to accept the structured array.

**Files**:
- `src/server.ts` — upload-data endpoint: derive transcript string from transcriptMessages for the summarization queue

---

### Bug 3: Egress (S3 recording upload) failing

**Symptom**: `recordingUrl` contains a local `/tmp/` path instead of an S3 URL. Egress status shows `EGRESS_ABORTED`.

**Root cause**: `EndCallTool` with `delete_room=True` kills the LiveKit room before egress can finalize and upload to S3.

**Sequence**:
1. LLM calls `end_call` → goodbye message plays
2. After speech finishes → `ctx.session.shutdown()`
3. Session `close` event fires → **two things race**:
   - Our `session_end` handler starts stopping egress and polling for completion
   - `EndCallTool._on_session_close` runs → calls `job_ctx.shutdown()` which adds room deletion to shutdown callbacks
4. `job_ctx.shutdown()` triggers callbacks → `job_ctx.delete_room()` runs
5. Room deletion **immediately aborts all active egresses**
6. Our polling sees `EGRESS_ABORTED` or a `/tmp/` scratch file

**Before EndCallTool**: Calls ended when the caller hung up. The room stayed alive long enough for egress to finalize naturally.

**After EndCallTool with `delete_room=True`**: The room is killed programmatically during shutdown, racing against egress finalization.

**Proof**: `recordingUrl: "/tmp/tmp6ybzuz2e/audio.ogg"` — a local egress scratch file that never got uploaded to S3.

**Fix**: Set `delete_room=False` on `EndCallTool`. In our `session_end` handler, after egress finalization completes, delete the room ourselves to hang up the SIP caller.

**Files**:
- `livekit-python/server.py` — EndCallTool: `delete_room=False`
- `livekit-python/server.py` — session_end handler: delete room after egress completes

---

## 2. Architecture Analysis: Address Data

### Two Address Storage Mechanisms

**`CallerAddress` model** (`caller_addresses` table):
- Links to `Caller` via `callerId` (FK)
- Stores full address details: address, street, city, state, zipCode, isPrimary, label
- Plus RentCast property enrichment: propertyType, bedrooms, bathrooms, squareFootage, yearBuilt
- Unique constraint: `@@unique([callerId, address])` — deduplicates
- Supports **multiple addresses per caller**

**`CallRecord.callerAddress`** (column on `call_records` table):
- A plain `String?` field
- Meant to capture "which address was discussed on THIS specific call"
- Currently **never set** (Bug 1 above)
- Returned by both `/me/calls` and `/call-records` API endpoints

### Role of CallerAddress by Integration Type

| | No Integration / Google Calendar | FSM (Jobber / HCP) |
|---|---|---|
| **Source of truth for voice agent** | ✅ `CallerAddress` — injected into system prompt | ❌ FSM platform (properties/addresses on client/customer) |
| **System prompt address data** | From `CallerAddress` records | From `callerInfo.fsProperties` (stripped from CallerAddress at line 9126-9129 of server.ts) |
| **CallerAddress records exist?** | ✅ Yes — created by `submit_intake_answers` | ✅ Yes — synced by `create-customer` and `create-property` backend endpoints |
| **CallerAddress purpose** | Primary store + voice agent reads | Local cache for dashboard display + RentCast enrichment |
| **New address created via** | `submit_intake_answers(address=...)` | `fs_create_property(customer_id, address)` or `fs_submit_lead(...)` |

**Key insight**: `CallerAddress` is a **universal local cache** of addresses. For generic/GCal
it's the source of truth that the voice agent reads. For FSM it's a synced mirror that the
dashboard reads. The voice agent never reads CallerAddress for FSM — it reads from the platform.

### Should We Keep Syncing FSM → CallerAddress?

**Yes. Recommendation: keep the existing sync.** Reasons:

1. **CallerDetails dashboard page** — shows addresses from `CallerAddress` regardless of
   integration type. Without sync, FSM callers would show no addresses.
2. **RentCast property enrichment** — `propertyType`, `bedrooms`, `bathrooms`, `squareFootage`,
   `yearBuilt` are populated via RentCast when a `CallerAddress` is created. This data doesn't
   exist in Jobber or HCP — it's our own value-add for the dashboard.
3. **Platform migration resilience** — if a business switches from Jobber → HCP or drops FSM,
   caller address history is preserved in our system.
4. **Cost** — essentially zero. A single `prisma.callerAddress.upsert()` that's already written,
   wrapped in try/catch, deduplicated by the `@@unique([callerId, address])` constraint.

### Why Both CallerAddress and CallRecord.callerAddress Exist

These serve different purposes:
- **`CallerAddress`**: Identity data — all addresses associated with a caller (persists across calls)
- **`CallRecord.callerAddress`**: Call-specific context — which address THIS call was about

A caller with 3 properties might call about a different one each time.
`CallRecord.callerAddress` captures that per-call context. This is a legitimate field to keep.

### The Problem

`CallRecord.callerAddress` is never populated because `callRecordId` isn't passed through
during the call. The fix (Bug 1) resolves this for non-FSM. Phase 3 extends to FSM.

For **FSM locations**: `fs_create_property` and `fs_create_customer` both sync addresses back
to `CallerAddress` (lines 464-505 and 263-310 of `field-service-tools.ts`), but neither sets
`CallRecord.callerAddress` because they don't have `callRecordId`.

---

## 3. Architecture Analysis: Name Data

### Current State: Redundant Name Storage

**On `Caller`**: `name`, `firstName`, `lastName` — the authoritative caller identity.

**On `CallRecord`**: `callerName`, `callerFirstName`, `callerLastName` — snapshot fields, set by the **summarization worker** post-call (not by tools during the call).

### How Names Are Currently Populated

| Path | Sets Caller record? | Sets CallRecord snapshot? |
|---|---|---|
| `submit_intake_answers` (generic) | ✅ Yes — `Caller.name/firstName/lastName` | ❌ No |
| `fs_create_customer` (FSM) | ✅ Yes — upserts `Caller` with name + externalCustomerId | ❌ No |
| `/internal/agent-config` (FSM pre-load) | ✅ Indirectly (Caller may already exist from previous call) | ❌ No |
| Summarization worker (post-call) | ✅ Creates/links Caller by phone | ✅ Copies `Caller.name` → `CallRecord.callerName` |

The summarization worker is the **only** code path that populates `callerName` on CallRecord. It does this by:
1. Finding/creating a `Caller` record from the phone number
2. Copying `Caller.name`, `firstName`, `lastName` → `CallRecord.callerName`, etc.

### The Problem

This is redundant and fragile:
- `CallRecord` already has `callerId` (FK to `Caller`) and **both API endpoints already join** `Caller`:
  - `call-records-router.ts` line 74: `include: { caller: true }`
  - `server.ts` `/me/calls` line 5396: `caller: { select: { id, phoneNumber, name, flaggedSpam } }`
- But `callerName` is still read from the **snapshot** (`record.callerName`) instead of the join (`record.caller?.name`)
- If the caller corrects their name on a later call, old CallRecords show the stale snapshot name
- The summarization worker does unnecessary work copying fields that should be derived from the join

### Design Decision

**Derive name from the Caller join. Stop writing snapshot fields.**

```typescript
// Instead of:
callerName: record.callerName,

// Do:
callerName: record.caller?.name || null,
callerFirstName: record.caller?.firstName || null,
callerLastName: record.caller?.lastName || null,
```

This is backward-compatible (same API response shape) and eliminates the sync issue entirely. The summarization worker stops copying name fields and just focuses on linking `callerId` and generating `summary`/`successEvaluation`.

---

## 4. Multi-Address Flow by Platform

### Generic / Google Calendar (no FSM)

**System prompt generation** (`server.ts` lines 9235-9310):

| Scenario | System prompt instruction |
|---|---|
| New caller (no addresses) | "No address on file. If needed for service, collect their full street address." |
| Returning caller, 1 address | "I have your address as {addr}. Is this call for that location?" — confirm, don't re-ask |
| Returning caller, 2+ addresses | "I see you have a few addresses on file. Which one is this call about?" |

**Adding a new address**:
1. Agent asks about address → caller gives new address
2. Agent calls `validate_address` → normalized address returned
3. Agent calls `submit_intake_answers(address="normalized address")`
4. Backend creates new `CallerAddress` record (first address is auto-primary)
5. Backend sets `CallRecord.callerAddress` (if `callRecordId` provided — **Bug 1**)
6. Next call: system prompt shows both addresses

**Selecting existing address** (returning caller):
1. System prompt lists addresses with IDs
2. Caller confirms or picks one
3. Agent calls `submit_intake_answers(address_id="existing-id")`
4. Backend looks up `CallerAddress` by ID, sets `CallRecord.callerAddress`

### FSM (Jobber / HCP)

**System prompt generation** (`server.ts` lines 9100-9176):

When FSM is active, **our CallerAddress records are stripped** from the prompt:
```typescript
callerInfo.address = null;
callerInfo.addresses = [];
```
They're replaced with **FSM properties** (from Jobber/HCP):
```typescript
callerInfo.fsCustomerId = customer.id;
callerInfo.fsProperties = customer.properties;
```

| Scenario | System prompt instruction |
|---|---|
| New customer (not in FSM) | No properties. Agent collects info, calls `fs_create_customer` + `fs_create_property` |
| Returning customer, 1 property | "I have your address as {addr}. Is this where you need service?" — confirm with property_id |
| Returning customer, 2+ properties | "Which property is this for?" — pick property_id or collect new address |

**Adding a new address (FSM)**:
1. Caller mentions new address → agent validates → checks service area
2. Agent calls `fs_create_property(customer_id, address)` → creates in Jobber/HCP
3. Backend also syncs to `CallerAddress` (field-service-tools.ts line 464-505)
4. But **does NOT set** `CallRecord.callerAddress` (no callRecordId)

### FSM Tool Address Creation: Two Paths

**Path 1: Separate steps** (granular, existing customer or multi-step flow):
1. `fs_create_customer(first_name, last_name)` — **no address param** on Python tool
2. `fs_create_property(customer_id, street, city, state, zip_code)` — creates property separately
3. `fs_create_service_request(customer_id, description, property_id=...)` — links property

Note: The backend `create-customer` endpoint and HCP adapter both accept an `address` field
and can create a customer with an inline address. But the Python `fs_create_customer` tool
doesn't expose this parameter, so the agent always uses `fs_create_property` separately.

**Path 2: `fs_submit_lead`** (all-in-one for new callers):
- Single tool call: name + address + service description
- Backend orchestrates: create customer → create property → create service request
- Preferred path for new callers (fewer tool calls, less latency)

| Tool | Customer | Address/Property | Service Request |
|---|---|---|---|
| `fs_create_customer` | ✅ | ❌ (not exposed) | ❌ |
| `fs_create_property` | ❌ | ✅ | ❌ |
| `fs_create_service_request` | ❌ | ❌ | ✅ |
| **`fs_submit_lead`** | ✅ | ✅ | ✅ |

Both `fs_create_property` backend and `fs_create_customer` backend (when address provided)
sync back to `CallerAddress`. The `submit-lead` backend also syncs via its internal
`createCustomer` + `createProperty` calls.

### Gap: `CallRecord.callerAddress` Never Set for FSM

The FSM tools don't have access to `callRecordId`, so even when addresses are created/confirmed, `CallRecord.callerAddress` is never populated. The fix requires passing `callRecordId` through to the FSM backend endpoints as well, or handling it in the summarization worker as a safety net.

Note: `create-service-request` and `submit-lead` backend endpoints already accept `callRecordId`
and use it to sync `externalRequestId`/`externalRequestUrl` — so the pattern exists. We just
need to also set `CallRecord.callerAddress` in those same blocks.

---

## 5. Proposed Design: Single Source of Truth

### Core Principle

| Data | Source of Truth | Rationale |
|---|---|---|
| Caller name, email | **`Caller`** record (derive via join) | Identity doesn't change per call. If corrected, update everywhere. |
| Caller addresses | **`CallerAddress`** table (1-to-many) | Multiple addresses per caller, enriched with RentCast data |
| Which address for THIS call | **`CallRecord.callerAddress`** (string) | Call-specific context — keep on CallRecord |
| Summary, successEvaluation | **`CallRecord`** | LLM-generated, call-specific |

### Data Flow

#### During Call (Primary — Authoritative)

| Tool | Updates Caller? | Updates CallerAddress? | Sets CallRecord.callerAddress? |
|---|---|---|---|
| `submit_intake_answers` | ✅ name, email | ✅ creates/selects address | ✅ **with callRecordId fix** |
| `fs_create_customer` | ✅ already syncs | ✅ already syncs | ❌ needs callRecordId |
| `fs_create_property` | ❌ | ✅ already syncs | ❌ needs callRecordId |
| `fs_get_customer_by_phone` | ❌ (read-only) | ❌ | ❌ |

#### Post-Call (Safety Net — Summarization Worker)

1. **Always**: Link `callerId` on CallRecord (create Caller from phone if needed)
2. **Always**: Generate `summary` and `successEvaluation`
3. **If `CallRecord.callerAddress` is null** AND Caller has exactly 1 address → copy it
4. **Stop**: No longer copy name fields (derived from join at query time)

#### At Query Time

```typescript
// /me/calls endpoint (server.ts)
callerName: record.caller?.name || null,         // from join, not snapshot
callerFirstName: record.caller?.firstName || null,
callerLastName: record.caller?.lastName || null,
callerAddress: record.callerAddress || null,      // from CallRecord (call-specific)

// /call-records endpoint (call-records-router.ts)
// Already joins caller — just change callerName source
callerName: record.caller?.name || record.callerName || null,  // prefer join, fallback to snapshot during migration
```

### Edge Cases

| Scenario | Result |
|---|---|
| Call drops before any tool runs | Caller created from phone by summarization worker, name null, address null — correct |
| Name collected, call drops before address | `Caller.name` set, `CallRecord.callerAddress` null — correct |
| Caller corrects name on call 2 | `Caller.name` updated, ALL past CallRecords show corrected name via join — desired |
| Same caller, different address per call | Each `CallRecord.callerAddress` is independent — correct |
| FSM: new property created | Address synced to `CallerAddress` + `CallRecord.callerAddress` (with fix) |

---

## 6. Implementation Plan

### Phase 1: Fix Active Bugs ✅ IMPLEMENTED

**1a. Store `callRecordId` in ToolContext** ✅
- `api_client.py`: `log_call_start` now returns `Optional[str]` (was `None`)
- `tools/__init__.py`: Added `call_record_id` param to `ToolContext`
- `server.py`: Captures return value, passes to `ToolContext(call_record_id=...)`
- `tools/submit_intake_answers.py`: Removed `call_record_id` from LLM params, auto-reads from `tool_context.call_record_id`

**1b. Fix summarization queue transcript** ✅
- `src/server.ts` (upload-data endpoint): Converts `transcriptMessages` array to flat string via
  `transcriptMessages.map(m => \`${m.role}: ${m.content}\`).join('\n')` before queueing

**1c. Fix egress (EndCallTool race)** ✅
- `server.py`: `EndCallTool(delete_room=False)` — room stays alive for egress
- `server.py` (`on_session_end`): After upload_call_data completes, deletes room via
  `room_api.room.delete_room()` to hang up SIP caller

### Phase 2: Derive Name from Join ✅ IMPLEMENTED

**2a. Change API response to derive from Caller join** ✅
- `src/server.ts` (`/me/calls`): Added `firstName: true, lastName: true` to caller select;
  changed to `callerName: record.caller?.name || null` (no snapshot fallback)
- `src/routes/call-records-router.ts`: Changed to `callerName: record.caller?.name || null`

**2b. Simplify summarization worker** ✅
- `src/queues.ts`: Removed name snapshot copying block entirely
- Added callerAddress safety net: if `CallRecord.callerAddress` is null and Caller has
  exactly 1 address, copies it

### Phase 3: Pass callRecordId to FSM Tools (Future)

**3a. Add callRecordId to FSM tool calls**
- `fs_create_customer` and `fs_create_property` Python tools pass `callRecordId` to backend
- Backend endpoints use it to set `CallRecord.callerAddress`
- Files: `livekit-python/tools/fs_customer.py`, `livekit-python/tools/fs_property.py`, `src/routes/field-service-tools.ts`

### Phase 4: Cleanup (Future)

**4a. Drop snapshot columns via migration**
- Remove `caller_name`, `caller_first_name`, `caller_last_name` columns from `call_records`
- Safe once all queries derive from the Caller join (done in Phase 2)
