# Integration State Transitions — Data Impact Analysis & Migration Plan

**Date:** February 27, 2026
**Status:** Planning
**Related files:**
- `~/callsaver-api/src/server.ts` — Connect/disconnect endpoints, `cleanupAfterDisconnect`, `getLiveKitToolsForLocation`, `buildDynamicAssistantConfig`, `/internal/agent-config`
- `~/callsaver-api/src/utils.ts` — `buildDynamicAssistantConfig` (system prompt generation per integration)
- `~/callsaver-api/src/routes/field-service-tools.ts` — FSM tool endpoints (customer/property CRUD, Caller sync)
- `~/callsaver-api/src/adapters/field-service/` — Jobber/HCP adapters
- `~/callsaver-api/prisma/schema.prisma` — Caller, CallRecord, CallerAddress, CallbackRequest, IntegrationConnection, OrganizationIntegration
- `~/callsaver-frontend/src/pages/IntegrationsPage.tsx` — UI for connect/disconnect/switch
- `~/callsaver-frontend/src/lib/integrations-config.ts` — Available integrations config
- `~/callsaver-frontend/src/components/integrations/switch-integration-dialog.tsx` — Switch confirmation dialog

---

## 1. Current Architecture Summary

### 1.1 Integration Storage Models

| Model | Auth Type | Platforms | Storage |
|-------|-----------|-----------|---------|
| `IntegrationConnection` | OAuth (Pipedream) | Google Calendar, Jobber | `nango_connections` table |
| `OrganizationIntegration` | API Key | Housecall Pro | `organization_integrations` table |

**Single-integration model:** Only ONE integration can be active per organization at a time. Connecting a new integration automatically disconnects the existing one.

### 1.2 Integration-Specific Data on Core Models

#### Caller Model
| Field | Written By | Purpose | Integration-Specific? |
|-------|-----------|---------|----------------------|
| `phoneNumber` | Call start | Unique identifier | ❌ Universal |
| `name`, `firstName`, `lastName` | Agent intake OR FSM sync | Display name | ❌ Universal (but FSM sync overwrites) |
| `email` | Agent intake OR FSM sync | Contact info | ❌ Universal |
| `summary` | Summarization queue | AI-generated profile summary | ❌ Universal |
| `customIntakeAnswers` | submit-intake-answers tool | JSON intake responses | ❌ Universal |
| **`externalCustomerId`** | FSM create-customer endpoint | Jobber/HCP customer ID | ✅ **Platform-specific** |
| **`externalPlatform`** | FSM create-customer endpoint | `"jobber"` or `"housecall-pro"` | ✅ **Platform-specific** |
| **`externalCustomerUrl`** | FSM create-customer endpoint | Deep link to Jobber/HCP | ✅ **Platform-specific** |

#### CallerAddress Model
| Field | Written By | Purpose | Integration-Specific? |
|-------|-----------|---------|----------------------|
| `address`, `street`, `city`, `state`, `zipCode` | validate-address tool OR FSM sync | Address data | ❌ Universal |
| `isPrimary` | Set on creation | Primary flag | ❌ Universal |
| `rentcastId`, `rentcastData`, `rentcastFetchedAt` | Property enrichment queue | RentCast property details | ❌ Universal (enrichment runs for all) |

#### CallRecord Model
| Field | Written By | Purpose | Integration-Specific? |
|-------|-----------|---------|----------------------|
| `callerAddress` | Summarization queue | Call-specific address | ❌ Universal |
| `toolCalls` | on_session_end upload | JSON array of all tool calls | Contains integration-specific tool calls but stored generically |
| `transcriptMessages` | on_session_end upload | Structured transcript | ❌ Universal |
| `summary` | Summarization queue | AI-generated call summary | ❌ Universal |

#### CallbackRequest Model
| Field | Written By | Purpose | Integration-Specific? |
|-------|-----------|---------|----------------------|
| All fields | request_callback tool | Callback details | ❌ Universal |

