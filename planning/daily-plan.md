# Daily Plan: Immediate Next Steps

> **Purpose:** Daily execution plan — current focus and immediate tasks
> **For all outstanding tasks:** See active-plan.md
> **Complete reference:** See master-plan.md
> **Date:** February 11, 2026 (updated 3:56pm)

---

## Current Roadmap

**Stripe Catalog Setup → Webhook Configuration → LiveKit S3 → Local E2E Testing → Production Deploy**

Business formation (Prosimian Labs LLC) is **substantially complete** — LLC formed, OA signed, EIN obtained, Mercury submitted, Stripe live. CA foreign LLC registration (LLC-5) submitted, waiting for approval. DBA filing blocked on CA LLC-12 (Statement of Information).

---

## ✅ Completed Today (Feb 11)

### DocuSeal Documentation Consolidation
- ✅ **Comprehensive DOCUSEAL_SETUP.md** — Created canonical setup & operations guide in `~/callsaver-docuseal/`
- ✅ **Webhook handler documentation** — Detailed `submission.completed` handler side effects (Attio fetch, Stripe customer/checkout creation, SES email)
- ✅ **Email template customization** — Added copy-paste-ready text templates for Signature Request (✍️), Documents Copy (📄), and Reminder (⏳) emails using `legal@callsaver.ai`
- ✅ **Pro plan section** — Documented Pro features needed (HTML emails + company logo, $240/yr), when to purchase
- ✅ **Deleted 9 superseded docs** — Template setup, webhook guide, quick start, workflow testing, MSA version control, etc.
- ✅ **Archived 1 doc** — `DOCUSEAL_STRIPE_TESTING_STEPS.md` → `docs/archive/testing/`
- ✅ **Simplified `~/callsaver-docuseal/README.md`** — 267 → 60 lines, pointer to DOCUSEAL_SETUP.md + CDK quick reference

### Email Config Updates
- ✅ **Removed redundant "CallSaver" from email subjects** — 5 subjects updated in `email-config.ts`
- ✅ **Magic link subject fixed** — Changed to `🔑 Sign in with this link` (matches actual sent emails)

### Repo Organization
- ✅ **`~/production-launch-plan` reorganized** — Created `planning/`, `legal/`, `services/`, `qr-code/`, `website/`, `scripts/`, `archive/` subdirectories
- ✅ **Logo update script** — Moved `update-logos.sh` to `~/production-launch-plan/scripts/` (cross-repo utility)
- ✅ **README.md created** — Full documentation of repo structure and utilities
- ✅ **Backed up to GitHub** — `CallSaver-ai/launch-plan` repo with `.gitignore`
- ✅ **Deleted stale files** — `fonts-for-ubuntu/`, `docuseal-plan.md`, font evaluation files
- ✅ **Archived** — `debugging-supabase-auth-redirect-loops.md` → `archive/`

### Stripe Documentation Consolidation
- ✅ **Comprehensive STRIPE_SETUP.md** — Expanded to ~1050 lines, single canonical reference in `~/callsaver-api/docs/integrations/stripe/`
- ✅ **Created `setup-stripe-portal.ts`** — Programmatic billing portal configuration script (no manual Dashboard setup)
- ✅ **§1 Architecture Overview rewritten** — DocuSeal cross-reference, full provisioning flow diagram, state machine, integration architecture table
- ✅ **§5 Webhook side effects documented** — Every DB write, email, Slack notification, BullMQ job, CRM sync for all 6 webhook events
- ✅ **§6 Pricing Plans & Usage Billing** — New section with plan tables, implementation fee mechanics, Stripe Meters API, usage reporting flow
- ✅ **§9 Billing Portal** — Updated to reference `setup-stripe-portal.ts` instead of manual Dashboard steps
- ✅ **Doc audit executed** — Deleted 5 superseded files (3 docs + 2 legacy scripts), archived 5 to `docs/archive/`
- ✅ **`docs/integrations/stripe/`** now contains only `STRIPE_SETUP.md`

