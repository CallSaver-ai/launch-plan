# Active Plan: Production Launch Outstanding Tasks

> **Purpose:** Current focus areas with only outstanding tasks from master-plan.md
> **For daily execution:** See daily-plan.md for immediate next steps
> **Complete reference:** See master-plan.md for full historical record
> **LLC Decision:** Prosimian Labs LLC (Wyoming) DBA CallSaver

---

## Phase 0: Co-Founder Offboarding & Domain Transfer

| # | Task | Description | Status |
|---|------|-------------|--------|
| 0.2 | **Remove Azhar from Google Workspace** | ✅ Removed `azhar@callsaver.ai` from Google Workspace Admin | ✅ |
| 0.3 | **Close Suspended AWS Account** | ✅ Old AWS account has been closed | ✅ |
| 0.4 | **Pay Google Workspace Bill** | Google Workspace subscription expires in ~25 days (around March 5, 2026). Ensure payment is current to avoid losing `alex@callsaver.ai` email access | ☐ |
| 0.6 | **Investigate Google Cloud Account** | **Deferred — current `scrumptiouslemur@gmail.com` account is working fine.** Will switch to `alex@callsaver.ai` later when funds are available to pay the delinquent bill. The `GOOGLE_API_KEY` is shared across **8 Google APIs** (Gemini, Places, Geocoding, Weather, PageSpeed, Maps JS, GBP, Routes). See `external-services-inventory.md` § 12 | ⏳ Deferred |

---

## Phase 1: Technical Resurrection (Remaining Tasks)