#### Agent Model (config JSON)
| Config Key | Set By | Purpose | Integration-Specific? |
|------------|--------|---------|----------------------|
| `autoScheduleAssessment` | HCP/Jobber settings toggle | Auto-schedule estimates | ✅ **FSM-specific** |
| `includePricing` | HCP/Jobber settings toggle | Share pricing with callers | ✅ **FSM-specific** |
| `collectEmail` | Settings toggle | Email collection behavior | ❌ Universal |

### 1.3 What `cleanupAfterDisconnect` Currently Does

When an FSM integration (Jobber/HCP) is disconnected or switched:

1. **Clears `externalCustomerId`, `externalPlatform`, `externalCustomerUrl`** on all Callers linked to the disconnected platform
2. **Clears FSM-specific agent config flags** (`autoScheduleAssessment`, `includePricing`)
3. **Does NOT run** for Google Calendar disconnects (no GCal-specific data on Callers)

### 1.4 What `cleanupAfterDisconnect` Does NOT Do

- Does **NOT** delete Caller records
- Does **NOT** delete CallerAddress records
- Does **NOT** delete CallRecord records
- Does **NOT** delete CallbackRequest records
- Does **NOT** delete the call transcript, summary, or tool calls
- Does **NOT** clear `name`, `firstName`, `lastName`, `email` on Callers (these are universal)

### 1.5 How Tools Are Selected (`getLiveKitToolsForLocation`)

| Integration | Base Tools | Integration Tools | Intake Tool |
|-------------|-----------|-------------------|-------------|
| **None** | validate-address, request-callback, transfer-call | — | submit-intake-answers |
| **Google Calendar** | validate-address, request-callback, transfer-call | 5 google-calendar-* tools | submit-intake-answers |
| **Jobber** | validate-address, request-callback, transfer-call | 13 fs-* tools | ❌ (FSM handles intake) |
| **Housecall Pro** | validate-address, request-callback, transfer-call | 18 fs-* tools | ❌ (FSM handles intake) |

---

## 2. State Transitions — Complete Matrix

### Legend
- 🟢 **No action needed** — data remains valid
- 🟡 **Minor cleanup** — stale data exists but doesn't break anything
- 🔴 **Requires action** — data would be invalid or confusing

### 2.1 No Integration → Google Calendar

**What happens on connect:**
- `IntegrationConnection` created (OAuth via Pipedream)
- No existing OAuth connection to delete
- `getLiveKitToolsForLocation` starts returning 5 google-calendar-* tools
- `buildDynamicAssistantConfig` switches to GCal system prompt variant
- `submit-intake-answers` tool remains (GCal is not FSM)

**Impact on existing data:**

| Data | Impact | Status |
|------|--------|--------|
| Callers (name, phone, email) | 🟢 Unchanged, still valid | No action |
| CallerAddresses | 🟢 Unchanged, still used in system prompt | No action |
| CallRecords | 🟢 Unchanged, historical data preserved | No action |
| CallbackRequests | 🟢 Unchanged, still functional | No action |
| Intake answers | 🟢 Unchanged, `submit-intake-answers` still available | No action |
| Agent config | 🟢 No FSM flags to clear | No action |

**Verdict: ✅ Seamless transition. No data migration needed.**

### 2.2 No Integration → Jobber

**What happens on connect:**
- `IntegrationConnection` created (OAuth via Pipedream)
- `getLiveKitToolsForLocation` starts returning 13 fs-* tools, removes `submit-intake-answers`
- `buildDynamicAssistantConfig` switches to Jobber system prompt variant (pre-fetches services)
- FSM tools become available (customer lookup, create, property, service requests)

**Impact on existing data:**