### Stripe Sandbox Inventory (verified via API)
- ✅ **Products:** 7 active products (Operator, Growth, Enterprise, AI Voice Usage, Implementation Fee, Additional Location, Review Management)
- ✅ **Prices:** 11 active prices with proper lookup keys (monthly + annual for all plans, metered usage, impl fee, add-ons)
- ✅ **Meter:** `mtr_test_61U47pu7Nmzf95mmE41GoKKfr9KQ54YK` (CallSaver Voice Minutes, sum aggregation)
- ✅ **Webhooks:** 2 endpoints configured (ngrok local + staging.api.callsaver.ai) with signing secrets
- ✅ **Portal config:** `bpc_1SQ5SJGoKKfr9KQ55TTg4ndE` — updated with staging return URL and business profile
- ✅ **Deactivated 5 duplicate/legacy products** (from earlier test runs)
- ✅ **.env updated** — publishable key, webhook secret (ngrok for local), success/cancel URLs

### LiveKit Infrastructure & Documentation
- ✅ **Created IAM user `callsaver-livekit-egress`** — Dedicated IAM user with `LiveKitEgressS3Access` inline policy scoped to `s3:PutObject`/`s3:PutObjectAcl`/`s3:ListBucket` on `callsaver-sessions-staging` and `callsaver-sessions-production`
- ✅ **Created `services/livekit-egress-setup.md`** — Comprehensive LiveKit Cloud & Egress setup documentation (architecture, env vars, S3 buckets, IAM config, dashboard steps)
- ✅ **Created `docs/ai-agent/LIVEKIT_AGENT.md`** — Comprehensive Python voice agent technical documentation (20 sections: architecture, system prompt generation, greeting logic, caller identification, AI provider pipeline, tool calls, silence detection, max call duration, call transfer, egress recording, deployment instructions)
- ✅ **Fixed production bucket naming** — Corrected `callsaver-sessions-production-us-west-1` → `callsaver-sessions-production` across all planning docs, IAM policy, and agent documentation

### Stripe Dunning & Compliance Fixes
- ✅ **STRIPE_SETUP.md §11 rewritten** — Trial statement descriptor compliance, Smart Retries interaction with webhooks, detailed dunning email sequence with template references, job config
- ✅ **Trial statement descriptor enabled** — `CALLSAVER* TRIAL OVER` on first post-trial charge (Visa/Mastercard compliance)
- ✅ **Smart Retries `attempt_count` guard** — `invoice.payment_failed` handler now skips duplicate dunning on retry attempts 2-8
- ✅ **Dunning worker type bugs fixed** — `amountDue`→`amount`, added `planName`, `suspensionDate` to all 4 email templates
- ✅ **`DunningEmailJobData` interface updated** — Added `planName`, `suspensionDate` (ISO string, Day 0 + 30 days)
- ✅ **`scheduleDunningEmails` updated** — Accepts `planName`, computes suspension date, passes both to all jobs
- ✅ **Org query fixed** — `invoice.payment_failed` handler now includes `plan: true` in Prisma query

### Legal Documents Alignment (Feb 11 afternoon)
- ✅ **URL convention unified** — All legal pages now use `/privacy-policy` and `/terms-of-service` across landing page, web app, MSA, Stripe portal, and DocuSeal
- ✅ **App Privacy Policy rewritten** (`~/callsaver-frontend/src/pages/PrivacyPage.tsx`) — Synced with MSA: entity info (Prosimian Labs LLC), full subprocessor list matching MSA §8 (added Anthropic, AssemblyAI, Supabase, Google Maps APIs, scheduling integrations), contact email fixed to `legal@callsaver.ai`, date updated to Feb 11 2026
- ✅ **App Terms of Service rewritten** (`~/callsaver-frontend/src/pages/TermsPage.tsx`) — Synced with MSA: entity info, acceptable use matching MSA §15, billing/trial/SLA sections added, governing law California, date updated
- ✅ **Landing page privacy policy** — Fixed section numbering (missing §10 renumbered)
- ✅ **Landing page TOS** — Fixed duplicate section numbering (§3-§13 → §3-§16), governing law changed Wyoming → California
- ✅ **MSA URLs updated** in `generate-msa-pdf.ts` (§6.2 and §22.1 now use `/privacy-policy` and `/terms-of-service`)
- ✅ **Frontend routes renamed** — `/terms` → `/terms-of-service`, `/privacy` → `/privacy-policy` in `App.tsx` + `login-form.tsx`
- ✅ **All doc references updated** — `STRIPE_SETUP.md`, `EMAIL_IMPLEMENTATION_PLAN.md`, `setup-stripe-portal.ts`