| # | Task | Description | Status |
|---|------|-------------|--------|
| 1.6 | **Health Check: Analytics** | **✅ COMPLETED Feb 9, 2026.** GA4 and ContentSquare verified working (GA4 showing 3 users in last 30min, ContentSquare tracking confirmed). GrowthBook SDK connected but A/B testing deferred until later phase. Analytics debugger cleaned up (removed Hotjar, fixed Cal.com detection). Environment variables fixed (added NEXT_PUBLIC_ prefix to GrowthBook credentials). | ✅ |
| 1.7 | **Cal.com GA4 Integration** | **✅ COMPLETED Feb 9, 2026.** Cal.com embed updated to: (1) Use `alexsikand/demo` (fixed from azharhuda), (2) Forward UTM params from page URL to embed config, (3) Listen for `bookingSuccessfulV2` events and fire GA4 `demo_booking_completed` conversion, (4) Track `bookerViewed` events for engagement. Booking form configured with 6 fields + hidden `qr_sid` for QR attribution. Embed colors updated to #4c00ff with forced light theme. | ✅ |
| 1.8 | **QR Code API Testing** | **✅ COMPLETED Feb 9, 2026.** QR scan tracking tested end-to-end on staging. Database migration applied, seed data created (`bcard` short code), QR image generated, `GET /q/bcard` returns 302 with `qr_sid` + UTMs + cookie, `/book` page loads Cal.com embed, scan events recorded correctly in DB. Vercel geo fields null as expected (ECS, not Vercel edge). See `qr-code-system.md` for full documentation. **Decision pending:** order business cards with staging QR codes or wait for production API. | ✅ |
| 1.9 | **Order Business Assets** | Submit Moo.com order for business cards and flyers after testing confirmed | ☐ |
| 1.10 | **Redeploy DocuSeal Server** | **✅ COMPLETED Feb 9, 2026.** Server deployed at `forms.callsaver.ai` with SES SMTP credentials. **SMTP credentials updated in EC2 instance** - password synced with Secrets Manager. Server restarted successfully with new credentials. **SMTP authentication tested and verified** - both external and in-container tests passed. Ready for production email sending. | ✅ |
| 1.10a | **Update DocuSeal API Key in Secrets Manager** | **✅ COMPLETED Feb 8, 2026.** After DocuSeal admin setup completed at `https://forms.callsaver.ai/setup`: (1) ✅ Signed in to DocuSeal admin. (2) ✅ Copied new API key from Settings → API. (3) ✅ Updated staging secret: `aws secretsmanager put-secret-value --secret-id callsaver/staging/backend/DOCUSEAL_API_KEY --secret-string "<new-key>"`. (4) Update production secret when ready: `aws secretsmanager put-secret-value --secret-id callsaver/production/backend/DOCUSEAL_API_KEY --secret-string "<new-key>"`. (5) Also update `DOCUSEAL_WEBHOOK_SECRET` if a new webhook is configured. (6) Restart ECS tasks to pick up new secrets: `aws ecs update-service --cluster Callsaver-Cluster-staging --service callsaver-node-api-staging --force-new-deployment` | ✅ |
| 1.12 | **Deploy Web UI (Staging)** | **✅ COMPLETED Feb 9, 2026.** Deployed `callsaver-frontend` to `https://staging.app.callsaver.ai`. CloudFront CNAME conflict resolved via wildcard cert + associate-alias approach. Distribution: ELY11NNZH2QZK (`d1d69ehy9s378n.cloudfront.net`). S3 bucket: `callsaver-frontend-staging`. **ISSUE RESOLVED:** Fixed redirect loops by removing broken `require('https')` in `supabase-auth.ts` and reverting debug hacks. Staging fully functional. | ✅ |
| 1.15 | **Recreate All S3 Buckets (via CDK)** | **✅ COMPLETED Feb 10, 2026.** All S3 buckets CDK-managed in `Callsaver-Storage-staging`. Old account (086002003598) owns original names globally → new shared buckets use `callsaver-ai-` prefix. **Bucket Inventory:** (1) `callsaver-sessions-staging` (2) `callsaver-business-profiles` (3) `callsaver-frontend-staging` (4) `callsaver-web-ui-staging-v2` (5) `callsaver-ai-forms` (6) `callsaver-ai-cities-counties` — 50 JSONs uploaded (7) `callsaver-ai-voice-samples` — 9 WAVs uploaded. **IAM:** Dedicated `callsaver-docuseal-s3` user (`AKIA4FOROB4GPUUTIKNG`) with `DocuSealS3Access` policy scoped to `callsaver-ai-forms`. SES user `callsaver-ses-smtp` has only `AmazonSESFullAccess`. **Secrets Manager:** `docuseal/aws-access-key-id` + `docuseal/aws-secret-access-key` → new S3 user. `docuseal/s3-attachments-bucket` → `callsaver-ai-forms`. `SESSION_S3_BUCKET` → `callsaver-sessions-staging`. **Code audit:** All old bucket refs updated across `callsaver-api`, `callsaver-frontend`, `lead-gen-production`, `callsaver-docuseal`. EC2 `/opt/docuseal/.env` updated with new S3 credentials + restarted. | ✅ |
| 1.19 | **Update GitHub Actions Secrets** | Update all GitHub Actions secrets for both repos (see Section F). Key changes: new AWS credentials, new IAM role ARN, new CloudFront distribution IDs, production Stripe publishable key (`pk_live_`). Update hardcoded old account ID `086002003598` in `deploy-staging.yml` | ☐ |
| 1.20 | **Create Supabase Production Instance** | Create a separate Supabase project for production (`callsaver-production`, region: **West US / N. California**). **Start on Free plan** — upgrade to Pro happens at launch (task 4.20). Steps: (1) Create new Free org + project in Supabase dashboard. (2) Run Prisma migrations: `DATABASE_URL=<new-pooled-url> npx prisma migrate deploy`. (3) Configure Auth settings: magic link template, redirect URLs (`https://app.callsaver.ai/...`), email templates. (4) Copy new credentials: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DATABASE_URL`, `DIRECT_URL`. (5) Update production Secrets Manager entries with new values. (6) **Migrate DocuSeal database** from staging Supabase to production Supabase: update `DATABASE_URL` in `/opt/docuseal/.env` on the EC2 instance to point to the new production Postgres, then restart DocuSeal (`sudo docker-compose down && sudo docker-compose up -d`). DocuSeal will re-run migrations on the new database. Re-create admin account at `https://forms.callsaver.ai/setup` and re-upload MSA template. **Staging continues to use existing project** (`arjdfatbdpegoyefdqfo.supabase.co`). This eliminates the risk of staging migrations breaking production | ☐ |
| 1.21 | **Configure LiveKit Cloud S3 Credentials** | LiveKit Egress writes call recordings directly to S3. In the **LiveKit Cloud dashboard** → Settings → Egress: configure AWS credentials (access key + secret) for the new AWS account so Egress can write to `callsaver-sessions-staging-us-west-1` and `callsaver-sessions-production-us-west-1`. Create a dedicated IAM user with `s3:PutObject` permission scoped to these buckets only | ☐ |
| 1.22 | **Staging Validation Checkpoint** | **✅ COMPLETED Feb 9, 2026.** Status: (1) ✅ API health endpoint responds on `staging.api.callsaver.ai` (verified). (2) ✅ Web UI loads on `staging.app.callsaver.ai` — **DEPLOYED** and fully functional. (3) ✅ Magic link login works (Supabase auth). (4) ✅ API endpoints accessible — all endpoints working after `supabase-auth.ts` fix. (5) ✅ DocuSeal API reachable from backend (completed Feb 9, 2026 — https://forms.callsaver.ai accessible with updated SMTP). **Staging fully validated and ready for production deployment.** | ✅ |

---

## Phase 2: Federal & State Compliance

| # | Task | Description | Status |
|---|------|-------------|--------|
| 2.1 | **Form Prosimian Labs LLC (Wyoming)** | ✅ COMPLETED Feb 10, 2026. Articles of Organization filed with Northwest Registered Agent. Operating Agreement signed via DocuSeal. EIN obtained. Business documents stored in ~/callsaver-documents. | ✅ |
| 2.2 | **File DBA "CallSaver" (Santa Cruz County)** | **WAITING FOR CA LLC-12.** Will file after CA foreign LLC registration is approved and CA Statement of Information (Form LLC-12) is filed. FBN requires: Wyoming Certificate of Organization + CA SI-550. Filing fee: $50 + $8 for additional owner. Publication required within 45 days (4 weeks in Santa Cruz newspaper). | ⏳ Blocked on 2.8 |
| 2.3 | **Execute Solo Founder OA** | ✅ COMPLETED Feb 10, 2026. Northwest solo founder operating agreement drafted, reviewed, and signed via DocuSeal. | ✅ |
| 2.4 | **Get EIN** | ✅ COMPLETED Feb 10, 2026. EIN obtained from IRS for Prosimian Labs LLC. | ✅ |
| 2.5 | ~~**E-File 83(b) Election**~~ | **N/A — Not needed.** Single-member LLC with no equity grants; 83(b) election is unnecessary. | N/A |
| 2.6 | **CA Virtual Office** | **WAITING FOR CA LLC-5.** Northwest virtual office setup will be finalized after CA foreign LLC registration is approved. Address: 2108 N St, Ste N, Sacramento, CA 95816. | ⏳ Blocked on 2.8 |
| 2.7 | **WY Certificate of Good Standing** | ✅ COMPLETED. Certificate of Existence obtained from Wyoming SOS. | ✅ |
| 2.8 | **CA Foreign Qualification** | **SUBMITTED Feb 10, 2026.** Form LLC-5 filed with California Secretary of State. Waiting for approval (1-2 business days). Uses Northwest as CA registered agent. | ⏳ In Progress |
| 2.9 | **CA Registered Agent** | ✅ COMPLETED. Northwest Registered Agent setup for California included in LLC-5 filing. | ✅ |
| 2.10 | **Compile Startup Expense Receipts** | Collect payment receipts for business formation, software costs, and laptop purchases (up to $5,000 IRS startup deduction). **Note:** Some expenses paid from mom's personal card — document as member loan: (1) Create a simple promissory note from LLC to mom, (2) LLC reimburses mom from Mercury once funded, (3) Keep receipts + note for tax records. Accounting connected to Mercury. | ☐ |

---

## Phase 3: Sales & Finance Infrastructure

> **Dependency note:** Tasks 3.1–3.2 require DBA (2.2), EIN (2.4), and CA Virtual Office (2.6) to be completed first.

| # | Task | Description | Status |
|---|------|-------------|--------|
| 3.1 | **Mercury & Stripe Setup** | ✅ Mercury application submitted (awaiting approval). ✅ Stripe account created and live (Feb 10, 2026) for Prosimian Labs LLC. Customer support address: 2108 N St, Ste N, Sacramento, CA 95816. | ✅ |
| 3.2 | **Stripe Production Mode** | ✅ Stripe account is live with production keys. Need to run `setup-stripe-catalog.ts` to generate live catalog IDs and configure webhook endpoints. | ⏳ Partial |
| 3.3 | **Stripe Webhooks (Staging + Production)** | Configure Stripe webhook endpoints for staging and production environments (in addition to existing ngrok URL) | ☐ |
| 3.4 | **AWS SES Domain Verification** | **✅ COMPLETED Feb 8, 2026.** Domain `callsaver.ai` verified in SES us-west-1. DKIM records added to DNS stack. All 6 sender identities verified: `alex@`, `info@`, `support@`, `billing@`, `legal@`, `reports@callsaver.ai` | ✅ |
| 3.4a | **Create SES SMTP Credentials for DocuSeal** | **✅ COMPLETED Feb 8, 2026.** IAM user `callsaver-ses-smtp` created with SES access. SMTP credentials stored in Secrets Manager. DocuSeal configured to send via SES | ✅ |
| 3.5 | **AWS SES Production Request** | Submit production access request (see SES Production Request Draft in appendix). If rejected, switch to **Resend** as fallback — only requires API key swap in `email-adapter.ts`, supports same sender addresses. See SES Fallback Plan below | ☐ |
| 3.6 | **Nango Webhooks (Staging + Production)** | Configure Nango webhook endpoints for staging and production environments (currently only points to ngrok) | ☐ |
| 3.7 | **Intercom Webhooks & Subscription** | Set up Intercom webhooks and verify subscription is active | ☐ |
| 3.8 | **Attio CRM: Account Migration** | ✅ COMPLETED. Attio CRM transferred from Azhar to Alex. | ✅ |
| 3.9 | **Attio CRM: Operator Plan Workflow** | Create Attio workflow to provision users on Operator plan (lower tier) | ☐ |
| 3.10 | **Attio CRM: Scale Plan Workflow** | Create Attio workflow to provision users on Scale plan (higher tier) | ☐ |
| 3.11 | **Cal.com Lead Enrichment** | Re-enable Cal.com; ensure webhook pushes enriched lead data to Attio (new account) | ☐ |
| 3.12 | **Pricing Review** | Review and finalize Operator, Growth, and Scale plan pricing before launch | ☐ |
| 3.13 | **Twilio Account Reactivation** | Pay $22 delinquent balance on Twilio account. Re-enable Twilio and LiveKit SIP integration. Currently mocked via `SKIP_TWILIO_PURCHASE=true` env var — set to `false` when ready for live phone provisioning. Verify existing provisioned numbers are still active | ☐ |
| 3.14 | **Configure Cal.com Custom Domain** | In Cal.com dashboard → Settings → Organizations → Custom domain: set `book.callsaver.ai`. Update Cal.com embed code in `callsaver-landing` if URL changes. Also update hardcoded `azharhuda/demo` Cal.com link in `server.ts:15140` to your Cal.com username | ☐ |
| 3.15 | **Configure Intercom Custom Domain** | In Intercom → Settings → Help Center → Custom domain: set `help.callsaver.ai`. Add CNAME record (already in DNS checklist) | ☐ |
| 3.16 | **Configure Supabase Custom Domain** | Deferred to **task 4.20** (right before launch). Custom domain `auth.callsaver.ai` requires Pro plan. Will be enabled when production org is upgraded to Pro. DNS CNAME already in checklist | ☐ |

---

## Phase 4: Pre-Launch Polish & Operations

| # | Task | Description | Status |
|---|------|-------------|--------|
| 0.7 | **Restrict Google API Keys** | After resolving GCP account: (1) **Backend key** (`GOOGLE_API_KEY`) — restrict to Gemini, Places, Geocoding, Weather, PageSpeed, GBP, Routes APIs + IP-restrict to ECS NAT Gateway IPs. (2) **Frontend key** (`VITE_GOOGLE_MAPS_API_KEY`) — restrict to Maps JavaScript API + HTTP referrer restrict to `*.callsaver.ai`, `localhost:*` | ☐ |
| 0.8 | **Audit All External Service Accounts** | For each of the 23 external services (see `external-services-inventory.md`), verify: which email owns the account, billing is current, API keys are valid. Priority: AWS, Google Cloud, Twilio, Google Workspace, Namecheap (🔴 P0), then OpenAI, Deepgram, Cartesia, Anthropic, AssemblyAI, LiveKit, Sentry, Vercel, Attio, Nango, Intercom (🟡 P1) | ☐ |
| 4.1 | **MSA / Privacy Policy / TOS Review** | One round of review on existing Master Service Agreement, Privacy Policy, and Terms of Service before launch. **Decision: Use DBA "CallSaver" for all customer-facing documents** (MSA, Privacy Policy, TOS, DocuSeal countersignature). Include a legal entity disclosure paragraph in the MSA: *"CallSaver" is a trade name of Prosimian Labs LLC, a Wyoming limited liability company.* Use the Wyoming LLC name only for banking, tax, and government filings | ☐ |
| 4.2 | **Sentry Error Tracking** | Reactivate Sentry subscription (trial expired); verify error tracking is operational for `callsaver-api` and `callsaver-web-ui` | ☐ |
| 4.3 | **API Key Rotation** | Rotate all API keys across services (new AWS account invalidates all AWS keys); audit every service referencing old keys and update env vars across Secrets Manager, GitHub Actions secrets, and local `.env` files | ☐ |
| 4.4 | **CI/CD Pipeline Review** | Evaluate moving from local deploys to: Vercel branch deploys for `callsaver-landing`, GitHub Actions/workflow deploys for `callsaver-api` and `callsaver-web-ui`; set up staging → production promotion. Update `deploy-staging.yml` with new account role ARN. Regenerate Cosign keys for image signing. **⚠️ Verify `deploy-prod.yml` exists** in `callsaver-api/.github/workflows/` — the Deployment Scripts section references it but only `ci.yml`, `deploy-staging.yml`, and `publish-and-update-ui.yml` were found. If it doesn't exist, create it based on `deploy-staging.yml` with production role ARN, production ECR repo, and manual approval gate | ☐ |
| 4.7 | **Landing Page Copy Review** | Pre-launch review of messaging, positioning, and CTAs on callsaver.ai | ☐ |
| 4.7a | **Screen Recording Tool Evaluation** | Evaluate screen recording tools for dashboard video: Focusee, Cap.so, Poindeo. Test each tool's features, pricing, and output quality. Choose best option for recording dashboard demo video. | ☐ |
| 4.7b | **Update Logo Font (License Issue)** | **✅ COMPLETED Feb 11, 2026.** Logo recreated with Figtree font (OFL licensed). All repos updated. Font toggle removed. See detail section below. | ✅ |
| 4.7c | **Figtree Font Size Audit** | Figtree renders tighter/smaller than Inter at equivalent sizes. Audit and adjust font sizes across: (1) `~/callsaver-landing` — `_variables.scss` (`$font-size-root`, `$font-size-base`, heading sizes), `style.scss`, component overrides. (2) `~/callsaver-frontend` — `theme.css`, `index.css`, Tailwind config, component `text-[]` classes. MSA PDF sizing confirmed OK — no changes needed. | ☐ |
| 4.8 | **Help Center / Documentation** | Set up customer-facing help center and product documentation | ☐ |
| 4.9 | **Status Page** | Set up public status page (e.g., BetterUptime, Instatus) for customer trust | ☐ |
| 4.10 | **Social Proof** | Get testimonial from Travis (electrician) for landing page | ☐ |
| 4.11 | **Upload DocuSeal MSA Template** | After DocuSeal redeploy (1.10), upload the MSA template to the new instance. Template must match your LLC/DBA name (same decision as 4.1). Code in `server.ts` dynamically fetches latest template from DocuSeal API. Verify DocuSeal API key and webhook secret are set in Secrets Manager | ☐ |
| 4.13 | **CloudWatch Alarms** | Set up CloudWatch alarms for: API ALB 5xx error rate, ECS task health (unhealthy count > 0), ECS CPU/memory utilization > 80%, ALB target response time > 5s. Configure SNS topic to email `alex@callsaver.ai` for alerts. **Also add alarms for Agent service** (CPU/memory, task health) | ☐ |
| 4.20 | **Upgrade Supabase Production to Pro** | **Do this right before launch to avoid unnecessary cost.** Upgrade the production Supabase organization to Pro ($25/mo). This unlocks: daily backups with PITR, no 7-day pause risk, 8 GB database (vs 500 MB), 100 GB storage, email support. Then enable custom domain `auth.callsaver.ai` on the production project (Pro required). Add CNAME record to Route 53 (already in DNS checklist). Update `VITE_SUPABASE_URL` / `VITE_AUTH_REDIRECT_URL` in production GitHub Actions secrets to use `https://auth.callsaver.ai`. **Staging stays on Free** — pausing and lack of backups don't matter for dev/test | ☐ |

### Task 4.7b Detail: Logo Font Update — ✅ COMPLETED (Feb 11, 2026)

**Problem:** Old logo used Avenir Next (commercial license). Recreated in Inkscape with **Figtree** font (OFL licensed).

**Simplified logo scheme (2 variants × 3 formats = 6 files):**
- `black-logo.{svg,png,webp}` — Black text on transparent (light backgrounds)
- `white-logo.{svg,png,webp}` — White text on transparent (dark backgrounds)

**What was done:**
1. ✅ Created `black-logo.svg` and `white-logo.svg` in Inkscape (Figtree Medium, 988×152px)
2. ✅ Exported PNG (via `inkscape --export-png`) and WebP (via ImageMagick `convert`)
3. ✅ Replaced logos in `~/callsaver-landing/public/img/` (6 files)
4. ✅ Replaced logos in `~/callsaver-frontend/public/` (7 files incl. `images/` dupe)
5. ✅ Replaced `~/callsaver-api/email-previews/black-logo.png` (MSA PDF letterhead)
6. ✅ Replaced `~/callsaver-api/public/white-logo.svg` (email logo) + `logo-header.png`
7. ✅ Deleted all Sandbox template logos (logo-dark, logo-light, logo-purple, logo@2x, etc.)
8. ✅ Updated `generate-msa-pdf.ts`: replaced Avenir Next with configurable Inter/Figtree, generates both versions
9. ✅ Removed Avenir Next from `~/callsaver-frontend/index.html`, added Figtree to Google Fonts
10. ✅ Replaced `--font-avenir` CSS variable with `--font-figtree` in `theme.css`
11. ✅ Added floating font comparison widget to both landing page and frontend (temporary, remove before launch)

**Still pending:**
- **Stripe** — Upload new logo in Stripe Dashboard → Settings → Branding
- **DocuSeal** — Update logo if used in MSA template
- **Business cards** — Update Moo.com templates
- **Font decision** — Compare Inter vs Figtree body text using the floating widget, then remove widget

---

## Phase 5: Production Deployment

> **Do not start this phase until staging validation (1.22) is complete and Phases 2-3 are substantially done.**

| # | Task | Description | Status |
|---|------|-------------|--------|
| 1.13 | **Reconstruct AWS Infrastructure (Production API)** | Stand up production ECS/Fargate environment: `Callsaver-Network-production`, `Callsaver-Storage-production`, `Callsaver-Backend-production`, `Callsaver-Agent-production`. Create production Secrets Manager entries under `callsaver/production/backend/` and `callsaver/production/agent/` | ☐ |
| 1.14 | **Deploy Web UI (Production)** | Deploy `callsaver-frontend` production: run CDK for `FrontendProductionStack`, then deploy static build. May need same wildcard cert + associate-alias approach if `app.callsaver.ai` has same CNAME conflict from old account | ☐ |
| 1.17 | **Create All AWS Secrets Manager Entries (Production)** | Create all secrets under `callsaver/production/backend/` and `callsaver/production/agent/`. Use production-specific values where different. **Run `scripts/setup-stripe-catalog.ts` against production Stripe** to generate live catalog IDs | ☐ |
| 4.6 | **Environment Separation Verification** | Final verification pass: distinct staging/production configs, separate databases, env vars, webhook endpoints | ☐ |

---

## Completed Tasks (Reference)

**Phase 0:**
- ✅ 0.1 - Domain transfer completed (now under your control)
- ✅ 0.2 - Removed Azhar from Google Workspace
- ✅ 0.3 - Old AWS account closed
- ✅ 0.5 - Created reports@ email

**Phase 1:**
- ✅ 1.1 - AWS account created with alex@callsaver.ai
- ✅ 1.1a - AWS CLI configured
- ✅ 1.2 - DKIM exported
- ✅ 1.3 - Route 53 hosted zone created
- ✅ 1.4 - Nameservers updated
- ✅ 1.5 - Vercel reactivated + GitHub Actions CI/CD for landing page (Feb 9)
- ✅ 1.10 - DocuSeal deployed to forms.callsaver.ai (Feb 8)
- ✅ 1.10a - DocuSeal API key updated in Secrets Manager (Feb 8)
- ✅ 1.11 - Staging API infrastructure deployed
- ✅ 1.11a - Docker images built and pushed
- ✅ 1.12 - Staging web UI deployed (with redirect loop issue)
- ✅ 1.16 - Staging secrets created
- ✅ 1.18 - CDK SecretsNamespace updated
- ✅ 1.23 - Hardcoded old account references removed
- ✅ 1.24 - Better Auth dead code removed
- ✅ 1.25 - CDK DNS stack deployed (refactored to shared `Callsaver-DNS` stack, Feb 8)
- ✅ 1.8 - QR Code API Testing completed (Feb 9)

**Phase 2:**
- ✅ 2.0 - LLC name decided (Prosimian Labs LLC)
- ✅ 2.1 - Prosimian Labs LLC formed (Wyoming, Feb 10)
- ✅ 2.3 - Operating Agreement signed via DocuSeal (Feb 10)
- ✅ 2.4 - EIN obtained from IRS (Feb 10)
- ✅ 2.9 - CA Registered Agent (Northwest, included in LLC-5 filing)

**Phase 3:**
- ✅ 3.1 - Mercury application submitted + Stripe account live (Feb 10)
- ✅ 3.4 - AWS SES domain verification completed (Feb 8)
- ✅ 3.4a - SES SMTP credentials created for DocuSeal (Feb 8)

**Phase 4:**
- ✅ 4.5 - Fixed staging web UI build vars
- ✅ 4.12 - Removed Azhar code references
- ✅ 4.14 - Generated VAPID keys
- ✅ 4.15 - Migrated Google Place Details cron to BullMQ
- ✅ 4.16 - Added production CORS origins
- ✅ 4.17 - Fixed analytics IDs
- ✅ 4.18 - Removed SendGrid dead code
- ✅ 4.19 - Verified S3 data availability
- ✅ 4.21 - Set up Upstash Redis for production

---

## Critical Path Summary

**Completed Feb 10:**
1. ~~Recreate all S3 buckets (1.15)~~ ✅ Done — 3 new buckets created, data uploaded, all code refs updated
2. ~~DocuSeal S3 config~~ ✅ Done — dedicated IAM user, Secrets Manager, EC2 .env updated
3. ~~S3 bucket audit~~ ✅ Done — all old refs fixed across 4 repos
4. ~~LLC Formation (2.1)~~ ✅ Done — Articles filed, OA signed, EIN obtained
5. ~~CA Foreign LLC (2.8)~~ ⏳ Submitted — Form LLC-5 filed, awaiting approval
6. ~~Landing Page Stripe Compliance~~ ✅ Done — Cancellation policy, footer, deployed to Vercel
7. ~~MSA Entity Name Fix~~ ✅ Done — Updated to Prosimian Labs LLC, DBA CallSaver
8. ~~Stripe Account (3.1)~~ ✅ Done — Stripe live for Prosimian Labs LLC
9. ~~Mercury Application (3.1)~~ ✅ Done — Submitted, awaiting approval

**Next Up (Feb 11):**
1. Regenerate MSA PDF with corrected entity name
2. Re-upload MSA template to DocuSeal
3. Run `setup-stripe-catalog.ts` for live Stripe catalog IDs
4. Configure Stripe webhooks (staging + production)
5. Wait for CA LLC-5 approval → file LLC-12 → file FBN

**This Week:**
1. Complete Stripe integration (catalog, webhooks)
2. Deploy production infrastructure (1.13, 1.14)
3. Wait for CA approvals, then file DBA
4. Complete remaining pre-launch tasks (Phase 4)

**Key Dependencies:**
- **Redirect loop fix → Staging validation (1.22)**
- **DocuSeal SMTP update (1.10) → Full staging validation**
- **Phase 2 tasks 2.1, 2.2, 2.4, 2.6 must complete before Phase 3 banking setup**
- **Production deployment (1.13, 1.14) should wait for staging validation (1.22)**
- **Supabase Pro upgrade (4.20) should happen right before launch to avoid costs**
- Production CNAME `app.callsaver.ai` may need same wildcard + associate-alias fix

**Architecture Notes:**
- **DNS:** Single `Callsaver-DNS` stack manages all Route 53 records (shared across environments)
- **DocuSeal:** Single server at `forms.callsaver.ai` — test mode for staging, production mode for production. Both environments share the same URL, differentiated by API key

---

## Current Issues

### CloudFront CNAME Conflict — RESOLVED ✅ (Feb 9, 2026)

**Error:** `"One or more of the CNAMEs you provided are already associated with a different resource"` (HTTP 409)

**Root Cause:** The CNAME `staging.app.callsaver.ai` was registered in a **suspended AWS account** (old account). When that account was suspended, the CloudFront distribution was deleted but CloudFront's global CNAME registry still held the association.

**Solution Applied:** Wildcard certificate + associate-alias approach (per AWS documentation)

**Steps Taken:**
1. ✅ Requested wildcard ACM certificate `*.app.callsaver.ai` in us-east-1
2. ✅ Deployed FrontendStagingStack with wildcard alias `*.app.callsaver.ai` (bypasses specific CNAME conflict)
3. ✅ Added DNS TXT record `_staging.app.callsaver.ai → d1d69ehy9s378n.cloudfront.net` for ownership verification
4. ✅ Ran `aws cloudfront associate-alias --target-distribution-id ELY11NNZH2QZK --alias staging.app.callsaver.ai` to claim the domain
5. ✅ Updated CDK stack to use `staging.app.callsaver.ai` instead of wildcard
6. ✅ Built frontend with staging environment variables
7. ✅ Deployed assets to S3 bucket `callsaver-frontend-staging`
8. ✅ Fixed S3 bucket policy for CloudFront OAI access

**Final Result:**
- **Distribution:** ELY11NNZH2QZK (`d1d69ehy9s378n.cloudfront.net`)
- **Custom Domain:** https://staging.app.callsaver.ai ✅ LIVE
- **SSL Certificate:** Valid (wildcard cert from ACM)
- **Status:** Fully functional staging frontend

---

## Important Fixes Applied

### DocuSeal Database Configuration (Feb 8, 2026)

**Issue:** DocuSeal container was stuck in restart loop with database configuration errors.

**Root Cause:** The Docker setup was trying to use `DATABASE_URL` which caused Rails to parse the ERB template incorrectly.

**Solution:**
1. **Removed `DATABASE_URL`** from environment variables
2. **Added bind mount `./data:/data`** to persist SQLite database
3. **Let DocuSeal use default SQLite** at `/data/db.sqlite3` (built-in behavior)

**Result:** DocuSeal now boots successfully with default SQLite database, migrations run automatically.

### DNS A Record Missing for forms.callsaver.ai (Feb 8, 2026)

**Issue:** Caddy couldn't obtain SSL certificate due to NXDOMAIN for forms.callsaver.ai.

**Root Cause:** The `Callsaver-DNS` stack requires `elasticIp` context value to create the A record for forms.callsaver.ai.

**Solution:**
```bash
# Deploy DNS stack with elasticIp context
pnpm cdk deploy Callsaver-DNS \
  -c hostedZoneId=Z0339740EIC19MEVQ7EI \
  -c elasticIp=52.53.135.206 \
  -c deploy_backend=false \
  --require-approval never
```

**Key Points:**
- Must pass `elasticIp` context when deploying DNS stack
- Use `deploy_backend=false` to avoid backend stack dependencies
- DNS record now correctly points: `forms.callsaver.ai → 52.53.135.206`

**Result:** https://forms.callsaver.ai is now accessible with valid SSL certificate.

---

## Deferred Tasks (Post-Revenue / Future Roadmap)

> **These tasks are intentionally deferred until the business has revenue or they become necessary.**

| # | Task | Description | Trigger |
|---|------|-------------|---------|
| D.1 | **Business Insurance** | General liability + E&O/cyber insurance. Skipping until revenue justifies the cost. | When revenue > $5K/mo or first enterprise client |
| D.2 | **GrowthBook A/B Testing** | Set up A/B testing on landing page and web app. SDK connected but experiments deferred. | Post-launch optimization phase |
| D.3 | **SEO Optimization** | Technical SEO, blog articles, structured data, sitemap optimization. | Post-launch growth phase |
| D.4 | **Blog Articles** | Content marketing for organic traffic. | Post-launch growth phase |
| D.5 | **Supabase Custom Domain** | `auth.callsaver.ai` — requires Pro plan ($25/mo). Deferred to task 4.20 right before launch. | Right before launch |
| D.6 | **Google Cloud Account Migration** | Switch from `scrumptiouslemur@gmail.com` to `alex@callsaver.ai`. Deferred — current account works fine. | When funds available to pay delinquent bill |
| D.7 | **Wyoming Annual Report** | $60/yr, due Feb 2027. | Feb 2027 |
| D.8 | **CA Franchise Tax** | $800, due ~June 15, 2026. | June 2026 |

---

## Phase 3: Legal & Compliance (Web App)

| # | Task | Description | Status |
|---|------|-------------|--------|
| 3.1 | **Create Web App Privacy Policy & Terms of Service** | Create comprehensive privacy policy and terms of service for the actual AI voice agent web application (staging.app.callsaver.ai and app.callsaver.ai), separate from the simplified landing page documents. **RECOMMENDATION:** Create separate pages for the web app (like landing page) and reference them in the MSA, rather than putting everything in the MSA document itself. Tasks: Review existing MSA content in `~/callsaver-api/scripts/generate-msa-pdf.ts`; Create comprehensive Privacy Policy for web app including call recording/AI processing, all third-party services (Twilio, LiveKit, OpenAI, Anthropic, etc.), data breach notification, international transfers, California rights; Create comprehensive Terms of Service including service description, payment terms/SLA, account termination, force majeure, data processing agreements; Add cross-references between MSA and web app policies; Update MSA to reference web app policy URLs; Test policy integration with web app UI. **Decision Point:** Should policies live in `~/callsaver-frontend/src/app/privacy-policy/page.tsx` & `~/callsaver-frontend/src/app/terms-of-service/page.tsx` (recommended) or be embedded directly in MSA document | ☐ |
