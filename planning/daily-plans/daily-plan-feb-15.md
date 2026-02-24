# Daily Plan — Feb 15, 2026

## Overview

Eight onboarding/provisioning issues discovered during E2E staging testing on Feb 14.
This document captures investigation findings, root causes, and proposed fixes for each.

---

## Issue #1: Cal.com Booking Fields Split (`businessName` + `businessLocation`)

**Priority:** HIGH  
**Status:** Investigation complete — ready to implement

### Problem
Cal.com booking form currently has a single combined field `businessNameAndLocation` (e.g., "Acme Plumbing, Sacramento CA"). The form is being updated to split this into two separate fields: `businessName` and `businessLocation`.

### Root Cause
The Cal.com booking form was originally designed with one field. A split improves data quality and Google Places search accuracy.

### Files Affected
| File | Lines | What Changes |
|------|-------|--------------|
| `callsaver-api/src/server.ts` | ~14311 | Cal.com webhook handler extracts `businessNameAndLocation` from `booking.responses` |
| `callsaver-api/src/services/cal-booking-pipeline.ts` | 1-18 | `CalBookingPipelineInput` interface has `businessNameAndLocation` field |
| `callsaver-api/src/services/cal-booking-pipeline.ts` | ~514-530 | `createAttioCompany` uses `input.businessNameAndLocation` for Attio company name |
| `callsaver-api/src/services/cal-booking-pipeline.ts` | ~705-750 | `runCalBookingPipeline` uses it for Google Places search + logging |

### Proposed Fix
1. Update `CalBookingPipelineInput` interface: replace `businessNameAndLocation` with `businessName` and `businessLocation`.
2. Update Cal.com webhook handler in `server.ts` to extract both new fields from `booking.responses`.
3. Update `searchGooglePlaces()` to use `businessName` + `businessLocation` for better search (e.g., `"Acme Plumbing" near "Sacramento, CA"`).
4. Update `createAttioCompany()` to use `businessName` for company name.
5. Backward-compat: if old `businessNameAndLocation` is present (from old form), fall back to it.

### Estimated Effort
~30 min code changes + deploy

---

## Issue #2: Email Footer Company Name Change

**Priority:** MEDIUM  
**Status:** Investigation complete — ready to implement

### Problem
All transactional email footers display "CallSaver AI LLC" with the old address. Need to update to "Prosimian Labs LLC" with new address.

### Root Cause
Hardcoded company name and address in the MJML master template.

### Files Affected
| File | Lines | What Changes |
|------|-------|--------------|
| `callsaver-api/src/email/templates/master.mjml` | ~160, ~178 | Footer text: company name + address (appears in 2 conditional blocks) |

### Proposed Fix
1. Replace `CallSaver AI LLC` → `Prosimian Labs LLC` in both footer blocks.
2. Update address from `30 N Gould St, Ste N, Sheridan, Wyoming 82801` to the new Prosimian Labs LLC address.
3. Rebuild email templates after change.

### Estimated Effort
~5 min

---

## Issue #3: Stripe Checkout Redirect URL Uses Production Instead of Staging

**Priority:** HIGH  
**Status:** Investigation complete — **root cause identified**

### Problem
When Stripe checkout email is sent in staging, the `success_url` and `cancel_url` point to `https://app.callsaver.ai` (production) instead of `https://staging.app.callsaver.ai`.

### Root Cause
**The `getCurrentEnvironmentUrls()` function in `config/loader.ts` (line 548-585) checks `NODE_ENV === 'production'` first.** The Dockerfile sets `ENV NODE_ENV=production` (line 58) for all environments. This means staging ECS tasks also have `NODE_ENV=production`, so the function always returns production URLs — the `APP_ENV === 'staging'` check on line 564 is never reached.