| Data | Impact | Status |
|------|--------|--------|
| Callers (name, phone, email) | 🟢 Unchanged. On next call, FSM `fs-get-customer-by-phone` will search Jobber for matching phone. If found, `externalCustomerId` gets linked. If not found, agent creates new Jobber customer via `fs-create-customer`. | No action |
| CallerAddresses | 🟡 Still in DB but **not shown to agent**. FSM path strips `callerInfo.addresses` in agent-config and replaces with `fsProperties` from the FSM platform. Pre-existing addresses persist in DB for display on CallerDetailPage. | No action needed, but addresses won't be used by agent |
| CallRecords | 🟢 Unchanged, historical data preserved | No action |
| CallbackRequests | 🟢 Unchanged, still functional | No action |
| Intake answers (customIntakeAnswers) | 🟡 Still in DB. `submit-intake-answers` tool removed — agent uses FSM tools instead. Historical intake data viewable in frontend. | No action |
| Agent config | 🟢 FSM flags (`autoScheduleAssessment`, `includePricing`) default to `false`/`true` | No action |

**What the user should know:**
- Existing callers will need to be matched to Jobber customers. If the business already has them in Jobber, the agent will find them by phone. If not, the agent will create new Jobber customers.
- The business should import their existing customers into Jobber before connecting (standard Jobber onboarding).

**Verdict: ✅ Clean transition. Existing callers naturally re-link on their next call.**

### 2.3 No Integration → Housecall Pro

Same as 2.2 (No Integration → Jobber), but:
- `OrganizationIntegration` created (API key, not OAuth)
- HCP tools are a superset of Jobber tools (18 vs 13)
- HCP pre-fetches business hours, services, and service zones
- `lead_source = 'CallSaver'` is set for HCP-created customers

**Verdict: ✅ Clean transition. Same natural re-linking behavior.**

### 2.4 Google Calendar → Jobber

**What happens on connect:**
- Existing `IntegrationConnection` (google-calendar) is **deleted**
- `cleanupAfterDisconnect('google-calendar')` runs but **does nothing** (GCal is not in `fsIntegrations` list)
- New `IntegrationConnection` (jobber) is created
- Tools switch from google-calendar-* to fs-* tools
- `submit-intake-answers` is **removed** (FSM handles intake)

**Impact on existing data:**

| Data | Impact | Status |
|------|--------|--------|
| Callers | 🟢 Unchanged. No externalCustomerId was set (GCal doesn't set it). On next call, FSM tools link callers to Jobber. | No action |
| CallerAddresses | 🟡 Still in DB. Agent switches from CallerAddress-sourced addresses to Jobber property addresses. Pre-existing addresses remain for historical display. | No action |
| CallRecords | 🟢 Unchanged. Historical tool calls reference `google_calendar_*` functions which are now just historical data. | No action |
| CallbackRequests | 🟢 Unchanged | No action |
| Google Calendar events | 🔴 **Events created in Google Calendar still exist** but agent can no longer manage them. No tool to list/update/cancel. | See note below |
| Intake answers | 🟡 Historical data preserved, tool removed | No action |

**Note on Google Calendar events:** When switching away from GCal, any appointments created by the agent in Google Calendar remain in the user's calendar. The agent can no longer manage them. The user manages them directly in Google Calendar. This is acceptable — the events are in the user's calendar, not our system.

**Verdict: ✅ Clean transition. GCal events persist in user's calendar (expected).**

### 2.5 Google Calendar → Housecall Pro

Same as 2.4, but:
- Existing `IntegrationConnection` (google-calendar) is deleted
- New `OrganizationIntegration` (housecallpro) is created
- Also deletes any existing `OrganizationIntegration` if present (single-integration model)

**Verdict: ✅ Clean transition.**

### 2.6 Jobber → Housecall Pro ⚠️

**What happens on connect:**
- `POST /me/integrations/api-key` is called
- All existing `IntegrationConnection` records are **deleted** (this deletes the Jobber OAuth connection)
- `cleanupAfterDisconnect(organizationId, 'jobber')` runs:
  - Clears `externalCustomerId`, `externalPlatform`, `externalCustomerUrl` on Callers where `externalPlatform = 'jobber'`
  - Clears FSM agent config flags
- New `OrganizationIntegration` (housecallpro) is created
- Tools switch from Jobber fs-* to HCP fs-*

**Impact on existing data:**

| Data | Impact | Status |
|------|--------|--------|
| Callers (name, phone, email) | 🟢 Preserved. `externalCustomerId` (Jobber ID) is **cleared**. | Correctly cleaned |
| Callers (externalCustomerId) | 🟢 **Cleared to null** by cleanup. On next call, FSM tools will search HCP by phone and link. | Correctly cleaned |
| CallerAddresses | 🟡 Addresses synced from Jobber properties remain. New HCP properties will also sync. May get duplicate addresses if Jobber and HCP have the same property addresses. | Minor - see dedup note |
| CallRecords | 🟢 Unchanged. Historical tool calls reference Jobber-specific fs_* calls but data is generic. | No action |
| CallbackRequests | 🟢 Unchanged | No action |
| Service Requests in Jobber | 🔴 **Still exist in Jobber** but no longer accessible via our platform. User manages directly in Jobber. | Expected |
| Service Requests page (frontend) | 🟡 `/me/service-requests` will now query HCP instead of Jobber. Old Jobber service requests disappear from the page. | Expected — we only show current platform |

**What the user should know:**
- They should export customer data from Jobber and import into HCP before switching
- Existing callers will naturally re-link to HCP customers on their next call
- Historical Jobber service requests won't show on the Service Requests page anymore (they're still in Jobber)

