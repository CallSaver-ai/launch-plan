# Housecall Pro Integration Plan — Comprehensive

> Created: Feb 22, 2026  |  Status: DRAFT
> Prereqs: `housecall-pro-customer-intents-analysis.md`, `housecallpro-api-mapping.md`, `HousecallProAdapter.ts` (875 lines, 34 methods)

---

## 1. Current State

### Already Built

- **HousecallProAdapter** — All 34 FieldServiceAdapter methods implemented
- **HousecallProClient** — REST client, `Token <apiKey>` auth, rate limiting
- **FieldServiceAdapterRegistry** — Routes HCP to API key auth (not Pipedream)
- **Frontend** — HCP card in integrations-config with `authType: 'api_key'`, API key dialog, sidebar renames "Appointments" → "Jobs"
- **server.ts** — `case 'housecall-pro'` adds 13 fs-* tools (same set as Jobber)
- **field-service-tools.ts** — Platform-agnostic routes (adapter resolved by locationId)

### Bugs Found (Hardcoded Jobber Assumptions)

| # | Issue | Severity | Location |
|---|-------|----------|----------|
| B1 | `externalPlatform: 'jobber'` hardcoded in create-customer | **High** | `field-service-tools.ts:212,225` |
| B2 | Jobber base64 ID decode for `externalRequestUrl` | **High** | `field-service-tools.ts:414-421,582-587` |
| B3 | fsInstructions header says "JOBBER" for ALL platforms | **High** | `server.ts:9066-9067` |
| B4 | All ID references say "Jobber EncodedId" | **High** | `server.ts:9081-9120`, `utils.ts:1503-1528` |

### Gaps Found

| # | Gap | Severity |
|---|-----|----------|
| G1 | `fs-check-service-area` — adapter has it, no route or tool exposed | Medium |
| G2 | `fs-get-company-info` — adapter has it, no route or tool | Low |
| G3 | No HCP-specific system prompt — uses Jobber prompt verbatim | High |
| G4 | Service zones not synced from HCP API to Location.serviceAreas | Medium |
| G5 | No webhook subscriptions for real-time sync | Low (future) |

---

## 2. Bug Fixes Required

### B1: Hardcoded `externalPlatform: 'jobber'`

`field-service-tools.ts` lines 212, 225 — both update/create paths in the Caller upsert:
```typescript
// CURRENT: externalPlatform: 'jobber',
// FIX:
const platform = adapter.getPlatformName();
// Then use: externalPlatform: platform,
```

Also fix `externalCustomerUrl` — currently Jobber-specific.

### B2: Jobber Base64 ID Decode

`field-service-tools.ts` lines 414-421, 582-587 — decodes Jobber EncodedId to build URL.

**Fix**: Extract a `buildExternalRequestUrl(platform, id)` helper:
- `jobber` → base64 decode → `https://secure.getjobber.com/requests/{numericId}`
- `housecallpro` → return `undefined` (no known public URL pattern)

### B3-B4: System Prompt Hardcoded for Jobber

`server.ts:9063-9142` — the entire `fsInstructions` block says "JOBBER", references "Jobber EncodedId", etc.

`utils.ts:1466-1582` — the `case 'jobber': case 'housecall-pro':` workflow section also uses Jobber language.

**Fix**: Make platform-conditional. Key differences:

| Aspect | Jobber | Housecall Pro |
|--------|--------|---------------|
| Platform name | "Jobber" | "Housecall Pro" |
| ID format | Base64 EncodedId `Z2lkOi8v...` | Simple string ID |
| Service area check | Text match vs AREAS SERVED | `fs_check_service_area` tool (zip code) |
| Lead creation | `property_id` required | `address` or `address_id` |
| Assessment entity | Jobber Assessment | HCP Estimate (scheduled) |
| Availability API | Gap analysis (computed) | Dedicated Booking Windows API |
| Estimate approval | UNSUPPORTED_OPERATION | `fs_approve_estimate` works |

---

## 3. HCP Service Zones vs Manual Service Areas

### Current: All platforms use `Location.serviceAreas` (manual city/county picker in onboarding)

### Problem: HCP has native `GET /service_zones?zip_code=X` — users maintain zones in HCP already

### Solution: Hybrid approach

- **HCP connected** → voice agent uses `fs-check-service-area` tool (zip code lookup, authoritative)
- **Jobber/GCal/None** → voice agent uses text match against AREAS SERVED (current behavior)
- **LocationsPage** → add "Sync from Housecall Pro" button when HCP connected
- **OnboardingPage Step 2** → show info banner: "Service areas managed in Housecall Pro"

### Implementation

1. Add `POST /internal/tools/fs/check-service-area` route
2. Add `fs-check-service-area` to HCP tool list in server.ts
3. Add HCP-specific prompt: "Call fs_check_service_area with ZIP code instead of text matching"
4. Add `POST /me/locations/:id/sync-service-zones` endpoint for frontend sync button
5. Add sync button to LocationsPage when HCP connected

---

## 4. `autoScheduleAssessment` and `includePricing` with HCP

Both flags live in `agents.config` JSONB and are **platform-agnostic**.

### autoScheduleAssessment

- **true**: Agent calls `fs_check_availability` → `fs_reschedule_assessment` (HCP: `PUT /jobs/{id}/schedule`)
- **false**: "Our team will reach out to schedule"
- Already implemented in HousecallProAdapter.rescheduleAssessment() — no changes needed