**Key code path:**
- `stripe-checkout-v2.ts:58` calls `getCurrentEnvironmentUrls()`
- `stripe-checkout-v2.ts:117` uses `envUrls.baseUrl` for `success_url`
- `config/loader.ts:553` returns production URLs when `NODE_ENV === 'production'`

### Files Affected
| File | Lines | What Changes |
|------|-------|--------------|
| `callsaver-api/src/config/loader.ts` | 548-585 | `getCurrentEnvironmentUrls()` — priority order of env checks |

### Proposed Fix (Option A — Recommended)
Swap the check order: check `APP_ENV === 'staging'` **before** `NODE_ENV === 'production'`:

```typescript
export function getCurrentEnvironmentUrls() {
  const nodeEnv = process.env.NODE_ENV;
  const appEnv = process.env.APP_ENV;
  
  // Staging: check APP_ENV FIRST (since NODE_ENV=production in Docker)
  if (appEnv === 'staging') {
    return { /* staging URLs */ };
  }
  
  // Production: only when NODE_ENV is 'production' AND APP_ENV is NOT 'staging'
  if (nodeEnv === 'production') {
    return { /* production URLs */ };
  }
  
  // Local development
  // ...
}
```

### Proposed Fix (Option B — Also valid)
Ensure `APP_ENV=staging` is set in the staging ECS task definition environment variables. This alone doesn't fix the issue because the `NODE_ENV` check still runs first, but combined with Option A it provides explicit environment tagging.

### Estimated Effort
~5 min code change — **but affects ALL environment URL resolution across the entire API**. Must verify `APP_ENV=staging` is set in staging ECS task definition.

---

## Issue #4: Welcome Email Magic Link Uses Production URL Instead of Staging

**Priority:** HIGH  
**Status:** Investigation complete — **same root cause as Issue #3**

### Problem
Welcome email magic link and fallback sign-in URL point to `https://app.callsaver.ai` instead of `https://staging.app.callsaver.ai` in staging.

### Root Cause
**Same as Issue #3.** Both `provision-handler.ts` and `provision-execution.ts` call `getCurrentEnvironmentUrls()` which returns production URLs due to `NODE_ENV=production` in Docker.

### Files Affected
| File | Lines | What Changes |
|------|-------|--------------|
| `callsaver-api/src/handlers/provision-handler.ts` | 51-68, 423-426, 283-286 | `getMagicLinkRedirectUrl()` and fallback sign-in URL |
| `callsaver-api/src/services/provision-execution.ts` | 60-77, 283-286 | Same pattern — `getMagicLinkRedirectUrl()` and fallback URL |
| `callsaver-api/src/email/config/email-config.ts` | 294-297 | `getCurrentEnvironmentUrls()` for `dashboardUrl` in email service |

### Proposed Fix
**Fixed by Issue #3's fix.** No additional code changes needed — all these files call the same `getCurrentEnvironmentUrls()` function.