### Stripe Billing Portal Updates (Feb 11 afternoon)
- ✅ **Portal URLs updated to app.callsaver.ai** — Privacy/terms links now point to product pages (not marketing site)
- ✅ **Sandbox portal updated** (`bpc_1SQ5SJGoKKfr9KQ55TTg4ndE`) — `staging.app.callsaver.ai/privacy-policy` + `/terms-of-service`
- ✅ **Production portal CREATED** (`bpc_1SznC3K6cCQ0p7wduEKtDCLv`) — `app.callsaver.ai/privacy-policy` + `/terms-of-service`
- ✅ **Production portal login page:** `https://billing.stripe.com/p/login/28EaEYc343B6diOemG2cg00`

### AWS Secrets Manager — Stripe Secrets (Feb 11 afternoon)
- ✅ **Created 3 missing staging secrets:** `STRIPE_PUBLISHABLE_KEY`, `STRIPE_SUCCESS_URL`, `STRIPE_CANCEL_URL`
- ✅ **Created 4 production secrets:** `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY`, `STRIPE_SUCCESS_URL`, `STRIPE_CANCEL_URL`
- ✅ **Added `STRIPE_SECRET_KEY_LIVE`** to `~/callsaver-api/.env` for running production scripts locally
- ⏳ **5 production secrets deferred** (WEBHOOK_SECRET, METER_ID, 3× PRICE_*) — blocked on production catalog creation + webhook endpoint

### Previously Completed (Feb 10)
- ✅ S3 bucket audit & code updates across 4 repos
- ✅ IAM separation (dedicated `callsaver-docuseal-s3` user)
- ✅ Wyoming LLC Formation + CA Foreign LLC Registration submitted
- ✅ Landing Page Stripe Compliance + Navbar Scrolling fixes
- ✅ MSA Entity Name fix + Stripe Account Live

---

## 🎯 Next Steps (Feb 11 afternoon)

### Priority 1: Upload MSA Template to DocuSeal (4.11) — ✅ COMPLETED
- ✅ Regenerated MSA PDF (`MSA-2026-02-11-1634.pdf`) with updated URLs + local date/timestamp naming
- ✅ Uploaded to https://forms.callsaver.ai/admin → Templates
- ✅ Configured all template fields (5 Customer + 4 CallSaver, signing order set)
- ✅ Customized email templates in Settings → Personalization (Signature Request, Documents Copy, Reminder)

#### DocuSeal Field Setup Instructions

After uploading the MSA PDF, the embedded invisible field tags should be **auto-detected**. If not, create fields manually:

**Step 1:** Create two roles: **"Customer"** (First Party) and **"CallSaver"** (Second Party)

**Step 2:** Add Customer fields (First Party):

| Field Name | Type | Settings |
|------------|------|----------|
| Customer Legal Name | Text | Required, **Read-only** (pre-filled from Attio CRM) |
| Customer Company | Text | Required, **Read-only** (pre-filled from Attio CRM) |
| Customer Title | Text | Required, **Read-only** (pre-filled from Attio CRM) |
| Customer Date | Date | Required, Enable **"Set signing date"** |
| Customer Signature | Signature | Required |

**Step 3:** Add CallSaver fields (Second Party):

