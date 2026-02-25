# fs-check-service-area Tool Removal — Decision Record

**Date:** Feb 24, 2026
**Status:** Implemented

## Context

An investigation into how LiveKit tools are registered and used revealed that the `fs-check-service-area` tool was broken:

1. **Backend sends it** — `getLiveKitToolsForLocation()` includes `'fs-check-service-area'` in the HCP tool list (server.ts)
2. **Backend route exists** — `POST /internal/tools/fs/check-service-area` works correctly (field-service-tools.ts)
3. **Python handler missing** — No `fs_check_service_area.py` in `livekit-python/tools/`, no handler in `__init__.py`'s if/elif chain
4. **Silent failure** — Python prints "Unknown tool: fs-check-service-area, skipping" and the LLM's tool call is silently dropped

The system prompt told the LLM to call `fs_check_service_area` for HCP service area checks (TWO-STEP CHECK), but the call never executed.

### Additional Issue: Returning Caller Step 4b

The `fsInstructions` in server.ts had a second bug: the returning caller workflow (step 4b) told ALL platforms to call `fs_check_service_area`, even Jobber — where the tool wasn't even in the tool list. The new caller workflow (step 6) was correctly platform-gated, but step 4b was not.

## Decision: Remove the Tool

Instead of creating the missing Python handler, we chose to **remove `fs-check-service-area` entirely** and rely on prompt-based service area checking for all platforms. This simplifies the architecture and creates consistency.

### Why This Works

1. **Service areas are already in the system prompt** for all platforms:
   - **HCP**: Full service zones (cities + ZIP codes per zone) are pre-fetched from HCP API and injected into the prompt at build time
   - **Jobber**: `location.serviceAreas` (city names) are injected into the prompt
   - **Google Calendar**: `location.serviceAreas` are injected into the prompt

2. **Backend guard on `create-property` is the real safety net** — If the LLM fails to catch an out-of-area address from the prompt, the `create-property` route has a hard guard that:
   - For HCP: Fetches all service zones and checks city OR ZIP against them
   - For Jobber: Checks city against `location.serviceAreas`
   - Returns 403 with a clear message ("Address is outside the service area")
   - The Python `fs_create_property` handler relays this error to the LLM

3. **The `checkServiceArea` adapter method still exists** — `HousecallProAdapter.checkServiceArea()` was upgraded (in this same session) to check both city AND ZIP against full zone data. The backend route still works. If we ever need the tool back, we just need to:
   - Create `livekit-python/tools/fs_service_area.py` with a `@function_tool()` handler
   - Register it in `livekit-python/tools/__init__.py`
   - Add `'fs-check-service-area'` back to the HCP tool list in `server.ts`

### Trade-off

If the LLM misses a match from the prompt (e.g., very large zone list), the UX is slightly worse:
- **With tool**: LLM calls tool → gets `isServiced: false` → declines gracefully
- **Without tool**: LLM misses it → calls `fs_create_property` → 403 error → LLM relays decline

The outcome is the same (correct rejection), but the 403 path is less graceful. For most businesses with a manageable number of zones, the LLM reliably matches from the prompt.

## Changes Made

### 1. Removed `fs-check-service-area` from HCP tool list
**File:** `src/server.ts` — `getLiveKitToolsForLocation()`
Removed `'fs-check-service-area'` from the `hcpTools` array.

### 2. Updated HCP service area prompt to be purely prompt-based
**File:** `src/utils.ts` — `generateSystemPrompt()`
Changed the TWO-STEP CHECK instruction for HCP from "call fs_check_service_area" to "check both city and ZIP codes against the service zones listed above."

### 3. Updated fsInstructions step 6 (new callers)
**File:** `src/server.ts` — `fsInstructions` template
Changed the HCP `serviceAreaStep` from referencing `fs_check_service_area` to prompt-based checking, consistent with Jobber's approach.

### 4. Updated fsInstructions step 4b (returning callers)
**File:** `src/server.ts` — `fsInstructions` template
Platform-gated step 4b using `isHCP` conditional. Both platforms now instruct the LLM to check from the prompt/service zones rather than calling a tool.

### 5. Fixed fs_create_service_request docstring
**File:** `livekit-python/tools/fs_service_request.py`
Changed hardcoded "Jobber EncodedId" references in parameter docstrings to generic descriptions (e.g., "the ID returned by fs_create_customer"). The system prompt already provides platform-specific ID guidance.

## How to Bring the Tool Back

If we find that prompt-based checking is insufficient (e.g., for businesses with 50+ zones or hundreds of ZIP codes):

1. Create `livekit-python/tools/fs_service_area.py`:
   ```python
   def fs_check_service_area_tool(context):
       @function_tool()
       async def fs_check_service_area(ctx, zip_code: str, city: Optional[str] = None) -> str:
           """Check if a ZIP code or city is within the business's service area."""
           body = {"zipCode": zip_code}
           if city:
               body["city"] = city
           return await call_fs_endpoint(context, "/check-service-area", body)
       return fs_check_service_area
   ```

2. Register in `livekit-python/tools/__init__.py`:
   ```python
   from .fs_service_area import fs_check_service_area_tool
   # ... in register_tools():
   elif tool_name == "fs-check-service-area":
       tool = fs_check_service_area_tool(context)
   ```

3. Add back to `server.ts` `getLiveKitToolsForLocation()` HCP tool list:
   ```typescript
   'fs-check-service-area',
   ```

4. Update prompt instructions to reference the tool again.

The backend route and adapter method are still in place and working.