### includePricing

- **true**: Agent mentions prices from `fs_get_services` (HCP Price Book, `unit_price` in cents → dollars)
- **false**: "Pricing depends on the specifics"
- Already handled in prompt template — no changes needed

---

## 5. Entity Nomenclature & UI/UX Changes

### Sidebar (Already Done)
- Jobber → "Service Requests" at `/service-requests`
- HCP → "Jobs" at `/jobs`
- GCal → "Appointments" at `/appointments`

### Pages Needing Changes

| Page | Change |
|------|--------|
| **LocationsPage** | Add "Sync Service Zones" button (HCP only) |
| **OnboardingPage Step 2** | Info banner when HCP connected |
| **OnboardingPage Step 4** | Future: pre-populate services from HCP Price Book |

### Pages Working As-Is (No Changes)
- ServiceRequestsPage, JobsPage — use unified adapter types
- IntegrationsPage — HCP card already works
- DashboardPage — call-centric, not platform-specific
- CallersPage, CallerDetailPage — platform-agnostic

---

## 6. Phased Implementation Plan

### Phase 1: Bug Fixes (Required for Launch) — 1-2 days

| Task | Description |
|------|-------------|
| P1-1 | Fix `externalPlatform: 'jobber'` → dynamic from adapter |
| P1-2 | Extract `buildExternalRequestUrl()` helper for platform-aware URLs |
| P1-3 | Make `fsInstructions` in server.ts platform-aware (header, IDs, platform name) |
| P1-4 | Make workflow section in utils.ts platform-aware |
| P1-5 | Test `autoScheduleAssessment` + `includePricing` with HCP adapter |

### Phase 2: Service Zones & Tools (Pre-Launch) — 2-3 days

| Task | Description |
|------|-------------|
| P2-1 | Add `fs-check-service-area` route in field-service-tools.ts |
| P2-2 | Add tool to HCP tool list + prompt instructions |
| P2-3 | Add `sync-service-zones` API endpoint |
| P2-4 | Add sync button to LocationsPage |
| P2-5 | OnboardingPage Step 2 info banner |

### Phase 3: Expanded Tools (Post-Launch) — 1-2 days per group

| Task | Tools |
|------|-------|
| P3-1 | Jobs: `fs-get-jobs`, `fs-get-job`, `fs-add-note-to-job`, `fs-cancel-job` |
| P3-2 | Appointments: `fs-get-appointments`, `fs-reschedule-appointment`, `fs-cancel-appointment` |
| P3-3 | Estimates: `fs-get-estimates`, `fs-accept-estimate`, `fs-decline-estimate` |
| P3-4 | Billing: `fs-get-invoices`, `fs-get-account-balance` |

### Phase 4: Advanced (Future)

- Webhook subscriptions for real-time sync
- Lead conversion (`POST /leads/{id}/convert`)
- OAuth 2.0 (when HCP partnership formalized)
- Multi-location HCP support

---

## 7. Database — No Schema Changes Needed

| Model | HCP Usage |
|-------|-----------|
| `OrganizationIntegration` | Stores API key in `accessToken` / `config.apiKey` |
| `Location.serviceAreas` | Synced from HCP zones (Phase 2) |
| `Caller.externalPlatform` | Will store `'housecallpro'` (fix B1) |
| `CallRecord.externalRequestId` | Stores HCP lead ID |

---

## 8. Testing Checklist

- [ ] HCP API key connect flow (frontend → `POST /me/integrations/api-key`)
- [ ] `fs-get-customer-by-phone` returns HCP customer
- [ ] `fs-create-customer` creates HCP customer + syncs to local Caller with `externalPlatform: 'housecallpro'`
- [ ] `fs-create-property` creates HCP address
- [ ] `fs-create-service-request` creates HCP lead (not Jobber request)
- [ ] `fs-check-availability` returns HCP booking windows
- [ ] `fs-reschedule-assessment` schedules HCP estimate via `PUT /jobs/{id}/schedule`
- [ ] `fs-get-services` returns HCP Price Book services with correct pricing
- [ ] `fs-check-service-area` returns correct zone match (Phase 2)
- [ ] System prompt says "Housecall Pro" not "Jobber" when HCP connected
- [ ] System prompt uses simple ID instructions (not base64 EncodedId)
- [ ] `autoScheduleAssessment=true` → agent schedules assessment via HCP
- [ ] `includePricing=false` → agent does not mention prices
- [ ] Sidebar shows "Jobs" when HCP connected
- [ ] Disconnect flow works: `DELETE /me/integrations/housecall-pro`

---

## 9. HCP Advantages to Leverage

| Feature | Benefit | When |
|---------|---------|------|
| **Booking Windows API** | No gap analysis needed — dedicated availability | Phase 1 (already using) |
| **Service Zones** | Authoritative zip-code-level service area check | Phase 2 |
| **Estimate Approve/Decline** | Caller can approve quotes over the phone | Phase 3 |
| **Single-call Lead Creation** | `POST /leads` with inline customer+address | Phase 1 (already using) |
| **Price Book** | Rich service catalog with pricing | Phase 1 (already using) |
| **Company API** | Business hours/location from API (not just Google) | Phase 3 |