**Verdict: ✅ Clean transition. `cleanupAfterDisconnect` handles the essential cleanup. Users expected to manage data export/import between platforms themselves.**

### 2.7 Housecall Pro → Jobber ⚠️

**What happens on connect:**
- `POST /me/integrations/connect` is called (Jobber is OAuth)
- All existing `IntegrationConnection` records are deleted (none exist if only HCP was connected)
- `cleanupAfterDisconnect` runs for each deleted OAuth connection type (likely none)
- ⚠️ **BUG: Existing `OrganizationIntegration` (HCP) is NOT deleted by `POST /me/integrations/connect`!**
  - The `/me/integrations/connect` endpoint only deletes `IntegrationConnection` records, not `OrganizationIntegration` records
  - The `/me/integrations/api-key` endpoint deletes both, but `/me/integrations/connect` doesn't
  - This means the HCP `OrganizationIntegration` would **persist** alongside the new Jobber `IntegrationConnection`

**This is a bug.** Let's trace what happens:
1. User has HCP connected (stored in `OrganizationIntegration`)
2. User connects Jobber (creates `IntegrationConnection`)
3. `getLiveKitToolsForLocation` finds the `IntegrationConnection` (Jobber) first → uses Jobber tools ✅
4. But `GET /me/integrations` would show HCP as still connected ❌
5. HCP API key is still valid and stored ❌
6. `cleanupAfterDisconnect` for HCP was never called → `externalCustomerId`/`externalPlatform` still say "housecall-pro" ❌

**Impact on existing data (assuming bug is fixed):**

| Data | Impact | Status |
|------|--------|--------|
| Callers (externalCustomerId) | 🔴 **Not cleared** unless we fix the bug. Should be cleared when HCP is disconnected. | **BUG** |
| CallerAddresses | 🟡 Same as 2.6 — HCP-synced addresses persist | Minor |
| Agent config (autoScheduleAssessment, includePricing) | 🔴 **Not cleared** unless we fix the bug | **BUG** |

**Verdict: 🔴 BUG — `POST /me/integrations/connect` must also clean up `OrganizationIntegration` records.**

### 2.8 Jobber → No Integration (Disconnect)

**What happens:**
- `DELETE /me/integrations/jobber` called
- `IntegrationConnection` deleted, Pipedream account deleted
- `cleanupAfterDisconnect('jobber')` runs:
  - Clears `externalCustomerId`, `externalPlatform`, `externalCustomerUrl`
  - Clears FSM agent config flags