| Field Name | Type | Default Value | Settings |
|------------|------|---------------|----------|
| CallSaver Legal Name | Text | `Alexander Sikand` | Required, **Read-only** |
| CallSaver Title | Text | `Founder` | Required, **Read-only** |
| CallSaver Date | Date | — | Required, Enable **"Set signing date"** |
| CallSaver Signature | Signature | — | Required |

**Step 4:** Place all fields on the **signature section** at the bottom of the document (last page)

**Step 5:** Set signing order: Customer signs first → CallSaver countersigns

**Step 6:** Save template and verify the template name contains "MSA" (required for `getLatestMSATemplateId()` auto-detection)

### Priority 2: Stripe Remaining Tasks (3.2 + 3.3) — ✅ SUBSTANTIALLY COMPLETE
- ✅ Created comprehensive `STRIPE_SETUP.md` in `~/callsaver-api/docs/integrations/stripe/`
- ✅ Sandbox catalog verified — all products, prices, and meter exist
- ✅ Sandbox webhook endpoints created (ngrok + staging)
- ✅ Sandbox portal configuration updated with `staging.app.callsaver.ai` privacy/terms links
- ✅ **Production portal CREATED** (`bpc_1SznC3K6cCQ0p7wduEKtDCLv`) with `app.callsaver.ai` privacy/terms links
- ✅ Deactivated duplicate/legacy sandbox products
- ✅ `.env` updated with all Stripe keys + webhook secrets + `STRIPE_SECRET_KEY_LIVE`
- ✅ Trial statement descriptor enabled (compliance)
- ✅ Smart Retries + dunning code fixed (`attempt_count` guard, type bugs)
- ✅ **Uploaded logo** to Stripe Dashboard → Settings → Branding
- ✅ **Disabled Stripe built-in emails** in Settings → Emails (sandbox + live)
- ✅ **AWS Secrets Manager** — 9 staging Stripe secrets + 4 production Stripe secrets configured
- **Production remaining (blocked on deploy):**
  - Run `setup-stripe-catalog.ts --env=production` → creates products/prices/meter on live account
  - Create production webhook endpoint → `api.callsaver.ai/webhooks/stripe`
  - Add remaining 5 production secrets (WEBHOOK_SECRET, METER_ID, 3× PRICE_*)

### Priority 3: AWS Activate Credits ($1,000) — ✅ APPLIED
- ✅ Application submitted Feb 11, 2026
- ✅ Selected "Founders Package" ($1,000) with "No funding" status
- ⏳ Awaiting approval (7-10 business days)
- Credits will auto-apply to AWS account `836347236108`
- Covers all AWS services including S3, ECS, SES, Amazon Bedrock (Claude, etc.)

### Priority 4: LiveKit S3 Credentials (1.21) — ✅ COMPLETE
- ✅ Created `callsaver-livekit-egress` IAM user with scoped S3 policy
- ✅ Created comprehensive `services/livekit-egress-setup.md` documentation
- ✅ Created comprehensive `docs/ai-agent/LIVEKIT_AGENT.md` (Python voice agent docs)
- ✅ **No manual LiveKit Cloud dashboard step needed** — the Python voice agent handles egress programmatically with per-request S3 credentials passed via the LiveKit Egress API. Dashboard S3 configuration is unnecessary.

### Priority 5: Figtree Font Size Audit (4.7c) — 🔄 IN PROGRESS
- Manual visual review by Alex of `~/callsaver-landing` and `~/callsaver-frontend`
- Adjust sizes where Figtree renders smaller than Inter
- Will share feedback after review

### Priority 6: UI Improvements (New)