### Estimated Effort
0 min (covered by Issue #3)

---

## Issue #5: `/me/complete-onboarding` 404 Error

**Priority:** HIGH  
**Status:** Investigation complete — needs route registration check

### Problem
Frontend calls `POST /me/complete-onboarding` during onboarding completion, but receives a 404 response.

### Root Cause (Likely)
The contract exists at `callsaver-api/src/contracts/user-onboarding.contract.ts` defining `POST /me/complete-onboarding`, but the actual route handler may not be registered in `server.ts`. The 16,807-line `server.ts` file was searched and the handler was not found in the sections examined. Possible causes:
1. Route handler was never implemented (contract-only).
2. Route handler exists but is registered via a different pattern (e.g., a router module).
3. Route was accidentally removed.

### Files Affected
| File | Lines | What Changes |
|------|-------|--------------|
| `callsaver-api/src/server.ts` | TBD | Need to add/verify route handler for `POST /me/complete-onboarding` |
| `callsaver-api/src/contracts/user-onboarding.contract.ts` | 1-104 | Contract definition exists |
| `callsaver-frontend/src/context/user-state-provider.tsx` | TBD | Frontend calls `completeOnboarding()` |

### Proposed Fix
1. Search `server.ts` definitively for `complete-onboarding` to confirm missing.
2. If missing, implement the handler:
   - Require auth
   - Update `user.onboardingCompleted = true` in Prisma
   - Return success with user object
3. If the frontend is using the generated API client, ensure the OpenAPI spec includes this endpoint.

### Estimated Effort
~20 min

---

## Issue #6: Call Forwarding Shows `[your CallSaver number]` Placeholder

**Priority:** MEDIUM  
**Status:** Investigation complete — root cause identified

### Problem
On the call forwarding step (Step 7, Path A) of onboarding, the dial codes show `[your CallSaver number]` or `[10-digit number]` instead of the actual provisioned number.

### Root Cause
The frontend code at `OnboardingPage.tsx:2229-2232` sets:
```typescript
const callsaverNum = callsaverNumber || '';
const phoneDigits = callsaverNum.replace(/\D/g, '');
const hasPhoneNumber = !!callsaverNum;
const formattedPhone = hasPhoneNumber ? formatPhoneNumber(callsaverNum) : '[your CallSaver number]';
```

The `callsaverNumber` state is populated at line 940-953 by calling `apiClient.user.getAgent({ locationId })` and extracting `agentData.phoneNumber`. If the agent API doesn't return a phone number (e.g., the `phoneNumber` field isn't populated on the agent record, or the API response shape doesn't match), `callsaverNumber` stays `null` and the placeholder is shown.

During provisioning (`provision-execution.ts:439-449`), the Agent record is created with `voiceId: 'Katie'` but **no phone number field**. The phone number is stored on the `TwilioPhoneNumber` record linked to the Location, not on the Agent.

### Files Affected
| File | Lines | What Changes |
|------|-------|--------------|
| `callsaver-frontend/src/pages/OnboardingPage.tsx` | 940-953 | Fetches `agentData.phoneNumber` — needs to use correct source |
| `callsaver-api/src/server.ts` | TBD | `GET /me/agent` or `GET /me/locations` — need to return provisioned phone number |

### Proposed Fix
**Option A (Recommended):** Update the agent API endpoint to include the provisioned Twilio phone number by joining through `Location → TwilioPhoneNumber`.

**Option B:** Use the location's phone number from the `/me/locations` response (which the frontend already fetches) instead of calling the agent endpoint.

### Estimated Effort
~20 min

---

## Issue #7: Organization Audio Samples Not Generated During Provisioning

**Priority:** LOW (not blocking — defaults work)  
**Status:** Investigation complete — **graceful fallback already implemented**

### Problem
During onboarding, voice preview audio samples use generic defaults instead of organization-specific samples with the business name.

### Root Cause
The voice sample generation script at `callsaver-api/src/scripts/generate-organization-voice-samples.ts` is NOT called during provisioning. However, **the system already has a graceful fallback**:

**How it works (server.ts:16264-16296):**
1. `/me/voice-samples` endpoint checks if org-specific samples exist via `checkSamplesExist(attioCompanyId)`
2. If org-specific samples exist: returns URLs from `s3://callsaver-ai-voice-samples/{attioCompanyId}/{voiceName}.wav`
3. If NOT: **falls back to default samples** from `s3://callsaver-ai-voice-samples/default/{voiceName}.wav`

**The defaults work fine** — they're generic greetings without the business name. Org-specific samples would say "Hello, thanks for calling {BusinessName}..." but this is a nice-to-have, not a blocker.

### Files Affected
| File | What Changes |
|------|--------------|
| `callsaver-api/src/scripts/generate-organization-voice-samples.ts` | Standalone script (exports functions for use) |
| `callsaver-api/src/services/provision-execution.ts` | Could optionally call `generateOrganizationVoiceSamples()` |
| `callsaver-api/src/server.ts` | 16264-16296 — already has fallback logic |

### Proposed Fix
**Option A (Recommended — defer to post-launch):** Leave as-is. Default samples provide adequate UX. Generate org-specific samples as a background job after launch when we have time.

**Option B (If time permits):** Import and call `generateOrganizationVoiceSamples(attioCompanyId)` at the end of `provision-execution.ts` after organization creation. The function is already exported and ready to use. Make it fire-and-forget (don't block provisioning on Cartesia API).

**Option C (Best UX — future):** Queue a background job to generate samples asynchronously after provisioning completes.

### Estimated Effort
- Option A: 0 min (no change)
- Option B: ~15 min (import + call in provision-execution.ts)
- Option C: ~45 min (background job infrastructure)

---

## Issue #8: Auto-Format Phone Number in Transfer Number Field

**Priority:** MEDIUM  
**Status:** Investigation complete — ready to implement

### Problem
The "Transfer Number" input field on Step 7 (Path B) of onboarding accepts raw phone number input without auto-formatting. Users must type the number manually without visual feedback.

### Root Cause
The input at `OnboardingPage.tsx:2017-2027` is a plain `<Input type="tel">` with no formatting:
```tsx
<Input
  type="tel"
  placeholder="(555) 123-4567"
  value={transferPhoneNumber}
  onChange={(e) => setTransferPhoneNumber(e.target.value)}
  ...
/>
```

The frontend already has `formatPhoneNumber()` in `lib/phone-utils.ts` for display formatting, but it's not applied as-you-type to the input.

### Files Affected
| File | Lines | What Changes |
|------|-------|--------------|
| `callsaver-frontend/src/pages/OnboardingPage.tsx` | 2017-2027 | Transfer phone number input |
| `callsaver-frontend/src/lib/phone-utils.ts` | 1-24 | Existing format utility |

### Proposed Fix
Apply `formatPhoneNumber()` as-you-type in the `onChange` handler. Keep the raw digits in state for API submission, but display formatted:

```tsx
const handlePhoneChange = (e: React.ChangeEvent<HTMLInputElement>) => {
  const raw = e.target.value.replace(/\D/g, '');
  // Limit to 10 digits (or 11 with country code)
  const limited = raw.slice(0, 11);
  setTransferPhoneNumber(limited);
};

// Display formatted
<Input
  type="tel"
  placeholder="(555) 123-4567"
  value={formatPhoneNumber(transferPhoneNumber)}
  onChange={handlePhoneChange}
/>
```

Alternatively, use `react-number-format` or `react-phone-number-input` for a more robust solution, but the simple approach above matches existing styling.

### Estimated Effort
~10 min

---

## Implementation Priority Order

| Order | Issue | Priority | Effort | Blocked By |
|-------|-------|----------|--------|------------|
| 1 | #3/#4: Environment URL fix | HIGH | 5 min | Verify APP_ENV in staging ECS |
| 2 | #5: `/me/complete-onboarding` 404 | HIGH | 20 min | — |
| 3 | #1: Cal.com booking fields split | HIGH | 30 min | Cal.com form update |
| 4 | #6: Call forwarding placeholder | MEDIUM | 20 min | — |
| 5 | #2: Email footer company name | MEDIUM | 5 min | New address from user |
| 6 | #8: Phone number auto-format | MEDIUM | 10 min | — |
| 7 | #7: Cartesia audio samples | MEDIUM | 45 min | — |

**Total estimated effort: ~2.5 hours**

---

## Notes

- Issues #3 and #4 share the same root cause and are fixed by a single 5-line change in `config/loader.ts`.
- Issue #5 needs verification — the handler may exist in an unexamined section of `server.ts` (16,807 lines).
- Issue #7 (Cartesia) is the largest effort item and could be deferred to a follow-up sprint if generic voice samples provide adequate UX.
- All issues are in `callsaver-api` or `callsaver-frontend` repos — no infrastructure changes needed.
