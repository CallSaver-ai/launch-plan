# Master Plan: Production Launch Complete Reference (Solo Founder - Max Privacy & Tech Recovery)

> **Purpose:** Complete historical record and reference document containing ALL tasks (completed + pending)
> **Current Status:** See active-plan.md for outstanding tasks and daily-plan.md for immediate next steps
> **LLC Decision:** Prosimian Labs LLC (Wyoming) DBA CallSaver

---

## Phase 0: Co-Founder Offboarding & Domain Transfer (Immediate)

| # | Task | Description | Status |
|---|------|-------------|--------|
| 0.1 | **Transfer Domain (Namecheap)** | Azhar transfers `callsaver.ai` ownership on Namecheap to your account, OR resets Namecheap credentials so you can access it directly. **P0 BLOCKER — cannot update nameservers without domain access** | ✅ Done (Feb 8) - Transfer completed, domain now under your control |
| 0.2 | **Remove Azhar from Google Workspace** | Log into Google Workspace Admin → Users → remove `azhar@callsaver.ai`. You are an admin so you can do this directly. Do this **after** DKIM export (1.2) | ☐ |
| 0.3 | **Instruct Azhar: Close Suspended AWS Account** | Azhar's AWS account (`azhar@callsaver.ai`) is suspended. He should: (1) Log into AWS console, (2) Go to Account Settings, (3) If account is suspended for non-payment, contact AWS Support to settle outstanding balance or request account closure, (4) If closure is available: Account → Close Account. Note: suspended accounts are auto-closed by AWS after 90 days of non-payment, but explicit closure is cleaner. Provide him these instructions via email/Slack | ✅ |
| 0.4 | **Pay Google Workspace Bill** | Google Workspace subscription expires in ~25 days (around March 5, 2026). Ensure payment is current to avoid losing `alex@callsaver.ai` email access | ☐ |
| 0.5 | **Create `reports@callsaver.ai`** | Create group email for weekly summary emails. Required for automated reporting system | ✅ |
| 0.6 | **Investigate Google Cloud Account** | **Deferred — current `scrumptiouslemur@gmail.com` account is working fine.** Will switch to `alex@callsaver.ai` later when funds are available to pay the delinquent bill. The `GOOGLE_API_KEY` is shared across **8 Google APIs** (Gemini, Places, Geocoding, Weather, PageSpeed, Maps JS, GBP, Routes). See `external-services-inventory.md` § 12 | ⏳ Deferred |
| 0.7 | **Restrict Google API Keys** | After resolving GCP account: (1) **Backend key** (`GOOGLE_API_KEY`) — restrict to Gemini, Places, Geocoding, Weather, PageSpeed, GBP, Routes APIs + IP-restrict to ECS NAT Gateway IPs. (2) **Frontend key** (`VITE_GOOGLE_MAPS_API_KEY`) — restrict to Maps JavaScript API + HTTP referrer restrict to `*.callsaver.ai`, `localhost:*` | ☐ |
| 0.8 | **Audit All External Service Accounts** | For each of the 23 external services (see `external-services-inventory.md`), verify: which email owns the account, billing is current, API keys are valid. Priority: AWS, Google Cloud, Twilio, Google Workspace, Namecheap (🔴 P0), then OpenAI, Deepgram, Cartesia, Anthropic, AssemblyAI, LiveKit, Sentry, Vercel, Attio, Nango, Intercom (🟡 P1) | ☐ |

---

## Phase 1: Technical Resurrection (Immediate)

> **Dependency:** Phase 0.1 (domain transfer) must complete before 1.4 (nameserver update)

