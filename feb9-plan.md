# Tomorrow's Plan (Feb 9, 2026)

> **Goal:** Fix staging web UI, complete staging validation, unblock production deploy.

---

## ✅ Step 1: Fix Redirect Loop (~5 min) - COMPLETED

**ROOT CAUSE FOUND & FIXED (Feb 9, 2026):** The custom `fetch` wrapper in `supabase-auth.ts` used `require('https')` — a CommonJS call in an ESM module. This crashed with `require is not defined` on every `auth.getUser()` call → 401 on every authenticated request → redirect loop.

**Fix Applied:** Removed the broken custom fetch wrapper from `~/callsaver-api/src/services/supabase-auth.ts`. The `NODE_TLS_REJECT_UNAUTHORIZED=0` env var already handles SSL in development, making the wrapper unnecessary.

**Deployment:**
- ✅ Backend fix deployed to staging (new Docker image pushed to ECR, ECS redeployed)
- ✅ Frontend debug hacks reverted, clean frontend deployed to staging
- ✅ Staging validation passed - no more redirect loops

### Background: known past issue (cuid vs email)

If after fixing the keys you still get errors, the other known issue is: auth middleware (`auth.ts:49`) looks up users by **email**, then `/me/organization` (`server.ts:1527`) queries `organizationMember` by **`userId` (cuid)**. If the user exists in Supabase but **not in the Prisma `User` table**, auth returns 401. If the user exists in Prisma but has **no `OrganizationMember` record**, it returns 404.

### Debug tool

A debug page was added to `SignInPage.tsx`: navigate to `/sign-in?debug=true` to see session state, sign out, and test `/me/organization` directly. **Remove this debug code before production.**

---

## ✅ Step 2: Revert 6 Debug Hacks - COMPLETED

All debug hacks have been reverted and the clean frontend deployed to staging:

| # | File | Status |
|---|------|--------|
| 1 | `src/components/routing/AuthenticatedRoute.tsx` | ✅ Reverted |
| 2 | `src/components/layout/authenticated-layout.tsx` | ✅ Reverted |
| 3 | `src/components/routing/OnboardingGate.tsx` | ✅ Reverted |
| 4 | `src/components/routing/PublicRoute.tsx` | ✅ Reverted |
| 5 | `src/pages/SignInPage.tsx` | ✅ Reverted (debug UI removed) |
| 6 | `src/main.tsx` | ✅ Reverted |

> **Note:** Debug UI at `/sign-in?debug=true` has been removed.

---

## ✅ Step 3: Update DocuSeal SMTP Credentials (~15 min) - COMPLETED

```bash
# COMPLETED Feb 9, 2026:
# - SMTP password updated in /opt/docuseal/.env
# - SMTP password updated in /opt/docuseal/docker-compose.yml  
# - DocuSeal containers restarted
# - SMTP authentication tested and verified
# - Both external and in-container tests passed
```

Email sending is now ready from DocuSeal admin panel at `https://forms.callsaver.ai`.

---

## ✅ Step 4: Complete Staging Validation (1.22) (~30 min) - COMPLETED

**Staging validation PASSED:**
- [x] Log in via magic link → dashboard loads without loops ✅
- [x] Hit API endpoints (locations, stats) ✅
- [x] Verify DocuSeal API reachable from backend ✅
- [x] Magic link login works ✅
- [x] API health endpoint responds ✅
- [x] No redirect loops ✅

**Staging is fully validated and ready for production deployment.**

---

## ✅ Step 5: Commit & Push - COMPLETED

**All changes committed and pushed (Feb 9, 2026):**
- `callsaver-api` (main): supabase-auth.ts fix, VAPID secrets in CDK, .env updates
- `callsaver-frontend` (staging): Debug hacks reverted, debug UI removed
- `callsaver-landing` (main): Cal.com embed updates

**Repository housekeeping also completed:**
- Renamed `callsaver-web-ui` folder → `callsaver-frontend` (GitHub repo: `CallSaver-ai/frontend`)
- Renamed GitHub repo `callsaver-landing` → `landing-page` (GitHub: `CallSaver-ai/landing-page`)
- Fixed critical branch issue: `main` branch had old code, `fuckyourself` branch had correct code. Reset `main` to correct commit (`43a62e1`) and force pushed.
- Deleted unprofessional `fuckyourself` branch from remote
- Set up GitHub Actions workflow for automatic Vercel deployment on push to `main`
- Installed GitHub CLI (`gh`) on dev machine
- Configured Vercel environment variables (GrowthBook, GA4, ContentSquare, Cal.com)
- Deleted duplicate `landing-page` Vercel project (kept `callsaver-landing`)