- Tools revert to base tools + `submit-intake-answers`

**Impact:** All clean. Callers, addresses, records preserved. External IDs cleared.

**Verdict: ✅ Clean.**

### 2.9 Housecall Pro → No Integration (Disconnect)

**What happens:**
- `DELETE /me/integrations/housecall-pro` called
- `OrganizationIntegration` deleted
- `cleanupAfterDisconnect('housecall-pro')` runs (same as Jobber)

**Verdict: ✅ Clean.**

### 2.10 Google Calendar → No Integration (Disconnect)

**What happens:**
- `DELETE /me/integrations/google-calendar` called
- `IntegrationConnection` deleted, Pipedream account deleted
- `cleanupAfterDisconnect('google-calendar')` → **does nothing** (GCal not in `fsIntegrations` list)
- Tools revert to base tools + `submit-intake-answers`

**Impact:** Google Calendar events remain in user's calendar. Agent can no longer manage them. All local data preserved.

**Verdict: ✅ Clean.**

---

## 3. Summary: What Breaks

### 3.1 Bug Found: HCP → Jobber Transition

**Problem:** `POST /me/integrations/connect` (OAuth flow) does not delete `OrganizationIntegration` records. This means switching from HCP (API key) to Jobber (OAuth) leaves the HCP integration orphaned.

**Fix:**
```typescript
// In POST /me/integrations/connect, after deleting IntegrationConnections:

// Also clean up OrganizationIntegration records (API key platforms like HCP)
const existingOrgIntegrations = await prisma.organizationIntegration.findMany({
  where: { organizationId },
});
for (const oi of existingOrgIntegrations) {
  console.log(`🗑️  Deleting OrganizationIntegration: ${oi.platform}`);
  await prisma.organizationIntegration.delete({ where: { id: oi.id } });
  // Map platform name to integration type for cleanup
  const typeKey = oi.platform === 'housecallpro' ? 'housecall-pro' : oi.platform;
  await cleanupAfterDisconnect(organizationId, typeKey);
}
```

**Files to change:** `src/server.ts` (`POST /me/integrations/connect` endpoint, ~line 7419)

### 3.2 Minor Issue: Duplicate CallerAddresses After Platform Switch

When switching from one FSM platform to another (Jobber → HCP or vice versa), CallerAddresses synced from the old platform persist. If the same caller has the same address in both platforms, a second CallerAddress won't be created (unique constraint on `[callerId, address]`). If addresses differ slightly (formatting), duplicates could appear.

**Recommendation:** No action needed. The `CallerAddress` unique constraint prevents true duplicates. Minor formatting differences are acceptable — the user can manage addresses on the CallerDetailPage.

### 3.3 Historical Tool Calls Contain Platform-Specific References

CallRecord `toolCalls` JSON contains function names like `fs_create_customer`, `fs_create_service_request`, etc. These are stored verbatim and remain after a platform switch. The frontend renders them generically (showing function name + result), so this is fine.

**Recommendation:** No action needed. Tool calls are historical records.

### 3.4 Frontend Service Requests Page Only Shows Current Platform

The `/me/service-requests` endpoint queries the **active** FSM platform. After switching from Jobber to HCP, Jobber service requests disappear from the page. This is expected behavior — we are not a CRM, we show the current platform's data.

**Recommendation:** No action needed. Could add a notice in the future ("You recently switched from Jobber. Historical service requests may be viewed in your Jobber account.").

---

## 4. What Does NOT Need Migration

The key insight is that **our core data models are integration-agnostic**:

- **Caller** — Phone number is the universal identifier. Name/email are synced regardless of integration. External IDs are correctly cleaned on disconnect.
- **CallerAddress** — Addresses are stored universally. Both RentCast enrichment (non-FSM) and FSM property sync write to the same model.
- **CallRecord** — Contains transcripts, summaries, tool calls. All stored as generic data. No platform-specific columns.
- **CallbackRequest** — Fully integration-agnostic. Works identically across all integration states.