| # | Task | Description | Status |
|---|------|-------------|--------|
| 1.1 | **Create New AWS Account** | Create new AWS account using mom's email and payment method (flagged on previous account with unpaid bill). Set up billing alerts ($50, $100, $200 thresholds) immediately. **P0 BLOCKER for all AWS services**. **Done:** Created with `alex@callsaver.ai` | ✅ |
| 1.1a | **Configure Local AWS CLI** | After account creation: (1) Create IAM admin user in new AWS console (IAM → Users → Create user → AdministratorAccess policy). (2) Generate access key (IAM → User → Security credentials → Create access key). (3) Update `~/.aws/credentials` with new `aws_access_key_id` and `aws_secret_access_key`. (4) Update `~/.aws/config` with `region = us-west-1`. (5) Verify with `aws sts get-caller-identity`. (6) Update any CDK deploy scripts (`deploy-local.sh`, `cdk.json`) that reference old account ID `086002003598`. **Must complete before any CDK deploy (1.3, 1.10, 1.11, etc.)**. **Done:** IAM user `alex-admin` created, credentials in `~/.aws/credentials` [default] profile, verified via `aws sts get-caller-identity`. Account ID: `836347236108`. Removed old `AWS_PROFILE=alex` from `.bashrc` | ✅ |
| 1.2 | **Export DKIM from Google Workspace** | Log into Google Workspace Admin → Apps → Gmail → Authenticate email; copy the exact DKIM record value for `callsaver.ai` before DNS cutover. **DKIM exported (regenerated Feb 8):** DNS host name: `google._domainkey`, TXT value: `v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2v3m0vOjGi9s1cSLPo0FN4TiHTyNA82sU4Fv2fM4vM80pskD7BYky96Bb7PZgHZNV6ao0dxlI6JBmynF7lns4lhaiC/Wj8LOB0799VyviHSMJ0NvpCHtwaXBuWIbpwtZhiCOVDdrW1yixcACpmUTa07qB4jKn23f1Y9+l1rIxXdXTU8L7S6VshuxOIHsP13HOK37/OKSjW3nolbvIKudlA8RH+eIMBFn6TVQ2Q4roKGK8JgdZl+as3Xa1fA1IHlGfswlAayrz30qEMKpS7d5BbArXcpJgxcY0EKA3/L+kk8E3DQR77ii05pi63AQEKwr8PV482fx/lBEPclO4knBIQIDAQAB`. Pass to CDK DNS stack (1.25) via context. After DNS is live, click "Start authentication" in Google Workspace | ✅ |
| 1.3 | **Create Route 53 Hosted Zone** | Create hosted zone for `callsaver.ai` in new AWS account — do this **manually first** (or via a minimal CDK stack) to retrieve the 4 NS records needed for task 1.4. Once the hosted zone exists, all DNS records will be managed via CDK (task 1.25). **Done:** Hosted Zone ID: `Z0339740EIC19MEVQ7EI`. NS records: `ns-156.awsdns-19.com`, `ns-1184.awsdns-20.org`, `ns-597.awsdns-10.net`, `ns-1892.awsdns-44.co.uk` | ✅ |
| 1.4 | **Update Domain Nameservers** | Log into Namecheap → Domain List → `callsaver.ai` → Nameservers → Custom DNS → paste the 4 NS records from task 1.3 (e.g., `ns-123.awsdns-45.com`). **⚠️ Propagation takes 24-48 hours** — do this ASAP after 1.3. **Done:** NS records updated in Namecheap (Feb 8, ~4:19 PM PST). Propagation clock started | ✅ |
| 1.5 | **Reactivate Vercel & Landing Page** | ✅ Vercel bill paid. GitHub Actions CI/CD workflow added to `CallSaver-ai/landing-page` for auto-deploy on push to `main`. Repos renamed: `web-ui` → `frontend`, `callsaver-landing` → `landing-page`. Branch issue fixed (Feb 9) | ✅ |
| 1.6 | **Health Check: Analytics** | **✅ COMPLETED Feb 9, 2026.** GA4 and ContentSquare verified working (GA4 showing 3 users in last 30min, ContentSquare tracking confirmed). GrowthBook SDK connected but A/B testing deferred until later phase. Analytics debugger cleaned up (removed Hotjar, fixed Cal.com detection). Environment variables fixed (added NEXT_PUBLIC_ prefix to GrowthBook credentials). | ✅ |
| 1.7 | **Cal.com GA4 Integration** | **✅ COMPLETED Feb 9, 2026.** Cal.com embed updated to: (1) Use `alexsikand/demo` (fixed from azharhuda), (2) Forward UTM params from page URL to embed config, (3) Listen for `bookingSuccessfulV2` events and fire GA4 `demo_booking_completed` conversion, (4) Track `bookerViewed` events for engagement. Booking form configured with 6 fields + hidden `qr_sid` for QR attribution. Embed colors updated to #4c00ff with forced light theme. | ✅ |
| 1.8 | **QR Code API Testing** | **✅ COMPLETED Feb 9, 2026.** QR scan tracking tested end-to-end on staging. DB migration applied, seed data created (`bcard` short code), QR image generated, `GET /q/bcard` returns 302 with `qr_sid` + UTMs + cookie, `/book` page loads Cal.com embed, scan events recorded in DB. See `qr-code-system.md`. **Decision pending:** order business cards with staging or production QR codes. | ✅ |
| 1.9 | **Order Business Assets** | Submit Moo.com order for business cards and flyers after testing confirmed | ☐ |
| 1.10 | **Redeploy DocuSeal Server** | **✅ COMPLETED Feb 9, 2026.** Server deployed at `forms.callsaver.ai` (EC2 i-0820e5048a5f6486a, EIP 52.53.135.206). **SMTP credentials updated and tested** - password synced with Secrets Manager, authentication verified. Server running with default SQLite database. Ready for production email sending. | ✅ |
| 1.10a | **Update DocuSeal API Key in Secrets Manager** | **✅ COMPLETED Feb 8, 2026.** DocuSeal admin setup completed at `https://forms.callsaver.ai/setup`. API key copied and staging secret updated in Secrets Manager | ✅ |
| 1.11 | **Reconstruct AWS Infrastructure (Staging API)** | Rebuild the full ECS/Fargate staging environment for `callsaver-api` in new AWS account. **✅ COMPLETED:** Deployed all 6 CDK stacks: (1) Callsaver-Shared (ECR repos + ACM cert), (2) Callsaver-Network-staging (VPC, subnets, NAT, security groups), (3) Callsaver-Storage-staging (S3 buckets), (4) Callsaver-Backend-staging (ECS Fargate service, ALB, task definition with Redis sidecar), (5) Callsaver-Agent-staging (Python LiveKit agent), (6) Callsaver-DNS-staging (Route 53 records). Created 45 Secrets Manager entries via `setup-secrets.sh staging`. Task role has SecretsManagerReadWrite + AmazonSESFullAccess. CDK image URI defaults fixed to use ECR repos instead of nginx. Health check verified: `https://staging.api.callsaver.ai/health` → 200 OK | ✅ |
| 1.11a | **Build & Push Docker Images to ECR** | Build and push staging Docker images to ECR repos created in 1.11. **✅ COMPLETED (Feb 8):** Both images built and pushed. Backend: `836347236108.dkr.ecr.us-west-1.amazonaws.com/callsaver-node-api:staging-latest` (git SHA `e661ac09b`). Agent: `836347236108.dkr.ecr.us-west-1.amazonaws.com/callsaver-livekit-python:staging-latest`. Fixed issues during build: removed `toNodeHandler` (Better Auth remnant), fixed Dockerfile for missing `generated/` directory | ✅ |
| 1.12 | **Deploy Web UI (Staging)** | **✅ COMPLETED Feb 9, 2026.** Deployed `callsaver-frontend` to `https://staging.app.callsaver.ai`. CloudFront CNAME conflict resolved via wildcard cert + associate-alias approach. Distribution: ELY11NNZH2QZK (`d1d69ehy9s378n.cloudfront.net`). S3 bucket: `callsaver-frontend-staging`. **ISSUE RESOLVED:** Fixed redirect loops by removing broken `require('https')` in `supabase-auth.ts` and reverting debug hacks. Staging fully functional. | ✅ |
| 1.13 | **Reconstruct AWS Infrastructure (Production API)** | Stand up production ECS/Fargate environment: `Callsaver-Network-production`, `Callsaver-Storage-production`, `Callsaver-Backend-production`, `Callsaver-Agent-production`. Create production Secrets Manager entries under `callsaver/production/backend/` and `callsaver/production/agent/` | ☐ |
| 1.14 | **Deploy Web UI (Production)** | Deploy `callsaver-web-ui` production: run CDK for `WebUiProductionStack`, then deploy static build via `deploy-production.sh` | ☐ |
| 1.15 | **Recreate All S3 Buckets (via CDK)** | All S3 buckets should be CDK-managed. **Per-environment** buckets (sessions, business profiles) are already created by `Callsaver-Storage-{env}`. **Shared** buckets (`callsaver-cities-counties`, `callsaver-voice-samples`) should go in a new `Callsaver-SharedData` stack since they contain identical static data used by both staging and production. **Web UI** and **DocuSeal** buckets are already CDK-managed. After CDK creates the buckets, upload voice sample audio files to `callsaver-voice-samples` and cities/counties JSON to `callsaver-cities-counties`. See Complete S3 Bucket Inventory below | ☐ |
| 1.16 | **Create All AWS Secrets Manager Entries (Staging)** | **✅ COMPLETED:** Created all 45 secrets (39 backend + 6 agent) via `scripts/setup-secrets.sh staging`. All secrets have real values except 3 DocuSeal placeholders (update after task 1.10a). See Comprehensive Secrets Inventory below | ✅ |
| 1.17 | **Create All AWS Secrets Manager Entries (Production)** | Create all secrets under `callsaver/production/backend/` and `callsaver/production/agent/`. Use production-specific values where different (see Section G: Staging vs Production Differences). **Run `scripts/setup-stripe-catalog.ts` against production Stripe** to generate live catalog IDs | ☐ |
| 1.18 | **Update CDK SecretsNamespace** | Add the 14 missing secrets to `~/callsaver-api/infra/cdk/lib/config.ts` (SecretsNamespace interface + `getSecretsNamespace()`) and wire them into `backend-service-stack.ts` container secrets. Missing: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DIRECT_URL`, `INTERNAL_API_KEY`, `INTERCOM_CLIENT_SECRET`, `NANGO_SECRET_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `SENDGRID_API_KEY`, `SES_CONFIGURATION_SET`, `SES_FROM_EMAIL`, `QR_IP_HASH_SECRET`, `E2E_TEST_SECRET` | ✅ |
| 1.19 | **Update GitHub Actions Secrets** | Update all GitHub Actions secrets for both repos (see Section F). Key changes: new AWS credentials, new IAM role ARN, new CloudFront distribution IDs, production Stripe publishable key (`pk_live_`). Update hardcoded old account ID `086002003598` in `deploy-staging.yml` | ☐ |
| 1.20 | **Create Supabase Production Instance** | Create a separate Supabase project for production (`callsaver-production`, region: **West US / N. California**). **Start on Free plan** — upgrade to Pro happens at launch (task 4.20). Steps: (1) Create new Free org + project in Supabase dashboard. (2) Run Prisma migrations: `DATABASE_URL=<new-pooled-url> npx prisma migrate deploy`. (3) Configure Auth settings: magic link template, redirect URLs (`https://app.callsaver.ai/...`), email templates. (4) Copy new credentials: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DATABASE_URL`, `DIRECT_URL`. (5) Update production Secrets Manager entries with new values. **Staging continues to use existing project** (`arjdfatbdpegoyefdqfo.supabase.co`). This eliminates the risk of staging migrations breaking production | ☐ |
| 1.21 | **Configure LiveKit Cloud S3 Credentials** | **IAM COMPLETED Feb 11, 2026.** Created IAM user `callsaver-livekit-egress` (`AKIA4FOROB4GDBZH7JEY`) with `LiveKitEgressS3Access` inline policy scoped to `s3:PutObject`/`s3:PutObjectAcl`/`s3:ListBucket` on `callsaver-sessions-staging` and `callsaver-sessions-production`. Created comprehensive `services/livekit-egress-setup.md` documentation. Created comprehensive `docs/ai-agent/LIVEKIT_AGENT.md` (Python voice agent technical documentation). **MANUAL STEP REMAINING:** Enter S3 credentials in LiveKit Cloud dashboard (https://cloud.livekit.io) → Settings → Egress → S3 | ⏳ IAM ✅ / Dashboard ☐ |
| 1.22 | **Staging Validation Checkpoint** | **✅ COMPLETED Feb 9, 2026.** Status: (1) ✅ API health endpoint responds on `staging.api.callsaver.ai` (verified). (2) ✅ Web UI loads on `staging.app.callsaver.ai` — **DEPLOYED** and fully functional. (3) ✅ Magic link login works (Supabase auth). (4) ✅ API endpoints accessible — all endpoints working after `supabase-auth.ts` fix. (5) ✅ DocuSeal API reachable from backend (completed Feb 9, 2026 — https://forms.callsaver.ai accessible with updated SMTP). **Staging fully validated and ready for production deployment.** | ✅ |
| 1.25 | **Create CDK DNS Stack** | **✅ COMPLETED (Feb 8):** Deployed `Callsaver-DNS-staging` stack managing all Route 53 records as IaC. Created: Vercel A/CNAME/TXT, Google Workspace MX (5 records), SPF (combined Google+SES), DKIM, DMARC, subdomain CNAMEs (`staging.api` → ALB, `api` → ALB, `book` → cal.com, `help` → intercom.help). SES records and `staging.app`/`app`/`forms`/`auth` CNAMEs pending (need CloudFront domain, Elastic IP, Supabase custom domain). Deploy command: `pnpm cdk deploy Callsaver-DNS-staging -c staging.certificateArn=<ARN> -c hostedZoneId=Z0339740EIC19MEVQ7EI` | ✅ |
| 1.23 | **Remove Hardcoded Old Account References** | Remove hardcoded ACM cert ARN (`086002003598`) from `backend-service-stack.ts`; update `deploy-local.sh` and CDK config to use new account values. **Fix `locations.ts:18`** — change hardcoded S3 region from `us-west-2` to `us-west-1` for `callsaver-cities-counties` bucket. **Must be committed before 1.11 CDK deploy** | ✅ |
| 1.24 | **Remove Better Auth Dead Code** | Better Auth (`better-auth`) has been **replaced by Supabase Auth**. Must remove before CDK deploy (1.11) since CDK will try to load `BETTER_AUTH_SECRET` from Secrets Manager. Clean up: (1) **`auth.ts`** — entire file uses `betterAuth()`, `prismaAdapter`, `magicLink` plugin. Rewrite or remove. (2) **`server.ts:35`** — remove `toNodeHandler` import; lines 396-421 `ba_session` cookie handling; line 1142-1150 reads `ba_session`; lines 1603-1617 `betterAuthUser`. (3) **`health-check.ts:11,27,55`** — remove `betterAuth` health check. (4) **`utils/session-token.ts`** — remove `BETTER_AUTH_COOKIE_NAMES`. (5) **`config/loader.ts:49-50`** — remove `BETTER_AUTH_SECRET`, `SESSION_COOKIE_NAME`. (6) **`package.json:120`** — remove `better-auth: ^1.3.32`. (7) **CDK `config.ts`** — remove `BETTER_AUTH_SECRET` from `SecretsNamespace`. (8) **`callsaver-web-ui/.env`** — remove `VITE_BETTER_AUTH_URL`. **Do NOT create `BETTER_AUTH_SECRET` in Secrets Manager** | ✅ |

### DNS Recreation Checklist (Full Rebuild)

> **Old Route 53 is dead.** Cannot recover cached records. All DNS must be recreated from scratch in the new hosted zone.

#### 1. Vercel (Landing Page)

| Record Type | Host | Value | Source |
|---|---|---|---|
| A | `callsaver.ai` | `76.76.21.21` | Vercel docs |
| CNAME | `www.callsaver.ai` | `cname.vercel-dns.com` | Redirect www → apex |
| TXT | `_vercel.callsaver.ai` | *(get from Vercel dashboard → Domains)* | Vercel domain ownership verification |

#### 2. Google Workspace (Gmail)

| Record Type | Host | Value | Source |
|---|---|---|---|
| MX | `callsaver.ai` | `1 ASPMX.L.GOOGLE.COM` | Google Workspace Admin |
| MX | `callsaver.ai` | `5 ALT1.ASPMX.L.GOOGLE.COM` | Google Workspace Admin |
| MX | `callsaver.ai` | `5 ALT2.ASPMX.L.GOOGLE.COM` | Google Workspace Admin |
| MX | `callsaver.ai` | `10 ALT3.ASPMX.L.GOOGLE.COM` | Google Workspace Admin |
| MX | `callsaver.ai` | `10 ALT4.ASPMX.L.GOOGLE.COM` | Google Workspace Admin |
| TXT | `callsaver.ai` | `v=spf1 include:_spf.google.com include:amazonses.com ~all` | Combined SPF for Google Workspace + AWS SES (must be ONE record) |
| CNAME | `google._domainkey.callsaver.ai` | *(export from Admin → Apps → Gmail → Authenticate email)* | DKIM signing key |
| TXT | `callsaver.ai` | `google-site-verification=...` | Get from Admin console or Search Console |

#### 3. DMARC (Email Protection)

| Record Type | Host | Value | Source |
|---|---|---|---|
| TXT | `_dmarc.callsaver.ai` | `v=DMARC1; p=quarantine; rua=mailto:alex@callsaver.ai` | Create new — protects email reputation |

#### 4. AWS SES (Transactional Email)

| Record Type | Host | Value | Source |
|---|---|---|---|
| TXT | `_amazonses.callsaver.ai` | *(generated by SES domain verification)* | New AWS console → SES → Verified identities |
| CNAME | `*._domainkey.callsaver.ai` (x3) | *(generated by SES DKIM setup)* | New AWS console → SES → DKIM |
| MX | `mail.callsaver.ai` | `10 feedback-smtp.us-west-1.amazonses.com` | Custom MAIL FROM — removes "via amazonses.com" from emails |
| TXT | `mail.callsaver.ai` | `v=spf1 include:amazonses.com ~all` | SPF for custom MAIL FROM subdomain |

#### 5. Subdomains (API, Frontend, DocuSeal, Services)

| Record Type | Host | Value | Source |
|---|---|---|---|
| A | `forms.callsaver.ai` | Elastic IP (from DocuSeal CDK output) | DocuSeal e-signature service |
| CNAME | `staging.api.callsaver.ai` | ALB DNS name (from ECS CDK output) | Staging API |
| CNAME | `api.callsaver.ai` | ALB DNS name (production ECS) | Production API |
| CNAME | `staging.app.callsaver.ai` | CloudFront distribution domain (from WebUiStagingStack output) | Staging frontend |
| CNAME | `app.callsaver.ai` | CloudFront distribution domain (from WebUiProductionStack output) | Production frontend |
| CNAME | `book.callsaver.ai` | *(get from Cal.com dashboard → Settings → Organizations → Custom domain)* | Cal.com Cloud booking page |
| CNAME | `help.callsaver.ai` | *(get from Intercom → Settings → Help Center → Custom domain)* | Intercom help center (professional support URL) |
| CNAME | `auth.callsaver.ai` | *(get from Supabase dashboard → Settings → Custom Domains)* | Supabase auth redirects (hides `arjdfatbdpegoyefdqfo.supabase.co`) |

#### 6. ACM Certificate Validation (Auto-Generated)

| Record Type | Host | Value | Source |
|---|---|---|---|
| CNAME | *(auto-generated)* | *(auto-generated)* | ACM cert for `staging.api.callsaver.ai` (us-west-1) |
| CNAME | *(auto-generated)* | *(auto-generated)* | ACM cert for `api.callsaver.ai` (us-west-1) |
| CNAME | *(auto-generated)* | *(auto-generated)* | ACM cert for `staging.app.callsaver.ai` (us-east-1) |
| CNAME | *(auto-generated)* | *(auto-generated)* | ACM cert for `app.callsaver.ai` (us-east-1) |

> **Important:** ACM DNS validation CNAME records are unique per certificate request. Create the certificates first, then add the validation records to Route 53. Certificates won't activate until validation completes.

#### 7. Google Search Console

| Record Type | Host | Value | Source |
|---|---|---|---|
| TXT | `callsaver.ai` | `google-site-verification=...` | Get from [Search Console](https://search.google.com/search-console) → Add Property → Domain → DNS verification |

> **Note:** This may be a different verification token than Google Workspace. Search Console lets you monitor indexing, SEO, sitemaps, and crawl issues for `callsaver.ai`.

> **Note on Gmail:** If MX, SPF, and DKIM are recreated correctly, Gmail should continue working without re-authentication. Export DKIM key from Google Workspace Admin **before** switching nameservers. SES records must be regenerated fresh on the new account.
>
> **Note on analytics (GA4, ContentSquare, GrowthBook):** No DNS records needed. These are JavaScript SDKs loaded via `<script>` tags, already configured in the codebase.

### AWS Infrastructure Reference (Reconstruct in New Account)

> Inferred from CDK stacks in `~/callsaver-api/infra/cdk/`. All resources must be recreated from scratch in the new AWS account.

**Pre-requisites (one-time setup):**
- CDK Bootstrap (`cdk bootstrap aws://<ACCOUNT_ID>/us-west-1`)
- Create ECR repositories: `backend` (Node.js API) and `agent` (Python LiveKit agent)
- Create IAM OIDC provider for GitHub Actions (role: `STAGING_AWS_ROLE_ARN`)
- Create IAM user with S3 + CloudFront permissions for web-ui GitHub Actions (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`)
- Create ACM certificate for `staging.api.callsaver.ai` in `us-west-1` (for API ALB)
- Create ACM certificate for `api.callsaver.ai` in `us-west-1` (for production API ALB)
- Create ACM certificate for `staging.app.callsaver.ai` in **`us-east-1`** (required for CloudFront)
- Create ACM certificate for `app.callsaver.ai` in **`us-east-1`** (required for CloudFront)
- Remove hardcoded old account cert ARN (`086002003598`) from `backend-service-stack.ts`
- Clear `cdk.context.json` in `~/callsaver-docuseal` (old account IDs `086002003598`, `005626493022`)
- Clear `cdk.context.json` in `~/callsaver-web-ui/infra` (old account ID `086002003598`, VPC/subnet IDs)
- Clear `cdk.context.json` in `~/callsaver-api/infra/cdk` (old account VPC/subnet lookups — **confirmed this file exists**)

**CloudFormation Stacks (via CDK, `us-west-1`):**

| Stack | Resources | Notes |
|-------|-----------|-------|
| `Callsaver-Network-staging` | VPC (2 AZs, 1 NAT GW), ALB security group (80/443), Fargate service SG (8080 from ALB) | CIDR `10.42.0.0/16` |
| `Callsaver-Storage-staging` | S3: `callsaver-sessions-staging` (30-day lifecycle), S3: `callsaver-business-profiles-us-west-1` (versioned, intelligent tiering) | SSM params for bucket names |
| `Callsaver-Backend-staging` | ECS Cluster (`callsaver-staging`), Fargate Service (`callsaver-staging-v0`, 256 CPU / 512 MB), ALB (internet-facing, HTTP→HTTPS redirect), Blue/Green target groups, CloudWatch Logs (3-day retention), Auto-scaling (1–2 tasks, 60% CPU) | Rolling deploy for staging, Blue/Green for prod |
| `Callsaver-Agent-staging` | Fargate Service (`callsaver-agent-staging`, 512 CPU / 2048 MB), Connects to LiveKit Cloud (`wss://callsaver-d8dm5v36.livekit.cloud`), Auto-scaling (1–2 tasks, 80% CPU) | No ALB — outbound only to LiveKit |

**Web UI Stacks (via CDK in `~/callsaver-web-ui/infra/`):**

| Stack | Resources | Notes |
|-------|-----------|-------|
| `WebUiStagingStack` | S3: `callsaver-web-ui-staging` (versioned, block public access), CloudFront distribution (`E337E74N4D2WS9`), OAI for S3 access | SPA routing: 403/404 → `/index.html` |
| `WebUiProductionStack` | S3: `callsaver-web-ui-production`, CloudFront distribution (`E376Z8D1B8SNQ3`) | Same pattern as staging |

**Complete S3 Bucket Inventory (recreate all in new account):**

| Bucket | Region | CDK Stack | Purpose |
|--------|--------|-----------|---------|
| `callsaver-sessions-staging` | us-west-1 | `Callsaver-Storage-staging` | Call recordings — **actively used by LiveKit Egress**. 30-day lifecycle |
| `callsaver-sessions-production` | us-west-1 | `Callsaver-Storage-production` | Call recordings (production) |
| `callsaver-company-website-extractions` | us-west-1 | `Callsaver-Storage-staging` | Business profiles extracted by crawl4ai pipeline. **This IS the business profiles bucket** — set `BUSINESS_PROFILES_S3_BUCKET` to this value in Secrets Manager. Used by both staging and production |
| `callsaver-cities-counties` | us-west-1 | **`Callsaver-SharedData`** (new) | Cities/counties JSON for location picker. Shared across envs. **⚠️ Code fix in task 1.23: `locations.ts:18` hardcodes `us-west-2` → `us-west-1`** |
| `callsaver-voice-samples` | us-west-1 | **`Callsaver-SharedData`** (new) | Voice sample audio files — **must re-upload audio files** after CDK creates bucket. Shared across envs |
| `callsaver-web-ui-staging` | us-west-1 | `WebUiStagingStack` | Staging web UI static files |
| `callsaver-web-ui-production` | us-west-1 | `WebUiProductionStack` | Production web UI static files |
| `callsaver-forms-us-west-1` | us-west-1 | `DocusealStack` | DocuSeal attachments |

> **All S3 buckets are CDK-managed.** Per-environment buckets live in `Callsaver-Storage-{env}`. Shared static-data buckets (`callsaver-cities-counties`, `callsaver-voice-samples`) live in a new `Callsaver-SharedData` stack — create this CDK stack in `~/callsaver-api/infra/cdk/`.

> **`BUSINESS_PROFILES_S3_BUCKET`** in Secrets Manager = `callsaver-company-website-extractions` (confirmed — this is the single bucket used by both the crawl4ai pipeline and the API's provisioning system).

### Comprehensive Secrets Inventory

> **Source of truth:** Cross-referenced from `~/callsaver-api/.env` (132 lines), CDK `config.ts` (SecretsNamespace), `agent-service-stack.ts`, and GitHub Actions workflows. Secrets marked ⚠️ are **NOT yet in CDK** — they must be added to CDK stacks or set as ECS environment variables.

#### A. AWS Secrets Manager — Backend (`callsaver/{env}/backend/`)

> These are loaded by CDK `backend-service-stack.ts` via `getSecretsNamespace()`. Create for both `staging` and `production`.

| # | Secret Path | Description | Staging Value | Production Value | In CDK? |
|---|------------|-------------|---------------|-----------------|---------|
| 1 | `DATABASE_URL` | Supabase Postgres (pooled via PgBouncer port 6543) | Existing project (`arjdfatbdpegoyefdqfo`) | **DIFFERENT** (new production project) | ✅ |
| 2 | `REDIS_URL` | Redis connection URL | `redis://localhost:6379` (sidecar) | **DIFFERENT** — Upstash URL (`rediss://...`) per task 4.21 | ✅ |
| 3 | ~~`BETTER_AUTH_SECRET`~~ | **DEPRECATED — DO NOT CREATE.** Better Auth has been replaced by Supabase Auth. Remove from CDK `SecretsNamespace` and `config/loader.ts`. See task 1.24 | N/A | N/A | ✅ (remove) |
| 4 | `SENTRY_DSN` | Sentry project DSN | Same | Same | ✅ |
| 5 | `SENTRY_ENVIRONMENT` | Environment name | `staging` | `production` | ✅ |
| 6 | `NODE_ENV` | Node environment | `production` | `production` | ✅ |
| 7 | `APP_ENV` | App environment (controls URL routing) | `staging` | `production` | ✅ |
| 8 | `SESSION_S3_BUCKET` | Call recording bucket | `callsaver-sessions-staging` | `callsaver-sessions-production` | ✅ |
| 9 | `BUSINESS_PROFILES_S3_BUCKET` | Business profiles bucket | `callsaver-company-website-extractions` | `callsaver-company-website-extractions` | ✅ |
| 10 | `PROVISION_API_KEY` | Internal provisioning auth | Same | Same | ✅ |
| 11 | `INTERCOM_ACCESS_TOKEN` | Intercom API token | Same | Same | ✅ |
| 12 | `ATTIO_API_KEY` | Attio CRM API key | Same | Same | ✅ |
| 13 | `STRIPE_SECRET_KEY` | Stripe secret key | `sk_test_...` | `sk_live_...` (**DIFFERENT**) | ✅ |
| 14 | `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing | Different per endpoint | Different per endpoint | ✅ |
| 15 | `STRIPE_PRICE_ID` | Legacy single price ID | Test price | Live price | ✅ |
| 16 | `STRIPE_SUCCESS_URL` | Post-checkout redirect | `https://staging.app.callsaver.ai/...` | `https://app.callsaver.ai/...` | ✅ |
| 17 | `STRIPE_CANCEL_URL` | Cancelled checkout redirect | `https://staging.app.callsaver.ai/...` | `https://app.callsaver.ai/...` | ✅ |
| 18 | `TWILIO_ACCOUNT_SID` | Twilio account SID | Same | Same | ✅ |
| 19 | `TWILIO_AUTH_TOKEN` | Twilio auth token | Same | Same | ✅ |
| 20 | `LIVEKIT_URL` | LiveKit Cloud WebSocket URL | Same | Same | ✅ |
| 21 | `LIVEKIT_API_KEY` | LiveKit API key | Same | Same | ✅ |
| 22 | `LIVEKIT_API_SECRET` | LiveKit API secret | Same | Same | ✅ |
| 23 | `DOCS_PASSWORD` | API docs access password | Same | Same | ✅ |
| 24 | `DOCUSEAL_API_KEY` | DocuSeal API key | Same | Same | ✅ |
| 25 | `DOCUSEAL_WEBHOOK_SECRET` | DocuSeal webhook signing | Same | Same | ✅ |
| 26 | `DOCUSEAL_API_URL` | DocuSeal server URL | `https://forms.callsaver.ai` | `https://forms.callsaver.ai` | ✅ |
| 27 | `SUPABASE_URL` | Supabase project URL | Existing project URL | **DIFFERENT** (new production project URL) | ⚠️ **MISSING** |
| 28 | `SUPABASE_ANON_KEY` | Supabase publishable key | Existing project key | **DIFFERENT** (new production project key) | ⚠️ **MISSING** |
| 29 | `SUPABASE_SERVICE_ROLE_KEY` | Supabase admin key (creates users) | Existing project key | **DIFFERENT** (new production project key) | ⚠️ **MISSING** |
| 30 | `DIRECT_URL` | Supabase direct connection (Prisma migrations, bypasses PgBouncer, port 5432) | Existing project direct URL | **DIFFERENT** (new production project direct URL) | ⚠️ **MISSING** |
| 31 | `INTERNAL_API_KEY` | API-to-API internal auth (separate from PROVISION_API_KEY) | Same | Same | ⚠️ **MISSING** |
| 32 | `INTERCOM_CLIENT_SECRET` | Intercom webhook signature verification | Same | Same | ⚠️ **MISSING** |
| 33 | `NANGO_SECRET_KEY` | Nango integration key | Same | Same | ⚠️ **MISSING** |
| 34 | `OPENAI_API_KEY` | OpenAI (used by backend for category classification LLM) | Same | Same | ⚠️ **MISSING** (only in agent) |
| 35 | `GOOGLE_API_KEY` | Google Places API (used by backend for place details) | Same | Same | ⚠️ **MISSING** (only in agent) |
| 36 | `SENDGRID_API_KEY` | SendGrid (legacy — may be replaced by SES) | Same | Same | ⚠️ **MISSING** — evaluate if still needed |
| 37 | `SES_CONFIGURATION_SET` | SES event tracking configuration set name | `callsaver-transactional` | `callsaver-transactional` | ⚠️ **MISSING** |
| 38 | `SES_FROM_EMAIL` | SES default sender | `alex@callsaver.ai` | `alex@callsaver.ai` | ⚠️ **MISSING** |
| 39 | `QR_IP_HASH_SECRET` | QR code IP hashing secret | Same | Same | ⚠️ **MISSING** |
| 40 | `E2E_TEST_SECRET` | E2E test authentication bypass | Same | **DO NOT SET in production** | ⚠️ **MISSING** |

> **⚠️ 14 secrets are NOT in the CDK SecretsNamespace yet.** Must add to `config.ts` and `backend-service-stack.ts` before deploying.

#### B. ECS Environment Variables (non-secret, set in CDK task definition)

> These are NOT secrets — they are plain environment variables set in the container definition.

| Env Var | Staging Value | Production Value | Notes |
|---------|---------------|-----------------|-------|
| `AWS_REGION` | `us-west-1` | `us-west-1` | Set by CDK |
| `APP_URL` | `https://staging.app.callsaver.ai` | `https://app.callsaver.ai` | **DIFFERENT** |
| `API_URL` | `https://staging.api.callsaver.ai` | `https://api.callsaver.ai` | **DIFFERENT** |
| `REDIS_URL` | `redis://localhost:6379` | Upstash URL (`rediss://...`) | **DIFFERENT** per task 4.21 |
| `SKIP_TWILIO_PURCHASE` | `true` (mock) → `false` (live) | `false` | Toggle for launch |
| `MAGIC_LINK_CALLBACK_URL` | `/onboarding` | `/onboarding` | Relative path |
| `MAGIC_LINK_NEW_USER_CALLBACK_URL` | `/onboarding` | `/onboarding` | Relative path |
| `OPENAI_MODEL` | `gpt-4.1-mini-2025-04-14` | `gpt-4.1-mini-2025-04-14` | LLM model |
| `FEATURE_ATTIO_SYNC_ENABLED` | `true` | `true` | Feature flag |
| `ENABLE_ATTIO_WORKERS` | `true` | `true` | Feature flag |
| ~~`SESSION_COOKIE_NAME`~~ | ~~`ba_session`~~ | ~~`ba_session`~~ | **DEPRECATED** — Better Auth cookie. Remove per task 1.24 |
| `TRUST_PROXY_COUNT` | `1` | `1` | **Required for ECS behind ALB** — Express needs this to get real client IPs for rate limiting. Without it, all requests appear from ALB IP |
| `USE_AWS_SECRETS` | `true` | `true` | Load secrets from AWS (set `false` locally) |

#### C. Stripe Catalog IDs (create in both staging and production Secrets Manager)

> These 19 env vars are product/price IDs from Stripe. **Staging uses `sk_test_` keys → test catalog. Production uses `sk_live_` keys → live catalog.** You must run `scripts/setup-stripe-catalog.ts` against production Stripe to generate live IDs.

| Secret | Description | Same across envs? |
|--------|-------------|-------------------|
| `STRIPE_METER_ID` | Usage meter | **DIFFERENT** (test vs live) |
| `STRIPE_PRODUCT_OPERATOR` | Operator plan product | **DIFFERENT** |
| `STRIPE_PRODUCT_GROWTH` | Growth plan product | **DIFFERENT** |
| `STRIPE_PRODUCT_ENTERPRISE` | Enterprise plan product | **DIFFERENT** |
| `STRIPE_PRODUCT_VOICE_USAGE` | Voice usage product | **DIFFERENT** |
| `STRIPE_PRODUCT_IMPLEMENTATION_FEE` | Implementation fee product | **DIFFERENT** |
| `STRIPE_PRODUCT_ADDON_LOCATION` | Location add-on product | **DIFFERENT** |
| `STRIPE_PRODUCT_ADDON_REVIEWS` | Reviews add-on product | **DIFFERENT** |
| `STRIPE_PRICE_OPERATOR_MONTHLY` | Operator monthly price | **DIFFERENT** |
| `STRIPE_PRICE_OPERATOR_ANNUAL` | Operator annual price | **DIFFERENT** |
| `STRIPE_PRICE_GROWTH_MONTHLY` | Growth monthly price | **DIFFERENT** |
| `STRIPE_PRICE_GROWTH_ANNUAL` | Growth annual price | **DIFFERENT** |
| `STRIPE_PRICE_ENTERPRISE_MONTHLY` | Enterprise monthly price | **DIFFERENT** |
| `STRIPE_PRICE_ENTERPRISE_ANNUAL` | Enterprise annual price | **DIFFERENT** |
| `STRIPE_PRICE_USAGE_STANDARD` | Standard usage price | **DIFFERENT** |
| `STRIPE_PRICE_USAGE_ENTERPRISE` | Enterprise usage price | **DIFFERENT** |
| `STRIPE_PRICE_IMPLEMENTATION_FEE` | Implementation fee price | **DIFFERENT** |
| `STRIPE_PRICE_ADDON_LOCATION` | Location add-on price | **DIFFERENT** |
| `STRIPE_PRICE_ADDON_REVIEWS` | Reviews add-on price | **DIFFERENT** |

> **Action required:** These 19 Stripe catalog IDs must either be (a) added to CDK SecretsNamespace and loaded as ECS secrets, or (b) stored as a single JSON secret. Currently they are NOT in CDK at all — they only exist in `.env`.

#### D. AWS Secrets Manager — Agent (`callsaver/{env}/agent/`)

> Loaded by `agent-service-stack.ts`. The agent also reads `LIVEKIT_*` and `PROVISION_API_KEY` from the backend namespace.

| # | Secret Path | Description | Same across envs? |
|---|------------|-------------|-------------------|
| 1 | `OPENAI_API_KEY` | OpenAI API key (primary LLM) | Same |
| 2 | `DEEPGRAM_API_KEY` | Deepgram STT API key | Same |
| 3 | `CARTESIA_API_KEY` | Cartesia TTS API key | Same |
| 4 | `ASSEMBLYAI_API_KEY` | AssemblyAI (fallback STT) | Same |
| 5 | `ANTHROPIC_API_KEY` | Anthropic (fallback LLM) | Same |
| 6 | `GOOGLE_API_KEY` | Google (fallback) | Same |

> Agent also receives these via CDK environment variables (not secrets): `LIVEKIT_URL`, `LIVEKIT_WORKER_NAME`, `API_URL`, `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE`
> Agent reads from backend namespace: `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `PROVISION_API_KEY` (as `INTERNAL_API_KEY`), `SENTRY_DSN`

#### E. LiveKit Agent Environment Variables (set in CDK, not secrets)

| Env Var | Value | Notes |
|---------|-------|-------|
| `LIVEKIT_URL` | `wss://callsaver-d8dm5v36.livekit.cloud` | LiveKit Cloud endpoint |
| `LIVEKIT_WORKER_NAME` | `callsaver-agent` | Must match dispatch rule |
| `API_URL` | `https://staging.api.callsaver.ai` or `https://api.callsaver.ai` | **DIFFERENT** per env |
| `SENTRY_ENVIRONMENT` | `staging` or `production` | **DIFFERENT** per env |
| `SENTRY_RELEASE` | Git SHA or `local` | Set at deploy time |

#### F. GitHub Actions Secrets

**`callsaver-api` repo:**

| Secret | Description | Action |
|--------|-------------|--------|
| `STAGING_AWS_ROLE_ARN` | IAM role ARN for OIDC-based deployment | **New value** from new account |
| `COSIGN_PRIVATE_KEY` | Container image signing key | **Regenerate** |
| `COSIGN_PASSWORD` | Cosign key password | **Regenerate** |
| `COSIGN_PUBLIC_KEY` | Cosign public key | **Regenerate** |

**`callsaver-web-ui` repo:**

| Secret | Description | Action |
|--------|-------------|--------|
| `AWS_ACCESS_KEY_ID` | IAM user for S3/CloudFront deploy | **New value** from new account |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret | **New value** from new account |
| `VITE_SUPABASE_URL` | Supabase project URL | Verify (same Supabase project) |
| `VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY` | Supabase publishable key | Verify (same) |
| `VITE_STRIPE_PUBLISHABLE_KEY` | Stripe publishable key | **`pk_test_` → `pk_live_`** for production |
| `VITE_GOOGLE_MAPS_API_KEY` | Google Maps API key | Verify still valid |
| `VITE_SENTRY_DSN` | Sentry DSN | Update after Sentry reactivation |

**Hardcoded values in GitHub Actions workflows (update after CDK creates new resources):**

| File | Value | What to update |
|------|-------|---------------|
| `deploy-web-ui-staging.yml` | `E337E74N4D2WS9` | New staging CloudFront distribution ID |
| `deploy-web-ui-production.yml` | `E376Z8D1B8SNQ3` | New production CloudFront distribution ID |
| `deploy-web-ui-production.yml` | `VITE_API_URL: https://api.callsaver.ai` | Verify correct |
| `deploy-staging.yml` | `086002003598` in IAM policy ARN | New AWS account ID |

#### G. Summary: Staging vs Production Differences

| Secret/Config | Staging | Production |
|--------------|---------|------------|
| `APP_ENV` | `staging` | `production` |
| `SENTRY_ENVIRONMENT` | `staging` | `production` |
| `APP_URL` | `https://staging.app.callsaver.ai` | `https://app.callsaver.ai` |
| `API_URL` | `https://staging.api.callsaver.ai` | `https://api.callsaver.ai` |
| `SESSION_S3_BUCKET` | `callsaver-sessions-staging` | `callsaver-sessions-production` |
| `STRIPE_SECRET_KEY` | `sk_test_...` | `sk_live_...` |
| `STRIPE_WEBHOOK_SECRET` | Staging endpoint secret | Production endpoint secret |
| `STRIPE_SUCCESS_URL` | `https://staging.app.callsaver.ai/onboarding/success` | `https://app.callsaver.ai/onboarding/success` |
| `STRIPE_CANCEL_URL` | `https://staging.app.callsaver.ai/onboarding/cancel` | `https://app.callsaver.ai/onboarding/cancel` |
| All 19 Stripe catalog IDs | Test catalog IDs (`prod_Ts...`, `price_1Su...`) | Live catalog IDs (run `setup-stripe-catalog.ts`) |
| `SKIP_TWILIO_PURCHASE` | `true` (mock) → later `false` | `false` |
| `E2E_TEST_SECRET` | Set for testing | **DO NOT SET** |
| `REDIS_URL` | `redis://localhost:6379` (sidecar) | **Upstash URL** (`rediss://...`) per task 4.21 |
| ~~`BETTER_AUTH_SECRET`~~ | **DEPRECATED** — remove, not needed with Supabase Auth | N/A |
| `PROVISION_API_KEY` | Generate unique staging value | **DIFFERENT** (generate separate production value) |
| `QR_IP_HASH_SECRET` | Generate unique staging value | **DIFFERENT** (generate separate production value) |

| `DATABASE_URL` | Existing Supabase project (pooled) | **DIFFERENT** (new production Supabase project) |
| `DIRECT_URL` | Existing Supabase project (direct) | **DIFFERENT** (new production Supabase project) |
| `SUPABASE_URL` | `https://arjdfatbdpegoyefdqfo.supabase.co` | **DIFFERENT** (new production project URL) |
| `SUPABASE_ANON_KEY` | Existing project anon key | **DIFFERENT** (new production project key) |
| `SUPABASE_SERVICE_ROLE_KEY` | Existing project service role key | **DIFFERENT** (new production project key) |

> **Everything else is identical** across staging and production (same Twilio account, same LiveKit Cloud project, same third-party API keys).

**Deployment scripts (`callsaver-api`):**
- Local: `~/callsaver-api/deploy-local.sh` (builds Docker image, pushes to ECR, runs CDK deploy)
- CI: `.github/workflows/deploy-staging.yml` (GitHub Actions, manual `workflow_dispatch`)
- Production: `.github/workflows/deploy-prod.yml` (manual, requires Cosign verification)

**Deployment scripts (`callsaver-web-ui`):**
- Local staging: `~/callsaver-web-ui/scripts/deploy-staging.sh` (Vite build → S3 sync → CloudFront invalidation)
- Local production: `~/callsaver-web-ui/scripts/deploy-production.sh` (same flow, production bucket/distribution)
- CI staging: `.github/workflows/deploy-web-ui-staging.yml` (push to `staging` branch)
- CI production: `.github/workflows/deploy-web-ui-production.yml` (push to `main` branch)

### DocuSeal Deployment Reference

> Source: `~/callsaver-docuseal/`. CDK stack deploys EC2 + Caddy + Docker Compose.

**Architecture:** EC2 t3.small (~$15/mo) + Caddy (auto-HTTPS via Let's Encrypt) + S3 bucket for attachments + Elastic IP

**Deploy command:**
```bash
cd ~/callsaver-docuseal
./deploy.sh -d forms.callsaver.ai -e alex@callsaver.ai \
  -u alex@callsaver.ai -p '<gmail-app-password>'
```

**Required changes before deploying:**
- Update `.env`: change `ADMIN_EMAIL`, `SMTP_USERNAME`, `SMTP_FROM` from `azhar@callsaver.ai` → `alex@callsaver.ai`
- Update `.env`: change `SMTP_PASSWORD` to your Gmail App Password
- Regenerate `SECRET_KEY_BASE` (current one was set by Azhar)
- Delete `cdk.context.json` (contains old account IDs `086002003598`, `005626493022`)
- **Change `AWS_REGION` in `.env` from `us-west-2` (Oregon) to `us-west-1` (N. California)** — previously deployed in wrong region
- Set `CDK_DEFAULT_REGION=us-west-1` before running deploy script
- After deploy: create A record `forms.callsaver.ai` → Elastic IP from CDK output

**Resources created:**
| Resource | Details |
|----------|--------|
| EC2 | t3.small, Amazon Linux 2023, encrypted EBS 20GB GP3, **us-west-1** |
| S3 | `callsaver-forms-us-west-1` (attachments, lifecycle policies) |
| Elastic IP | Static public IP for DNS A record |
| Security Group | HTTP (80) + HTTPS (443) only, no SSH (use SSM) |
| IAM Role | S3 + SSM permissions |
| CloudWatch Logs | Container monitoring |

**Access instance:** `aws ssm start-session --target <instance-id>`

### Provisioning Flow Reference

> The provisioning system creates Organizations, Users, Locations, Agents, and Phone Numbers when a customer completes the MSA + Stripe checkout.

**Current flow:** `provision-handler.ts` → DocuSeal MSA signing → Stripe checkout → `provision-execution.ts`

**Key env vars controlling mock/live behavior:**

| Env Var | Current Value | Effect |
|---------|---------------|--------|
| `SKIP_TWILIO_PURCHASE` | `true` | Creates mock phone number records (`+15555550100`) instead of purchasing real Twilio numbers |
| `TWILIO_ACCOUNT_SID` | set (but account delinquent) | Twilio API access — currently non-functional due to -$22 balance |
| `TWILIO_AUTH_TOKEN` | set (but account delinquent) | Twilio API auth |
| `LIVEKIT_URL` | `wss://callsaver-d8dm5v36.livekit.cloud` | LiveKit Cloud endpoint for SIP trunk setup |
| `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET` | set | LiveKit API access for SIP provisioning |

**To go live with phone provisioning:**
1. Pay Twilio $22 delinquent balance (3.13)
2. Set `SKIP_TWILIO_PURCHASE=false` in Secrets Manager (staging + production)
3. Verify LiveKit SIP integration is working (agent connects to LiveKit Cloud, SIP trunk routes calls)

**Provisioning steps per customer:**
1. Customer signs MSA on DocuSeal (`forms.callsaver.ai`)
2. Alex countersigns (currently hardcoded to `azhar@callsaver.ai` — must fix per 4.12)
3. Stripe checkout session created → customer enters payment
4. On checkout completion: Organization, User, Location(s) created
5. Business profile fetched from `callsaver-company-website-extractions` S3 bucket
6. Categories classified via LLM, service areas set from Google Place data
7. System prompt generated and stored on Agent model
8. Phone number provisioned via Twilio (or mocked) → LiveKit SIP trunk created

---

## Phase 2: Federal & State Compliance (Monday Morning)

| # | Task | Description | Status |
|---|------|-------------|--------|
| 2.0 | **Decide LLC Name** | Brainstorm and finalize the Wyoming LLC name before filing. This name appears in: (1) MSA legal entity disclosure (*"CallSaver" is a trade name of [LLC Name], a Wyoming limited liability company*), (2) DocuSeal MSA template, (3) Banking/Mercury account, (4) Stripe legal entity, (5) EIN application, (6) All government filings. **Must decide before 2.1**. **Decision:** Prosimian Labs LLC | ✅ |
| 2.1 | **Form Prosimian Labs LLC (Wyoming)** | ✅ COMPLETED Feb 10, 2026. Articles of Organization filed with Northwest Registered Agent. Operating Agreement signed via DocuSeal. EIN obtained. Business documents stored in ~/callsaver-documents. | ✅ |
| 2.2 | **File DBA "CallSaver" (Santa Cruz County)** | **WAITING FOR CA LLC-12.** Will file after CA foreign LLC registration is approved and CA Statement of Information (Form LLC-12) is filed. FBN requires: Wyoming Certificate of Organization + CA SI-550. Filing fee: $50 + $8. Publication required within 45 days. | ⏳ Blocked on 2.8 |
| 2.3 | **Execute Solo Founder OA** | ✅ COMPLETED Feb 10, 2026. Operating agreement drafted, reviewed, and signed via DocuSeal. | ✅ |
| 2.4 | **Get EIN** | ✅ COMPLETED Feb 10, 2026. EIN obtained from IRS for Prosimian Labs LLC. | ✅ |
| 2.5 | ~~**E-File 83(b) Election**~~ | **N/A — Not needed.** Single-member LLC with no equity grants; 83(b) election is unnecessary. | N/A |
| 2.6 | **CA Virtual Office** | **WAITING FOR CA LLC-5.** Northwest virtual office setup will be finalized after CA foreign LLC registration is approved. Address: 2108 N St, Ste N, Sacramento, CA 95816. | ⏳ Blocked on 2.8 |
| 2.7 | **WY Certificate of Good Standing** | ✅ COMPLETED. Certificate of Existence obtained from Wyoming SOS. | ✅ |
| 2.8 | **CA Foreign Qualification** | **SUBMITTED Feb 10, 2026.** Form LLC-5 filed with California Secretary of State. Waiting for approval. Uses Northwest as CA registered agent. | ⏳ In Progress |
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
| 3.4 | **AWS SES Domain Verification** | **✅ COMPLETED Feb 8, 2026.** Domain `callsaver.ai` verified in SES us-west-1. DKIM records added to DNS stack. All sender identities verified: `alex@`, `info@`, `support@`, `billing@`, `legal@`, `reports@callsaver.ai`. Custom MAIL FROM configured | ✅ |
| 3.4a | **Create SES SMTP Credentials for DocuSeal** | **✅ COMPLETED Feb 8, 2026.** IAM user `callsaver-ses-smtp` created (AKIA4FOROB4GLXDUNN45) with SES access. SMTP credentials stored in Secrets Manager under `docuseal/*` namespace | ✅ |
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
| 4.1 | **MSA / Privacy Policy / TOS Review** | One round of review on existing Master Service Agreement, Privacy Policy, and Terms of Service before launch. **Decision: Use DBA "CallSaver" for all customer-facing documents** (MSA, Privacy Policy, TOS, DocuSeal countersignature). Include a legal entity disclosure paragraph in the MSA: *"CallSaver" is a trade name of [Wyoming LLC Name], a Wyoming limited liability company.* Use the Wyoming LLC name only for banking, tax, and government filings | ☐ |
| 4.2 | **Sentry Error Tracking** | Reactivate Sentry subscription (trial expired); verify error tracking is operational for `callsaver-api` and `callsaver-web-ui` | ☐ |
| 4.3 | **API Key Rotation** | Rotate all API keys across services (new AWS account invalidates all AWS keys); audit every service referencing old keys and update env vars across Secrets Manager, GitHub Actions secrets, and local `.env` files | ☐ |
| 4.4 | **CI/CD Pipeline Review** | Evaluate moving from local deploys to: Vercel branch deploys for `callsaver-landing`, GitHub Actions/workflow deploys for `callsaver-api` and `callsaver-web-ui`; set up staging → production promotion. Update `deploy-staging.yml` with new account role ARN. Regenerate Cosign keys for image signing. **⚠️ Verify `deploy-prod.yml` exists** in `callsaver-api/.github/workflows/` — the Deployment Scripts section references it but only `ci.yml`, `deploy-staging.yml`, and `publish-and-update-ui.yml` were found. If it doesn't exist, create it based on `deploy-staging.yml` with production role ARN, production ECR repo, and manual approval gate | ☐ |
| 4.5 | **Fix Staging Web UI Build Vars** | `deploy-web-ui-staging.yml` does **NOT** inject `VITE_*` environment variables during the build step — unlike `deploy-web-ui-production.yml` which passes `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY`, `VITE_STRIPE_PUBLISHABLE_KEY`, `VITE_GOOGLE_MAPS_API_KEY`, `VITE_SENTRY_DSN`, `VITE_API_URL`, `VITE_APP_ENV`. Without these, the staging frontend builds with **undefined** client-side config → broken auth, no maps, no error tracking. Fix: add the same `VITE_*` env block to the staging workflow's build step, using staging-specific values (`VITE_APP_ENV=staging`, `VITE_API_URL=https://staging.api.callsaver.ai`, etc.) | ✅ |
| 4.6 | **Environment Separation Verification** | Verify distinct staging/production configs: separate databases, env vars, Vercel preview vs production, webhook endpoints. *Note: most of this is already covered by tasks 1.13 (production CDK stacks), 1.16-1.17 (separate secrets), 1.20 (separate Supabase), Section G (staging vs production differences). This task is a final verification pass to confirm nothing was missed* | ☐ |
| 4.7 | **Landing Page Copy Review** | Pre-launch review of messaging, positioning, and CTAs on callsaver.ai | ☐ |
| 4.7a | **Screen Recording Tool Evaluation** | Evaluate screen recording tools for dashboard video: Focusee, Cap.so, Poindeo. | ☐ |
| 4.7b | **Update Logo Font (License Issue)** | Old logo used Avenir Next (commercial license). Recreated in Inkscape with **Figtree** font (OFL). Simplified to 2 variants × 3 formats: `black-logo.{svg,png,webp}` + `white-logo.{svg,png,webp}`. All Sandbox template logos deleted. Replaced across landing page (6 files), frontend (7 files), API (3 files). Updated `generate-msa-pdf.ts` to use Inter/Figtree. Added font comparison widget to both repos. Removed Avenir Next from frontend. **Still pending:** Upload logo to Stripe, DocuSeal, business cards. Make body font decision (Inter vs Figtree). | ✅ |
| 4.8 | **Help Center / Documentation** | Set up customer-facing help center and product documentation | ☐ |
| 4.9 | **Status Page** | Set up public status page (e.g., BetterUptime, Instatus) for customer trust | ☐ |
| 4.10 | **Social Proof** | Get testimonial from Travis (electrician) for landing page | ☐ |
| 4.11 | **Upload DocuSeal MSA Template** | After DocuSeal redeploy (1.10), upload the MSA template to the new instance. Template must match your LLC/DBA name (same decision as 4.1). Code in `server.ts` dynamically fetches latest template from DocuSeal API. Verify DocuSeal API key and webhook secret are set in Secrets Manager | ☐ |
| 4.12 | **Remove Azhar Code References** | **5 hardcoded `azhar@callsaver.ai` references** that must be changed before launch: (1) `server.ts:15300-15301` — DocuSeal MSA countersignature email/name → `alex@callsaver.ai` / `Alex`, (2) `server.ts:15783` — DocuSeal webhook countersigner check → `alex@callsaver.ai`, (3) `server.ts:15140` — Cal.com link `azharhuda/demo` → your Cal.com username, (4) `provision-handler.ts:320` — TODO comment referencing azhar, (5) `admin-auth.ts:5` — remove `azhar@callsaver.ai` from admin allowlist | ✅ |
| 4.13 | **CloudWatch Alarms** | Set up CloudWatch alarms for: API ALB 5xx error rate, ECS task health (unhealthy count > 0), ECS CPU/memory utilization > 80%, ALB target response time > 5s. Configure SNS topic to email `alex@callsaver.ai` for alerts. **Also add alarms for Agent service** (CPU/memory, task health) | ☐ |
| 4.14 | **Generate VAPID Keys for Web Push** | Generate VAPID key pair (`npx web-push generate-vapid-keys`). Add `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` (`mailto:notifications@callsaver.ai`) to Secrets Manager (staging + production). Add to CDK SecretsNamespace. Frontend needs `VAPID_PUBLIC_KEY` for service worker registration. Without this, callback request push notifications silently fail | ✅ |
| 4.15 | **Migrate Google Place Details Cron to BullMQ** | `server.ts:17158` uses `node-cron` for daily Google Place Details sync (2 AM UTC). The other 2 scheduled jobs (usage reporting, weekly summary) already use BullMQ repeatable jobs. Migrate this last cron job to BullMQ for: (a) multi-instance safety (cron fires on every ECS task, BullMQ deduplicates), (b) restart resilience, (c) consistency with existing pattern. Remove `node-cron` dependency after migration | ✅ |
| 4.16 | **CORS: Add Production Origin** | `server.ts:344` hardcodes CORS `allowedOrigins` to only include `staging.app.callsaver.ai` + `APP_URL` + localhost. **Missing `https://app.callsaver.ai`** — production frontend will get CORS errors. Fix: add `https://app.callsaver.ai` to the allowlist, or better, derive allowed origins dynamically from `APP_URL` env var | ✅ |
| 4.17 | **Fix Placeholder Analytics IDs** | `callsaver-landing/.env.local` has placeholder values: `NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX` and `NEXT_PUBLIC_HOTJAR_ID=XXXXXXXXX`. Get real measurement IDs from GA4 and Hotjar dashboards, or remove Hotjar if ContentSquare is sufficient. **Done:** GA4 set to `G-KK8JGZCWBZ`, Hotjar removed (ContentSquare `6a46e9a377709` covers heatmaps/recordings) | ✅ |
| 4.18 | **Remove SendGrid Dead Code** | SendGrid (`@sendgrid/mail`) is confirmed dead code. Remove `SENDGRID_API_KEY`, `SENDGRID_FROM_EMAIL`, `SENDGRID_FROM_NAME` from `.env` and `config/loader.ts`. Remove `@sendgrid/mail` from `package.json`. Clean up any remaining import references | ✅ |
| 4.19 | **Verify S3 Data Availability** | ✅ **Data verified and recovered from git history.** Local backups at `~/callsaver-web-ui/s3-backup/`: (1) **50 cities/counties JSON files** in `s3-backup/cities-counties/` — upload to `callsaver-cities-counties` S3 bucket after CDK creates it (task 1.15). (2) **9 voice sample WAV files** (Blake, Brooke, Caroline, Emma, Katie, Lindsey, Ray, Ronald, Tessa) in `s3-backup/voice-samples/` — upload to `callsaver-voice-samples` S3 bucket. Use `scripts/upload-default-voice-samples.ts` or `aws s3 sync` to upload | ✅ |
| 4.20 | **Upgrade Supabase Production to Pro** | **Do this right before launch to avoid unnecessary cost.** Upgrade the production Supabase organization to Pro ($25/mo). This unlocks: daily backups with PITR, no 7-day pause risk, 8 GB database (vs 500 MB), 100 GB storage, email support. Then enable custom domain `auth.callsaver.ai` on the production project (Pro required). Add CNAME record to Route 53 (already in DNS checklist). Update `VITE_SUPABASE_URL` / `VITE_AUTH_REDIRECT_URL` in production GitHub Actions secrets to use `https://auth.callsaver.ai`. **Staging stays on Free** — pausing and lack of backups don't matter for dev/test | ☐ |
| 4.21 | **Set Up Upstash Redis for Production** | Create an Upstash Redis database for production (free tier: 500K commands/month, 256 MB — covers launch volume). **Why:** The ECS Redis sidecar is ephemeral and not shared across tasks. When auto-scaling kicks in (1→2 tasks), BullMQ repeatable jobs (usage reporting, weekly summary emails) fire on EVERY task → duplicate emails and Stripe usage reports. Upstash provides a shared, persistent Redis that BullMQ can use for job deduplication. **Steps:** (1) Create free Upstash Redis DB at [console.upstash.com](https://console.upstash.com), region: `us-west-1`. (2) Copy the Redis URL (`rediss://...`). (3) Set `REDIS_URL` in production Secrets Manager to the Upstash URL. (4) Update production CDK to remove the Redis sidecar container from the backend task definition (or just leave it unused — the `REDIS_URL` env var will override localhost). **Staging keeps the sidecar** (`redis://localhost:6379`) — duplication doesn't matter in dev. **Done:** Created `callsaver-production` database in us-west-1. Redis URL: `rediss://default:AcaZAAIncDI2Mzg2ZWZhYmYwY2I0Y2I5OTU1NmZjNDA1YWMyYmFiOHAyNTA4NDE@noted-hookworm-50841.upstash.io:6379` | ✅ |

---

## Quick Reference: Key Accounts & Services

| Service | Account/Entity | Notes |
|---------|----------------|-------|
| LLC | Prosimian Labs LLC (Wyoming) DBA CallSaver | ✅ Formed Feb 10. OA signed, EIN obtained. CA LLC-5 submitted. DBA pending CA LLC-12. |
| Domain | Namecheap (`callsaver.ai`) | Transfer from Azhar required (Phase 0.1) |
| AWS | Route 53, SES, ECS/Fargate, ECR, S3, Secrets Manager, ACM, CloudWatch (new account) | New account via mom's email; old account suspended |
| Database | Supabase (Postgres) | External — not on AWS. `DATABASE_URL` in Secrets Manager |
| Vercel | Landing page hosting (`callsaver-landing`) | ✅ Bill paid, deployed with Stripe compliance (Feb 10) |
| Analytics | ContentSquare, GA4, GrowthBook | Health check required; no DNS needed |
| Scheduling | Cal.com (Cloud) | Custom domain `book.callsaver.ai` + GA4 integration + Attio webhook |
| Mail/Office | Northwest Registered Agent | WY (done) + CA (pending) |
| Banking | Mercury | ✅ Application submitted Feb 10, awaiting approval |
| Payments | Stripe | ✅ Account live Feb 10 for Prosimian Labs LLC. Support addr: Sacramento RA |
| Email (Primary) | Google Workspace (`alex@callsaver.ai`) | DKIM export needed; bill due ~March 5, 2026 |
| Email (Transactional) | AWS SES (fallback: Resend) | 4 sender addresses: `support@`, `billing@`, `alex@`, `reports@` |
| Email (Cold Outbound) | Instantly.ai (`alex@trycallsaver.com`) | Already warming up (3 days in, 14-day warm-up) |
| CRM | Attio | Migrate or create new account (Azhar is primary) |
| Error Tracking | Sentry | Trial expired - reactivate |
| Support | Intercom | Custom domain `help.callsaver.ai`; verify subscription active |
| Auth | Supabase | Custom domain `auth.callsaver.ai` (Pro plan required) |
| CI/CD | GitHub Actions + Vercel | `callsaver-api`, `callsaver-web-ui`, `callsaver-landing` |
| DocuSeal | `forms.callsaver.ai` | E-signature service; redeploy in us-west-1 on new AWS |
| LiveKit | `wss://callsaver-d8dm5v36.livekit.cloud` | Voice AI agent connection (cloud, no custom domain) |
| Twilio | Voice telephony | **Delinquent (-$22)**, currently mocked. `SKIP_TWILIO_PURCHASE=true` in env. Pay balance before launch |
| Google Cloud | GCP (Gemini, Places, Geocoding, Weather, PageSpeed, Maps, GBP, Routes) | ⚠️ Possibly delinquent under `alex@callsaver.ai`. Fallback: `scrumptiouslemur@gmail.com`. See `external-services-inventory.md` |
| Upstash | Redis (managed) | **Production:** Upstash Redis (shared, persistent, free tier). **Staging:** ECS sidecar (localhost:6379, ephemeral) |
| Print | Moo.com | Business cards + flyers |

---

## Dependency Chain

```
Phase 0 (Offboarding)             Phase 1 (Tech)
──────────────────                ──────────────
0.1 Domain Transfer ─────────▶ 1.4 Update Nameservers
0.2 Remove Azhar (GWS) ──────── (after 1.2 DKIM export)
0.3 Azhar Close AWS ──────────── (independent, no blocker)
0.4 Pay GWS Bill ────────────── (deadline: ~March 5, 2026)

Phase 1 (Tech) — Code prereqs before CDK deploy
────────────────────────────────────────────────
1.18 Update CDK SecretsNamespace ──┐
1.23 Remove Hardcoded Old Refs ────┼──▶ 1.11 Staging API (CDK deploy)
1.24 Remove Better Auth ───────────┘         │
                                             ├──▶ 1.22 Staging Validation Checkpoint
                                             │         └──▶ 1.13 Production API
                                             │                    └──▶ 1.14 Production Web UI
                                             └──▶ 1.12 Staging Web UI
                                                       └──▶ 1.14 Production Web UI

Phase 1 (Tech) — AWS infrastructure
────────────────────────────────────
1.1 New AWS Account ──┬──▶ 1.3 Route 53 ──▶ 1.4 Update NS (requires 0.1)
                      │
                      ├──▶ 1.10 DocuSeal Server
                      │
                      ├──▶ 1.15 S3 Buckets (CDK: Storage + SharedData stacks)
                      │
                      ├──▶ 1.16 Secrets (Staging) ──▶ 1.11 CDK Deploy
                      ├──▶ 1.17 Secrets (Production) ──▶ 1.13 CDK Deploy
                      │
                      ├──▶ 1.20 Supabase Production Instance
                      └──▶ 1.21 LiveKit Cloud S3 Credentials

1.2 Export DKIM ──▶ 1.3 Route 53 (include DKIM record)
                    └──▶ 0.2 Remove Azhar from GWS (safe after DKIM exported)

Phase 2 (Compliance)              Phase 3 (Sales/Finance)
────────────────────              ───────────────────────
2.1 Form LLC ──┐
2.2 File DBA ──┤
2.4 Get EIN ───┼──────────────▶ 3.1 Mercury & Stripe ──▶ 3.2 Stripe Prod Mode
2.6 CA Office ─┘                                          └──▶ 3.3 Stripe Webhooks

1.1 New AWS Account ──────────▶ 3.4 SES Domain Verification
                                3.5 SES Prod Request
                                     └──▶ (if rejected) Resend or SendGrid fallback

                                3.8 Attio Migration ──▶ 3.9–3.11
                                3.13 Twilio Reactivation ($22)

Phase 4 (Pre-Launch) — near launch
───────────────────────────────────
4.20 Supabase Pro Upgrade (right before launch)
4.21 Upstash Redis for Production
```

---

## Timeline Summary

- **Day 0 (Today):** Phase 0 + Phase 1 — Domain transfer, new AWS account, DNS recovery, get tech stack live
- **Day 1 (Monday):** Phase 2 — LLC formation, DBA, EIN, compliance filings
- **Week 1–2:** Phase 3 — Banking, Stripe, SES (+ Resend fallback), webhooks, Attio migration (blocked by Phase 2)
- **Week 2–3:** Phase 4 — Legal review, Sentry, CI/CD, copy review, help center, status page
- **Day 25 (~March 5):** Google Workspace payment deadline
- **Day 30:** 83(b) election deadline from OA signing
- **Day 14 (from today):** Instantly.ai warm-up complete for `alex@trycallsaver.com`

---

## Appendix A: SES Production Request Draft

> Submit this via AWS Console → SES → Account Dashboard → "Request production access"

**Use case description (paste this):**

> We are CallSaver.ai, a B2B SaaS platform that provides AI voice agents for small/medium businesses (home services: HVAC, plumbing, electrical, etc.). We are requesting production access to send transactional emails only — no marketing or bulk email campaigns.
>
> **Email categories:**
> 1. **Transactional (account lifecycle):** Welcome emails, magic link sign-in, password reset, Stripe checkout links, docs invitations (~5–10/day initially)
> 2. **Billing notifications:** Payment receipts, payment failure dunning (3-stage, 30-day cycle), trial ending reminders, subscription confirmations (~2–5/day)
> 3. **Trial nurture sequence:** 4-email automated drip during 7-day free trial (getting started tips, feature highlights, annual savings offer, final trial reminder). Sent only to opted-in trial users (~1–3/day)
> 4. **Support notifications:** Ticket created/replied/resolved confirmations via Intercom webhook (~1–2/day)
>
> **Sending volume:** <50 emails/day initially, scaling to <500/day over 6 months.
>
> **Recipient management:** All recipients are authenticated users who signed up on our platform. We do not purchase lists. Unsubscribe links are included in all non-critical emails. Bounce and complaint handling via SES event notifications.
>
> **Sender addresses:** `support@callsaver.ai`, `billing@callsaver.ai`, `alex@callsaver.ai`, `reports@callsaver.ai`
>
> **Domain authentication:** DKIM, SPF, DMARC, and Custom MAIL FROM are fully configured.
>
> **Website:** https://callsaver.ai

**Expected approval time:** 24–48 hours. If rejected, proceed with Resend fallback.

### SES Fallback Plan

If AWS rejects the SES production request, choose **Option A (Resend)** or **Option B (SendGrid)**:

#### Option A: Resend (Recommended)

1. **Sign up for Resend** at https://resend.com (free tier: 3,000 emails/month, then $20/month)
2. **Verify domain** `callsaver.ai` in Resend dashboard (adds DKIM records — can coexist with SES DKIM)
3. **Update `email-adapter.ts`** — Replace `SESClient` with Resend SDK:
   ```typescript
   import { Resend } from 'resend';
   const resend = new Resend(process.env.RESEND_API_KEY);
   await resend.emails.send({
     from: options.from,
     to: options.to,
     subject: options.subject,
     html: options.html,
     text: options.text,
   });
   ```
4. **Add `RESEND_API_KEY`** to Secrets Manager (`callsaver/staging/backend/` and `callsaver/production/backend/`)
5. **No DNS changes needed** beyond Resend's DKIM records (additive, won't break existing)
6. **No template changes needed** — same sender addresses, same HTML/text bodies

> **Why Resend:** Modern developer-focused email API, excellent deliverability, simple SDK, transparent pricing. Founded by the creator of React Email. Supports all the same features as SES (DKIM, custom MAIL FROM, bounce tracking).

#### Option B: SendGrid (Already in codebase)

1. **Re-activate or create SendGrid account** — `@sendgrid/mail` is already a dependency in `package.json` (currently dead code, but the SDK is there)
2. **Verify domain** `callsaver.ai` in SendGrid → Settings → Sender Authentication (adds CNAME records for DKIM)
3. **Update `email-adapter.ts`** — Replace `SESClient` with SendGrid:
   ```typescript
   import sgMail from '@sendgrid/mail';
   sgMail.setApiKey(process.env.SENDGRID_API_KEY!);
   await sgMail.send({
     from: { email: options.from, name: options.fromName },
     to: options.to,
     subject: options.subject,
     html: options.html,
     text: options.text,
   });
   ```
4. **Add `SENDGRID_API_KEY`** to Secrets Manager. Update `SENDGRID_FROM_EMAIL` from `azhar@callsaver.ai` → `alex@callsaver.ai`
5. **Pros:** SDK already in `package.json`, mature platform, generous free tier (100 emails/day)
6. **Cons:** Owned by Twilio (another vendor dependency), heavier SDK, more complex dashboard

> **Recommendation:** Go with **Resend (Option A)** unless you have a specific reason to prefer SendGrid. If SES is approved, remove SendGrid dead code entirely (task 4.18).