**4.12 — Replace Google Maps with MapCN**
- Swap Google Maps in location cards (`~/callsaver-frontend`) with [MapCN](https://www.mapcn.dev/)
- More custom/modern feel vs boring default Google Maps
- Bonus: may eliminate `VITE_GOOGLE_MAPS_API_KEY` frontend exposure + reduce bundle size

**4.12a — LiveKit Agents-UI: Landing Page Audio Visualizer — ✅ COMPLETED (Feb 11, 2026)**
- Replaced Wave.js with standalone LiveKit-inspired Aura shader visualizer (WebGL + Web Audio API)
- Also fixed: geo banner + header combined overlay slide-in animation, nav/banner font 18px/600, button alignment, hover transition, GA4 events, GrowthBook error suppression, dev FontControlWidget
- Commit `7b7e79d`

**4.12b — LiveKit Agents-UI: Interactive Voice Agent in Frontend**
- Add in-browser voice agent interaction to per-location settings in `~/callsaver-frontend` (`LocationsPage`)
- Currently users can only play a sample — this lets them **actually talk to their configured agent** via WebRTC
- No phone/Twilio needed — connects directly to LiveKit Python agent API
- Requires: room token generation endpoint, `@livekit/components-react`, start/stop controls + audio viz

---

## 🎨 Logo Font Update — ✅ COMPLETED (Feb 11, 2026)

**Simplified to 2 variants × 3 formats = 6 files:**
- `black-logo.{svg,png,webp}` — Black text (light backgrounds)
- `white-logo.{svg,png,webp}` — White text (dark backgrounds)

**All old Sandbox template logos deleted** (logo-dark, logo-light, logo-purple, logo@2x, etc.)

### Completed Steps
1. ✅ Recreated logo in Inkscape with **Figtree** font (OFL licensed)
2. ✅ Exported PNG (988×152) + WebP via CLI tools
3. ✅ Replaced in `~/callsaver-landing/public/img/` (6 files)
4. ✅ Replaced in `~/callsaver-frontend/public/` (7 files)
5. ✅ Replaced in `~/callsaver-api/email-previews/` + `public/` (3 files)
6. ✅ Updated `generate-msa-pdf.ts` — Avenir Next → configurable Inter/Figtree
7. ✅ Removed Avenir Next from frontend, added Figtree font
8. ✅ Added floating font comparison widget (Inter ↔ Figtree) to both repos

### Still Pending
- Upload new logo to Stripe Dashboard → Settings → Branding
- Upload MSA template to DocuSeal
- ✅ Font decision made: **Figtree** everywhere. Font toggle widgets removed from both repos.
- ✅ MSA PDFs regenerated with Figtree font (Feb 11)

---

## Step 1: Configure LiveKit Cloud S3 Credentials (1.21) — ✅ COMPLETE

**Goal:** Enable LiveKit Egress to write call recordings to our S3 bucket.

**✅ COMPLETED (Feb 11):**
1. ✅ Created IAM user `callsaver-livekit-egress` (Access Key: `AKIA4FOROB4GDBZH7JEY`)
2. ✅ Attached `LiveKitEgressS3Access` inline policy (scoped to `callsaver-sessions-staging` + `callsaver-sessions-production`)
3. ✅ Created comprehensive documentation: `services/livekit-egress-setup.md`
4. ✅ Created Python voice agent documentation: `~/callsaver-api/docs/ai-agent/LIVEKIT_AGENT.md`
5. ✅ **No manual LiveKit Cloud dashboard step needed** — the Python voice agent handles egress programmatically with per-request S3 credentials via the LiveKit Egress API (`AWS_SESSION_BUCKET` env var). Dashboard S3 configuration is unnecessary.

---

## Step 2: Finalize Landing Page (`~/callsaver-landing`)

**Remaining tasks from Step 8 of previous plan:**

### Content & Copy
- [ ] Review and update website copy (Hormozi-style conversion optimization)
- [ ] Review features section for accuracy
- [ ] Review FAQ section answers
- [ ] Replace audio demo with better LiveKit-recorded sample
- [ ] Replace dashboard screenshot with screen recording video (evaluate Focusee / Cap.so / Poindeo)

### Branding
- [ ] Update company logo font: Avenir Next → Inter (GIMP)
- [ ] Update business card templates font: Avenir Next → Inter

### Minor Fixes
- [ ] Review scroll position offsets for anchor links
- [ ] Replace static thinking emoji with animated GIF/WebP
- [ ] Full review pass — fix any remaining issues

### Code Cleanup
- [ ] Delete dead code, unused images, and template leftovers

### Deferred
- SEO, GrowthBook A/B testing, blog articles — do last

---

## Step 3: DocuSeal API Keys & Webhook Setup

**Goal:** Get test mode and production mode API keys from DocuSeal admin portal and configure webhooks.

### 3a. DocuSeal API Keys
1. **Log in** to https://forms.callsaver.ai as admin
2. **Navigate to** Settings → API
3. **Copy the test mode API key** → update:
   - `~/callsaver-api/.env` (`DOCUSEAL_API_KEY=`)
   - `~/callsaver-api/.env.local` (`DOCUSEAL_API_KEY=`)
4. **Copy the production mode API key** → update:
   - `~/callsaver-api/.env.staging` (`DOCUSEAL_API_KEY=`)
   - `~/callsaver-api/.env.production` (`DOCUSEAL_API_KEY=`)
   - Secrets Manager: `callsaver/staging/backend/DOCUSEAL_API_KEY`
5. **Verify** `DOCUSEAL_WEBHOOK_SECRET` is set correctly in DocuSeal admin

### 3b. DocuSeal Webhook Configuration
- **Local (ngrok):** `https://<ngrok-url>/webhooks/docuseal`
- **Staging:** `https://staging.api.callsaver.ai/webhooks/docuseal`
- Event: `submission.completed` (triggers MSA countersign flow)

---

## Step 4: Webhook Setup (Stripe, Nango, Intercom)

### 4a. Stripe Webhooks — ✅ COMPLETED (Feb 11)
Both sandbox webhook endpoints already configured:
- **Local (ngrok):** `https://a59e83ba8dd0.ngrok-free.app/webhooks/stripe` → `whsec_DT4irGsjNSMUx1xnT2rghcNdBVyX4EWY`
- **Staging:** `https://staging.api.callsaver.ai/webhooks/stripe` → `whsec_srkDMchTTYvObB8twn2j4jIfKLS4AGbL`
- Events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `customer.subscription.trial_will_end`, `invoice.paid`, `invoice.payment_failed`
- `.env` updated: `STRIPE_WEBHOOK_SECRET` set to ngrok key for local dev (staging key in comments)
- **Production webhook** (`api.callsaver.ai`): Deferred until production deploy (Phase 5)

### 4b. Nango Webhooks
1. **Nango Dashboard** → Settings → Webhooks
2. **Add local:** `https://<ngrok-url>/webhooks/nango`
3. **Add staging:** `https://staging.api.callsaver.ai/webhooks/nango`
4. **Verify** `NANGO_SECRET_KEY` is correct in `.env` files

### 4c. Intercom Webhooks
1. **Intercom Developer Hub** → Your App → Webhooks
2. **Add local:** `https://<ngrok-url>/webhooks/intercom`
3. **Add staging:** `https://staging.api.callsaver.ai/webhooks/intercom`
4. **Verify** `INTERCOM_ACCESS_TOKEN` is correct

---

## Step 5: Re-enable Twilio & LiveKit in Provisioning

**Goal:** Remove the `SKIP_TWILIO_PURCHASE=true` flag and re-enable full provisioning flow.

### Prerequisites
- [ ] **Pay Twilio delinquent balance** ($22) — https://console.twilio.com/billing
- [ ] Verify existing provisioned numbers are still active
- [ ] Verify LiveKit Cloud connection: `wss://callsaver-d8dm5v36.livekit.cloud`

### Code Changes
1. Set `SKIP_TWILIO_PURCHASE=false` in `.env` / `.env.local` / `.env.staging`
2. Verify `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` are valid in env files
3. Verify `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL` are set

---

## Step 6: Full Provisioning & Onboarding Flow Test

**Goal:** Test the complete user journey end-to-end, locally and on staging.

### Test Flow (local first, then staging)
1. **Sign up** via magic link (Supabase auth)
2. **Onboarding wizard** — fill out business details
3. **Provision handler** triggers:
   - [ ] DocuSeal MSA sent → verify email arrives
   - [ ] MSA signed → `submission.completed` webhook fires
   - [ ] Verify signed document written to `callsaver-ai-forms` S3 bucket
   - [ ] Stripe checkout session created → payment completes
   - [ ] Twilio number purchased (if `SKIP_TWILIO_PURCHASE=false`)
   - [ ] LiveKit SIP trunk configured
   - [ ] Business profile created in `callsaver-business-profiles` S3
4. **Dashboard loads** with provisioned data
5. **Guided tour** (react-joyride) — test and finish implementation
6. **Test all provisioning emails:**
   - Welcome email
   - MSA email (via DocuSeal)
   - Invoice/receipt (via Stripe)
   - Any nurture sequence emails

### Verification Checklist
- [ ] All webhook endpoints responding (DocuSeal, Stripe, Nango, Intercom)
- [ ] S3 documents written correctly
- [ ] Database records created (User, Organization, OrganizationMember, etc.)
- [ ] No console errors in frontend
- [ ] No 5xx errors in API logs

---

## Step 7: Production Infrastructure Deploy

**Only after local + staging testing is confirmed working.**

1. Deploy `Callsaver-Network-production`
2. Deploy `Callsaver-Storage-production`
3. Deploy `Callsaver-Backend-production`
4. Deploy `Callsaver-Agent-production`
5. Create production Secrets Manager entries (`callsaver/production/backend/*`)
6. Create Supabase production instance (task 1.20)
7. Deploy production web UI (task 1.14)
8. Update Route 53 production DNS records
9. Configure production webhooks (Stripe, DocuSeal, Nango, Intercom)
10. Final environment separation verification (task 4.6)

---

## Business Formation (Running in Parallel)

| Task | Status |
|------|--------|
| 2.1 Form Prosimian Labs LLC (Wyoming) | ✅ COMPLETED - Articles filed, OA signed, EIN obtained |
| 2.2 File DBA "CallSaver" (Santa Cruz County, $58) | ⏳ Waiting for CA LLC-12 approval |
| 2.3 Execute Solo Founder OA | ✅ COMPLETED - Signed via DocuSeal |
| 2.4 Get EIN | ✅ COMPLETED |
| ~~2.5 E-File 83(b) Election~~ | N/A — Not needed for single-member LLC |
| 2.6 CA Virtual Office (Northwest) | ⏳ Waiting for CA LLC-5 approval |
| 2.8 CA Foreign LLC Registration | ⏳ SUBMITTED - Form LLC-5 filed, waiting 1-2 days |
| 2.7 WY Certificate of Good Standing | ✅ COMPLETED |
| 2.9 CA Statement of Information | ⏳ Will file after LLC-5 approval (Form LLC-12, $20) |
| 3.1 Mercury & Stripe Setup | ✅ Mercury submitted + Stripe LIVE |

---

## Previously Completed (Feb 8-9)

<details>
<summary>Click to expand completed items</summary>

- ✅ Fix redirect loop (supabase-auth.ts)
- ✅ Revert 6 debug hacks in callsaver-frontend
- ✅ Update DocuSeal SMTP credentials
- ✅ Complete staging validation (1.22)
- ✅ Commit & push all repos (Feb 9)
- ✅ QR Code API testing (1.8)
- ✅ Health Check: Analytics (1.6) — GA4 + ContentSquare working
- ✅ Cal.com GA4 Integration (1.7)
- ✅ Landing page legal compliance — LLC disclosure, governing law, consent banner research
- ✅ Landing page navigation fixes — anchor links, Cal.com embed
- ✅ DBA name availability check — "CallSaver" clear in CA
- ✅ Recreate all S3 buckets (1.15) — 7 buckets, all data uploaded
- ✅ GitHub Actions secrets fix (1.19) — old account ID updated

</details>