The **only integration-specific state** on core models is the trio of fields on Caller:
- `externalCustomerId`
- `externalPlatform`
- `externalCustomerUrl`

These are already correctly cleaned by `cleanupAfterDisconnect` on all FSM disconnect/switch paths (except the bug in 3.1).

---

## 5. User's Responsibility on Platform Switch (Jobber ↔ HCP)

When a business migrates from one FSM platform to another:

1. **Export customers from old platform** — Both Jobber and HCP support CSV export
2. **Import customers into new platform** — Both support CSV import
3. **Connect new integration in CallSaver** — Our cleanup handles the rest
4. **First calls post-switch** — Agent will search the new platform by phone number. If the business imported their data, customers will be found automatically. If not, agent creates new customers.

**We do NOT need to handle data migration between platforms.** The business manages their own data export/import. Our job is to cleanly disconnect from the old platform (clear stale IDs) and seamlessly connect to the new one.

---

## 6. Implementation Plan

### Phase 1: Fix the HCP → Jobber Bug (Critical)
**File:** `src/server.ts` (`POST /me/integrations/connect`, ~line 7419)
**Change:** After deleting `IntegrationConnection` records, also delete any `OrganizationIntegration` records and run `cleanupAfterDisconnect` for them.

### Phase 2: Improve Switch Dialog Messaging (Optional, UX)
**File:** `switch-integration-dialog.tsx`
**Change:** Show platform-specific guidance:
- If switching away from FSM: "Your existing call records and caller data will be preserved, but the agent will need to re-link callers to [new platform] on their next call."
- If switching to FSM from GCal/None: "Existing appointments in Google Calendar will remain but won't be managed by the agent. The agent will use [new platform] for scheduling going forward."

### Phase 3: Add Integration History Audit Trail (Future, Low Priority)
Consider logging integration switches to a new `integration_change_log` table for debugging:
```
| id | organizationId | fromType | toType | changedAt | changedBy |
```
This is not critical but would help with support tickets ("When did they switch?").

---

## 7. Testing Matrix

| Transition | Test Scenario | Expected Result |
|------------|--------------|-----------------|
| None → GCal | Connect GCal, make call, schedule appointment | Agent uses GCal tools, creates event |
| None → Jobber | Connect Jobber, call with known caller | Agent finds customer by phone in Jobber |
| None → HCP | Connect HCP, call with new caller | Agent creates HCP customer, sets externalCustomerId |
| GCal → Jobber | Switch from GCal to Jobber, make call | Agent uses Jobber tools, GCal events untouched |
| GCal → HCP | Switch from GCal to HCP | Same as above with HCP tools |
| Jobber → HCP | Switch from Jobber to HCP, verify cleanup | externalCustomerId cleared, HCP tools active |
| **HCP → Jobber** | Switch from HCP to Jobber, verify cleanup | **Must verify OrgIntegration deleted, externalCustomerId cleared** |
| Jobber → None | Disconnect Jobber, make call | Base tools only, submit-intake-answers available |
| HCP → None | Disconnect HCP, make call | Base tools only, submit-intake-answers available |
| GCal → None | Disconnect GCal, make call | Base tools only, no GCal tools |

---

## 8. Conclusion

The current architecture handles integration state transitions **remarkably well** due to the integration-agnostic design of core data models. The only bug found is the **HCP → Jobber transition** where `POST /me/integrations/connect` doesn't clean up `OrganizationIntegration` records.

**Key takeaway:** We do NOT need to build a data migration system for platform switches. The business handles their own data export/import between FSM platforms. Our job is to:
1. Cleanly disconnect (clear stale external IDs) ← already works
2. Seamlessly connect (agent re-links callers on next call) ← already works
3. Fix the one bug (HCP → Jobber cleanup) ← Phase 1
