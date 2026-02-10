# Active Plan: Production Launch Checklist (Remaining Tasks)

> **Current Status:** Technical infrastructure mostly complete. Focus on remaining deployment, compliance, and pre-launch tasks.
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
| 1.15 | **Recreate All S3 Buckets (via CDK)** | All S3 buckets should be CDK-managed. **Per-environment** buckets (sessions, business profiles) are already created by `Callsaver-Storage-{env}`. **Shared** buckets (`callsaver-cities-counties`, `callsaver-voice-samples`) should go in a new `Callsaver-SharedData` stack since they contain identical static data used by both staging and production. **Web UI** and **DocuSeal** buckets are already CDK-managed. After CDK creates the buckets, upload voice sample audio files to `callsaver-voice-samples` and cities/counties JSON to `callsaver-cities-counties`. See Complete S3 Bucket Inventory below | ☐ |
| 1.19 | **Update GitHub Actions Secrets** | Update all GitHub Actions secrets for both repos (see Section F). Key changes: new AWS credentials, new IAM role ARN, new CloudFront distribution IDs, production Stripe publishable key (`pk_live_`). Update hardcoded old account ID `086002003598` in `deploy-staging.yml` | ☐ |
| 1.20 | **Create Supabase Production Instance** | Create a separate Supabase project for production (`callsaver-production`, region: **West US / N. California**). **Start on Free plan** — upgrade to Pro happens at launch (task 4.20). Steps: (1) Create new Free org + project in Supabase dashboard. (2) Run Prisma migrations: `DATABASE_URL=<new-pooled-url> npx prisma migrate deploy`. (3) Configure Auth settings: magic link template, redirect URLs (`https://app.callsaver.ai/...`), email templates. (4) Copy new credentials: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DATABASE_URL`, `DIRECT_URL`. (5) Update production Secrets Manager entries with new values. (6) **Migrate DocuSeal database** from staging Supabase to production Supabase: update `DATABASE_URL` in `/opt/docuseal/.env` on the EC2 instance to point to the new production Postgres, then restart DocuSeal (`sudo docker-compose down && sudo docker-compose up -d`). DocuSeal will re-run migrations on the new database. Re-create admin account at `https://forms.callsaver.ai/setup` and re-upload MSA template. **Staging continues to use existing project** (`arjdfatbdpegoyefdqfo.supabase.co`). This eliminates the risk of staging migrations breaking production | ☐ |
| 1.21 | **Configure LiveKit Cloud S3 Credentials** | LiveKit Egress writes call recordings directly to S3. In the **LiveKit Cloud dashboard** → Settings → Egress: configure AWS credentials (access key + secret) for the new AWS account so Egress can write to `callsaver-sessions-staging-us-west-1` and `callsaver-sessions-production-us-west-1`. Create a dedicated IAM user with `s3:PutObject` permission scoped to these buckets only | ☐ |
| 1.22 | **Staging Validation Checkpoint** | **✅ COMPLETED Feb 9, 2026.** Status: (1) ✅ API health endpoint responds on `staging.api.callsaver.ai` (verified). (2) ✅ Web UI loads on `staging.app.callsaver.ai` — **DEPLOYED** and fully functional. (3) ✅ Magic link login works (Supabase auth). (4) ✅ API endpoints accessible — all endpoints working after `supabase-auth.ts` fix. (5) ✅ DocuSeal API reachable from backend (completed Feb 9, 2026 — https://forms.callsaver.ai accessible with updated SMTP). **Staging fully validated and ready for production deployment.** | ✅ |

---

## Phase 2: Federal & State Compliance

| # | Task | Description | Status |
|---|------|-------------|--------|
| 2.1 | **Form New Generic LLC** | Create new Wyoming LLC with chosen name (Prosimian Labs LLC) via Northwest | ☐ |
| 2.2 | **File DBA "CallSaver"** | Register "Doing Business As" CallSaver with the new LLC | ☐ |
| 2.3 | **Execute Solo Founder OA** | Sign Northwest Registered Agent's solo founder operating agreement template | ☐ |
| 2.4 | **Get EIN** | Use Santa Cruz for "Physical Location" (private); Wyoming RA for "Mailing" | ☐ |
| 2.5 | **E-File 83(b) Election** | Log into personal IRS.gov portal; file Form 15620 using new EIN (for solo founder equity) | ☐ |
| 2.6 | **CA Virtual Office** | Secure suite + Signed Office Lease via Northwest; keep home address off CA public record | ☐ |
| 2.7 | **WY Certificate of Good Standing** | Download Certificate of Existence from Wyoming SOS ($10–$20) | ☐ |
| 2.8 | **CA Foreign Qualification** | File Form LLC-5; use CA Virtual Office as "Principal Office in California" | ☐ |
| 2.9 | **CA Registered Agent** | Finalize Northwest Registered Agent setup for California | ☐ |
| 2.10 | **Compile Startup Expense Receipts** | Collect your payment receipts for business formation, software costs, and laptop purchases (up to $5,000 IRS startup deduction) | ☐ |

---

## Phase 3: Sales & Finance Infrastructure

> **Dependency note:** Tasks 3.1–3.2 require DBA (2.2), EIN (2.4), and CA Virtual Office (2.6) to be completed first.

| # | Task | Description | Status |
|---|------|-------------|--------|
| 3.1 | **Mercury & Stripe Setup** | Apply using Santa Cruz for personal KYC; CA Virtual Office for business verification. Requires: DBA (2.2), EIN (2.4), CA office (2.6) | ☐ |
| 3.2 | **Stripe Production Mode** | Switch Stripe from test to production mode; configure production API keys | ☐ |
| 3.3 | **Stripe Webhooks (Staging + Production)** | Configure Stripe webhook endpoints for staging and production environments (in addition to existing ngrok URL) | ☐ |
| 3.4 | **AWS SES Domain Verification** | **✅ COMPLETED Feb 8, 2026.** Domain `callsaver.ai` verified in SES us-west-1. DKIM records added to DNS stack. All 6 sender identities verified: `alex@`, `info@`, `support@`, `billing@`, `legal@`, `reports@callsaver.ai` | ✅ |
| 3.4a | **Create SES SMTP Credentials for DocuSeal** | **✅ COMPLETED Feb 8, 2026.** IAM user `callsaver-ses-smtp` created with SES access. SMTP credentials stored in Secrets Manager. DocuSeal configured to send via SES | ✅ |
| 3.5 | **AWS SES Production Request** | Submit production access request (see SES Production Request Draft in appendix). If rejected, switch to **Resend** as fallback — only requires API key swap in `email-adapter.ts`, supports same sender addresses. See SES Fallback Plan below | ☐ |
| 3.6 | **Nango Webhooks (Staging + Production)** | Configure Nango webhook endpoints for staging and production environments (currently only points to ngrok) | ☐ |
| 3.7 | **Intercom Webhooks & Subscription** | Set up Intercom webhooks and verify subscription is active | ☐ |
| 3.8 | **Attio CRM: Account Migration** | Export all data from current Attio account (Azhar is primary account holder); create new Attio account under your email or contact Attio support to transfer ownership and remove Azhar's seat | ☐ |
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
| 4.8 | **Help Center / Documentation** | Set up customer-facing help center and product documentation | ☐ |
| 4.9 | **Status Page** | Set up public status page (e.g., BetterUptime, Instatus) for customer trust | ☐ |
| 4.10 | **Social Proof** | Get testimonial from Travis (electrician) for landing page | ☐ |
| 4.11 | **Upload DocuSeal MSA Template** | After DocuSeal redeploy (1.10), upload the MSA template to the new instance. Template must match your LLC/DBA name (same decision as 4.1). Code in `server.ts` dynamically fetches latest template from DocuSeal API. Verify DocuSeal API key and webhook secret are set in Secrets Manager | ☐ |
| 4.13 | **CloudWatch Alarms** | Set up CloudWatch alarms for: API ALB 5xx error rate, ECS task health (unhealthy count > 0), ECS CPU/memory utilization > 80%, ALB target response time > 5s. Configure SNS topic to email `alex@callsaver.ai` for alerts. **Also add alarms for Agent service** (CPU/memory, task health) | ☐ |
| 4.20 | **Upgrade Supabase Production to Pro** | **Do this right before launch to avoid unnecessary cost.** Upgrade the production Supabase organization to Pro ($25/mo). This unlocks: daily backups with PITR, no 7-day pause risk, 8 GB database (vs 500 MB), 100 GB storage, email support. Then enable custom domain `auth.callsaver.ai` on the production project (Pro required). Add CNAME record to Route 53 (already in DNS checklist). Update `VITE_SUPABASE_URL` / `VITE_AUTH_REDIRECT_URL` in production GitHub Actions secrets to use `https://auth.callsaver.ai`. **Staging stays on Free** — pausing and lack of backups don't matter for dev/test | ☐ |

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
- ✅ 0.1 - Domain transfer completed
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

**Phase 3:**
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

**Immediate (Rest of Feb 9):**
1. ~~Fix redirect loops~~ ✅ Done
2. ~~Update DocuSeal SMTP~~ ✅ Done
3. ~~Complete staging validation (1.22)~~ ✅ Done
4. ~~QR Code testing (1.8)~~ ✅ Done
5. Landing page full review & polish (1.6, 1.7, 4.7 — see feb9-plan.md Step 7)
6. Start business incorporation — Prosimian Labs LLC via Northwest (2.1)

**This Week:**
1. Deploy production infrastructure (1.13, 1.14)
2. Form LLC and complete compliance (Phase 2)
3. Set up banking and Stripe production (Phase 3)
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