---

## ✅ Step 6: QR Code Testing (1.8) - COMPLETED

**QR code scan tracking tested end-to-end on staging (Feb 9, 2026):**

- ✅ Database migration applied — `qr_codes`, `qr_variants`, `qr_scan_events`, `cal_bookings` tables exist
- ✅ Seed data created with real variant names (`bcard` short code for business cards)
- ✅ `QR_IP_HASH_SECRET` set in staging secrets
- ✅ QR code image generated (`qr-bcard-staging.png` via `generate-qr.js`)
- ✅ `GET /q/bcard` returns 302 redirect with `qr_sid`, UTM params, and `set-cookie` header
- ✅ `/book` page loads with Cal.com inline embed (`alexsikand/demo`, `forwardQueryParams: true`)
- ✅ Scan events recorded in database with correct fields (variant link, session_id, ip_hash, user_agent, is_bot, landing_url)
- ✅ Vercel geo fields confirmed null as expected (API is on ECS, not Vercel edge)

**Decision pending:** Order business cards with staging API QR codes now, or wait for production API deployment. Production URL would be `https://api.callsaver.ai/q/bcard` instead of `https://staging.api.callsaver.ai/q/bcard`.

**Comprehensive QR system documentation:** See `qr-code-system.md`

---

## 🟢 Step 7: Landing Page Review & Polish - MOSTLY COMPLETED

**Goal:** Full landing page audit, compliance, analytics verification, and content updates.

### 7a. Compliance & Structure
1. Full review of landing page — fix any issues found
2. Add cookie consent banner if required for CCPA compliance
3. Decide footer LLC name: Wyoming holding LLC (Prosimian Labs LLC) vs DBA (CallSaver)

### 7b. Links & Navigation ✅ COMPLETED
4. ✅ Fixed Cal.com embed link to `alexsikand/demo` (was `azharhuda/demo`) in 4 files
5. ✅ Verified all anchor `#` tags — found and fixed ScrollToCTAButton bug (cta-section → book-a-call)
6. ✅ Verified "Book a Call" button scrolls to Cal.com CTA section correctly

### 7c. Analytics & Tracking ✅ PARTIALLY COMPLETED
7. ✅ GA4 and ContentSquare verified working (GA4 showing 3 users in last 30min). GrowthBook connected but A/B testing deferred.
8. Configure GA4 events for FAQ expansion clicks (track which FAQs users care about) — PENDING
9. ✅ Implemented GA4 conversion tracking for Cal.com embed: `bookingSuccessfulV2` → `demo_booking_completed`, UTM forwarding, `bookerViewed` events
10. Run PageSpeed Insights analysis on the site — PENDING

### 7d. Content Updates
11. Update FAQ content to reflect current application state
12. Review website text copy — align with Hormozi principles
13. Design GrowthBook A/B tests for the hero headline
14. Update features and integrations sections

### 7e. Media & Visuals
15. Replace web dashboard image with updated screenshot (eventually a ScreenStudio video on Mac)
16. Replace audio demo section with a better audio sample (record via LiveKit web interface for crisp caller audio)
17. Fix geobanner animation timing (should animate in from top alongside nav bar)
18. Small cosmetic fixes TBD
19. Possibly update colors

### 7f. Code Cleanup
20. Delete dead code, unused images, and template leftovers (site built from template — only using single-page app + privacy policy, TOS, careers pages)

### 7g. SEO & Content Marketing
21. Add more blog articles and optimize for SEO

---

## 🟡 Step 8: Business Incorporation - QUEUED

Incorporate **Prosimian Labs LLC** in Wyoming through **Northwest Registered Agent** (task 2.1). The old LLC has two members and co-founder Azhar (who dropped out) cannot be removed — a new single-member LLC is required.

---

## ⏳ Step 9: Start Production Deploy - DEFERRED

**Staging validated ✅ | All repos committed ✅ | Landing page CI/CD set up ✅**

Begin deploying production infrastructure (task 1.13):

1. Deploy `Callsaver-Network-production`
2. Deploy `Callsaver-Storage-production`
3. Deploy `Callsaver-Backend-production`
4. Deploy `Callsaver-Agent-production`
5. Create production Secrets Manager entries
6. Deploy production Supabase instance (task 1.20)
7. Deploy production web UI (task 1.14)
