# Field Service Tools Alignment Review

**Date:** Feb 24, 2026  
**Scope:** Python tool docstrings ↔ backend tool lists ↔ system prompt (fsInstructions)  
**Platforms:** Jobber, Housecall Pro (HCP)

---

## Architecture Overview

1. **Backend (`server.ts` `getLiveKitToolsForLocation`)** — builds an array of tool name strings (e.g., `'fs-get-customer-by-phone'`) and sends it via `POST /internal/agent-config` response.
2. **Python agent (`server.py`)** — receives tool names from agent config, calls `register_tools()` in `tools/__init__.py`.
3. **`tools/__init__.py`** — big if/elif chain: maps each tool name → a `@function_tool()` decorated function from the `fs_*.py` files.
4. **LiveKit** — presents the function name + docstring to the LLM as the tool schema (name, description, parameters). The LLM sees both the system prompt AND the tool docstrings.
5. **System prompt (`fsInstructions`)** — appended to the system prompt in `server.ts` when `fs-*` tools are detected. Uses template variables for platform-aware terminology.

---

## Tool List Comparison

### Backend tool lists (server.ts lines 8704–8781)

| Tool Name                   | Jobber | HCP | Python Handler |
|-----------------------------|--------|-----|----------------|
| fs-get-customer-by-phone    | ✅     | ✅  | ✅             |
| fs-create-customer          | ✅     | ✅  | ✅             |
| fs-update-customer          | ✅     | ✅  | ✅             |
| fs-list-properties          | ✅     | ✅  | ✅             |
| fs-create-property          | ✅     | ✅  | ✅             |
| fs-create-service-request   | ✅     | ✅  | ✅             |
| fs-get-request              | ✅     | ✅  | ✅             |
| fs-get-requests             | ✅     | ✅  | ✅             |
| fs-reschedule-assessment    | ✅     | ✅  | ✅             |
| fs-cancel-assessment        | ✅     | ✅  | ✅             |
| fs-check-availability       | ✅     | ✅  | ✅             |
| fs-get-services             | ✅     | ✅  | ✅             |
| fs-get-client-schedule      | ✅     | ✅  | ✅             |
| fs-get-jobs                 | ❌     | ✅  | ✅             |
| fs-get-job                  | ❌     | ✅  | ✅             |
| fs-get-appointments         | ❌     | ✅  | ✅             |
| fs-reschedule-appointment   | ❌     | ✅  | ✅             |
| fs-cancel-appointment       | ❌     | ✅  | ✅             |
| **fs-check-service-area**   | ❌     | ✅  | **❌ MISSING**  |

### Python handlers with NO backend caller

| Tool Name                   | Python Handler | Backend (Jobber) | Backend (HCP) |
|-----------------------------|----------------|------------------|---------------|
| **fs-submit-lead**          | ✅             | ❌               | ❌            |
| **fs-create-appointment**   | ✅             | ❌               | ❌            |
| **fs-create-assessment**    | ✅             | ❌               | ❌            |
| **fs-get-estimates**        | ✅             | ❌               | ❌            |
| **fs-get-invoices**         | ✅             | ❌               | ❌            |
| **fs-get-account-balance**  | ✅             | ❌               | ❌            |

---

## Issues Found

### 🔴 Issue 1: `fs-check-service-area` — Backend sends it, Python can't handle it

- **Backend (server.ts:8773):** Includes `'fs-check-service-area'` in HCP tool list.
- **Backend route (field-service-tools.ts:1575):** Route `POST /internal/tools/fs/check-service-area` exists and works.
- **Python (__init__.py):** No handler for `"fs-check-service-area"` — it will log `"[tools] Unknown tool: fs-check-service-area, skipping"` and silently fail to register.
- **System prompt (fsInstructions):** References `fs_check_service_area` in two places:
  - **New caller step 6** (HCP only): `"Call fs_check_service_area with the caller's ZIP code"`
  - **Returning caller step 4b** (BOTH platforms!): `"SERVICE AREA CHECK (MANDATORY): Call fs_check_service_area"`

**Impact:** For HCP, the system prompt instructs the LLM to call a tool that isn't registered — the LLM will attempt to call it, fail, and be confused. For Jobber, step 4b also references it (incorrectly — see Issue 2).

**Fix needed:** Create `fs_service_area.py` with `fs_check_service_area_tool()`, import it in `__init__.py`, and add the elif handler.

---

### 🔴 Issue 2: Returning caller step 4b references `fs_check_service_area` for ALL platforms

- **Location (server.ts:9507):** In the "WORKFLOW FOR RETURNING CALLERS" > "NEW ADDRESS" section, step 4b says:
  ```
  ⚠️ SERVICE AREA CHECK (MANDATORY): Call fs_check_service_area with the ZIP code...
  ```
- This is NOT gated by `isHCP` — it applies to both Jobber and HCP.
- For **Jobber**, `fs-check-service-area` is not in the tool list (line 8704–8733 — not included) AND the tool returns null for Jobber (adapter falls back to Location.serviceAreas text match, which is done tool-layer side).
- For **new callers**, step 6 correctly differentiates: HCP → `fs_check_service_area`, Jobber → manual city check against AREAS SERVED.
- But **returning callers** step 4b doesn't differentiate.

**Impact:** For Jobber returning callers wanting service at a new address, the system prompt tells the LLM to call a tool that doesn't exist in its toolset.

**Fix needed:** Gate step 4b with the same platform condition as step 6. For Jobber, it should say "Verify the city is in AREAS SERVED" instead.

---

### 🟡 Issue 3: `fs_create_service_request` docstring has Jobber-specific language

In `fs_service_request.py:39-44`:
```python
customer_id: The customer's ID (Jobber EncodedId from fs_create_customer or fs_get_customer_by_phone).
property_id: The property ID (Jobber EncodedId from fs_create_property).
service_id: The service ID (Jobber EncodedId from fs_get_services).
```

These docstrings are sent to the LLM as the tool parameter descriptions. When running for HCP:
- The **system prompt** says: `"IDs are plain string IDs"` (correctly platform-aware)
- The **tool docstring** says: `"Jobber EncodedId"` (incorrect for HCP)

This is contradictory. The LLM sees both and may be confused about ID format.

**Fix needed:** Change the docstrings to platform-agnostic language:
```python
customer_id: The customer's ID from fs_create_customer or fs_get_customer_by_phone.
property_id: The property ID from fs_create_property.
service_id: The service ID from fs_get_services.
```

---

### 🟡 Issue 4: `fs_assessment.py` module docstring is Jobber-specific

`fs_assessment.py:5-6`:
```python
In Jobber, an Assessment is the initial consultation/evaluation visit attached to a Request.
```

This is a module-level docstring (not shown to LLM), so it's low-impact. But the function docstrings in this file are actually generic enough ("assessment (initial site visit / consultation)") — they work for both platforms.

The system prompt handles the terminology correctly: for HCP it says "estimate/consultation" instead of "assessment".

**Impact:** Low — only affects developer readability, not LLM behavior.

---

### 🟢 Issue 5: Dead Python handlers (tools never sent from backend)

Six Python tool handlers exist but are never included in backend tool lists:

| Tool | Python File | Status |
|------|------------|--------|
| `fs-submit-lead` | fs_service_request.py | Backend route exists (`/submit-lead`), but not in tool lists |
| `fs-create-appointment` | fs_scheduling.py | Backend route exists (`/create-appointment`), but not in tool lists |
| `fs-create-assessment` | fs_assessment.py | Backend route exists (`/create-assessment`), but not in tool lists |
| `fs-get-estimates` | fs_billing.py | Backend route exists (`/get-estimates`), but not in tool lists |
| `fs-get-invoices` | fs_billing.py | Backend route exists (`/get-invoices`), but not in tool lists |
| `fs-get-account-balance` | fs_billing.py | Backend route exists (`/get-account-balance`), but not in tool lists |

**Why they're excluded:**
- **fs-submit-lead:** The system prompt workflow uses the explicit 3-step flow (create customer → create property → create service request) instead of the one-shot submit-lead. This gives the agent more control and error handling.
- **fs-create-appointment:** The workflow uses fs-reschedule-assessment for scheduling instead (assessment is auto-created by fs-create-service-request, then rescheduled to a time). Direct appointment creation isn't in the workflow.
- **fs-create-assessment:** Assessment is auto-created by Jobber when fs-create-service-request is called. Creating separately would fail ("Cannot create more than 1 assessment").
- **fs-get-estimates / fs-get-invoices / fs-get-account-balance:** Not in current workflow — could be added for returning callers who ask about billing.

**Impact:** None — these handlers are dead code on the Python side. They're correctly implemented and ready if the backend ever adds them to tool lists. No action needed, but they could be activated for richer returning-caller support.

---

## System Prompt (fsInstructions) Review

### What's correct ✅

1. **Platform-aware terminology:** `assessmentEntity` and `assessmentEntityCap` correctly switch between "assessment" (Jobber) and "estimate/consultation" (HCP).
2. **Platform-aware ID notes:** Separate `idNote` for Jobber ("EncodedId") vs HCP ("plain string ID").
3. **Platform-aware service area check (new callers):** Step 6 correctly differentiates — HCP uses `fs_check_service_area`, Jobber checks AREAS SERVED in system prompt.
4. **Property notes:** Platform-specific `propertyNote` and `customerIdNote`.
5. **Pricing control:** `includePricing` flag correctly gates whether service_price and pricing language are included.
6. **Auto-schedule toggle:** `autoScheduleAssessment` flag correctly gates step 11 between auto-scheduling and manual-only flow.
7. **Tool function names in system prompt match Python function names** (underscore convention: `fs_create_customer` matches `async def fs_create_customer`).

### What needs fixing ⚠️

1. **Returning caller step 4b** — `fs_check_service_area` reference not platform-gated (Issue 2 above).
2. **No HCP-specific tools in "OTHER RETURNING CALLER ACTIONS"** — The instructions mention `fs_get_jobs / fs_get_job` but these are only in the HCP tool list. For Jobber, these tools don't exist. The LLM won't be able to call them, but the system prompt suggests it. Conversely, Jobber's workflow focuses on Requests → Jobs (contractor handles), so this section is somewhat misleading for Jobber.

---

## Summary of Required Fixes

| Priority | Issue | Fix |
|----------|-------|-----|
| 🔴 HIGH | `fs-check-service-area` missing from Python | Create `fs_service_area.py`, add handler to `__init__.py` |
| 🔴 HIGH | Returning caller step 4b not platform-gated | Add `isHCP` condition in fsInstructions for step 4b |
| 🟡 MED  | `fs_create_service_request` docstring says "Jobber EncodedId" | Change to platform-agnostic wording |
| 🟢 LOW  | Dead Python handlers for 6 tools | No fix needed — ready for future activation |
| 🟢 LOW  | Module docstring in `fs_assessment.py` says "Jobber" | Cosmetic — update to say "Jobber/HCP" |
