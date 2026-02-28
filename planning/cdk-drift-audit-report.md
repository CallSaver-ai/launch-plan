# CDK Infrastructure Drift Audit Report

**Date:** Feb 25, 2026  
**Scope:** Compare CDK stack definitions vs deployed AWS resources in staging, identify gaps for production deployment  
**Region:** us-west-1 | **Account:** 836347236108  
**AWS Services in use:** Secrets Manager, S3, ECS, EC2 (shared DocuSeal server), ECR, IAM

---

## Executive Summary

The staging infrastructure has significant drift from the CDK definitions due to ad-hoc changes made via deploy scripts. **13 secrets**, **4 env vars**, and **4 manual IAM policies** exist in the running ECS task definitions that are NOT in the CDK stacks. A production deployment from current CDK code would produce a **non-functional** backend — missing Pipedream, Firecrawl, VAPID, and other critical configuration.

**Critical items to fix before production deploy: 10**  
**Medium items: 5**  
**Low/cleanup: 5**

---

## 1. ECS Task Definition Drift (CRITICAL)

### 1a. Backend — Secrets in deployed rev 97 but NOT in CDK rev 1

The deploy script (`deploy-staging-local.sh`) bases its task definition on CDK revision 1, then layers additional secrets/env vars on top. CDK has never been re-deployed after many of these were added to the code.

**Secrets truly missing from CDK code (not in config.ts or backend-service-stack.ts):**

| Secret | Used By | Notes |
|---|---|---|
| `CAL_WEBHOOK_SECRET` | `config/loader.ts` | Optional in loader but required at runtime |
| `FIRECRAWL_API_KEY` | `config/runtime.ts` | Required for website extraction |
| `FIRECRAWL_WEBHOOK_SECRET` | `config/runtime.ts` | Required for webhook verification |
| `PIPEDREAM_CLIENT_ID` | `lib/pipedream-client.ts` | Required for OAuth integrations (Jobber, GCal) |
| `PIPEDREAM_CLIENT_SECRET` | `lib/pipedream-client.ts` | Required for OAuth integrations |
| `PIPEDREAM_PROJECT_ID` | `lib/pipedream-client.ts` | Required for OAuth integrations |
| `PIPEDREAM_ENVIRONMENT` | `lib/pipedream-client.ts` | Required for OAuth integrations |
| `PIPEDREAM_OAUTH_APP_ID_JOBBER` | `server.ts` (connect flow) | Required for Jobber OAuth |
| `PIPEDREAM_OAUTH_APP_ID_GOOGLE_CALENDAR` | `server.ts` (connect flow) | Required for GCal OAuth |

**Secrets in CDK code but never deployed** (CDK was never re-applied after adding them):
LIVEKIT_SIP_ENDPOINT, LIVEKIT_WORKER_NAME, LIVEKIT_OUTBOUND_TRUNK_ID, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT, RENTCAST_API_KEY — all exist in `config.ts` and `backend-service-stack.ts` but the CDK base revision 1 predates them.

**Action:** Add all 9 missing secrets to `config.ts` + `backend-service-stack.ts`, then re-deploy CDK.

### 1b. Backend — Env vars in deployed but NOT in CDK

| Env Var | Value (staging) | Action |
|---|---|---|
| `REDIS_URL` | `redis://localhost:6379` | Staging overrides SM secret to use sidecar. CDK already has it as SM secret — this is fine for staging sidecar mode. |
| `WEBSITE_EXTRACTION_PROVIDER` | `firecrawl` | Add to CDK as plain env var |
| `SKIP_TWILIO_PURCHASE` | `false` | Staging-only. Do NOT add to production CDK. |
| `REUSE_TWILIO_NUMBER` | `+16198534869` | Staging-only. Do NOT add to production CDK. |

**Crawl4AI env vars** (`CRAWL4AI_ENDPOINT`, `CRAWL4AI_WEBHOOK_URL`, `CRAWL4AI_WEBHOOK_SECRET`) — these are **no longer needed**. Crawl4AI is not running on AWS; Firecrawl (cloud-managed) is the only extraction provider. These should be **removed from the deploy script** rather than added to CDK.

### 1c. Backend — Secrets in CDK code but NOT in deployed rev 97

| Secret | CDK Has | Deployed Has | Impact |
|---|---|---|---|
| `VAPID_PUBLIC_KEY` | ✅ | ❌ | Push notifications broken |
| `VAPID_PRIVATE_KEY` | ✅ | ❌ | Push notifications broken |
| `VAPID_SUBJECT` | ✅ | ❌ | Push notifications broken |

**Action:** Add VAPID to the deploy script immediately (short-term) AND re-deploy CDK (long-term).

### 1d. Agent — INTERNAL_API_KEY path mismatch (CRITICAL)

- **CDK `agent-service-stack.ts`** maps `INTERNAL_API_KEY` → `secrets.provisionApiKey` → `callsaver/{env}/backend/PROVISION_API_KEY`
- **Deployed task def** correctly maps `INTERNAL_API_KEY` → `callsaver/staging/backend/INTERNAL_API_KEY`
- **The two secrets have DIFFERENT VALUES:** `5a143e19...` (PROVISION) vs `ef0f9e95...` (INTERNAL)

If CDK deploys production fresh, the agent would get the PROVISION_API_KEY value and all agent→API calls would fail with 401.

**Action:** Fix `agent-service-stack.ts` line 133: change `secrets.provisionApiKey` → `secrets.internalApiKey`.

---

## 2. Secrets Manager — Full Audit

### 2a. Current SM secrets inventory

**Staging backend (31 secrets in SM):**
All `callsaver/staging/backend/*` — fully populated and working.

**Staging agent (8 secrets in SM):**
All `callsaver/staging/agent/*` — fully populated and working.

**Production backend (13 secrets exist in SM):**
- DOCUSEAL_API_KEY, DOCUSEAL_API_URL, DOCUSEAL_WEBHOOK_SECRET ✅ (correct production values)
- STRIPE_SECRET_KEY ✅ (has live key `sk_live_51SCAlJ...`, .env.production still has test key — **stale .env.production**)
- RENTCAST_API_KEY ✅ (same key as staging)
- PIPEDREAM_CLIENT_ID, CLIENT_SECRET, PROJECT_ID, OAUTH_APP_IDs ✅ (same as staging, correct)
- STRIPE_CANCEL_URL, STRIPE_PUBLISHABLE_KEY, STRIPE_SUCCESS_URL ❌ **Orphaned** — deleted from code

**Production agent (0 secrets exist):** ALL MISSING

**Shared (3 secrets):**
- `callsaver/shared/crawl4ai/OPENAI_API_KEY` — **can be deleted** (Crawl4AI no longer running on AWS)
- `callsaver/shared/docuseal/SES_SMTP_PASSWORD` — used by DocuSeal EC2 server (shared staging+prod)
- `callsaver/shared/docuseal/SES_SMTP_USERNAME` — used by DocuSeal EC2 server (shared staging+prod)

### 2b. Secrets that MUST be created for production

**41 missing production secrets** (down from 54 after accounting for shared keys):

**Backend secrets needed (`callsaver/production/backend/`):**
- `DATABASE_URL`, `DIRECT_URL` — **MUST be different** (production Supabase project)
- `REDIS_URL` — **MUST be different** (production Upstash instance, or own Redis)
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` — **MUST be different** (production Supabase)
- `STRIPE_WEBHOOK_SECRET` — **MUST be different** (production webhook endpoint)
- `STRIPE_METER_ID` — **MUST be different** (production Stripe account 51SCAlJ)
- `STRIPE_PRICE_IMPLEMENTATION_FEE` — **MUST be different** (production prices)
- `STRIPE_PRICE_USAGE_STANDARD` — **MUST be different** (production prices)
- `STRIPE_PRICE_USAGE_ENTERPRISE` — **MUST be different** (production prices)
- `SENTRY_DSN` — **SHOULD be different** (production Sentry project for clean separation)
- `SENTRY_ENVIRONMENT` — value: `production`
- `NODE_ENV` — value: `production`
- `APP_ENV` — value: `production`
- `SESSION_S3_BUCKET` — value: `callsaver-sessions-production`
- `CAL_WEBHOOK_SECRET` — **MUST be different** (different Cal.com webhook endpoint)
- `LIVEKIT_API_KEY` — see LiveKit section below
- `LIVEKIT_API_SECRET` — already different in .env.production
- `LIVEKIT_SIP_ENDPOINT` — already different in .env.production
- `LIVEKIT_WORKER_NAME` — already different in .env.production
- `LIVEKIT_URL` — TBD (same or different LiveKit project)
- `LIVEKIT_OUTBOUND_TRUNK_ID` — TBD
- `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` — can share (same app identity)
- All others that can share staging values (see section 2c)

**Agent secrets needed (`callsaver/production/agent/`):**
All 8 agent secrets — see section 2c for share vs separate.

### 2c. Staging vs Production — Share or Separate?

Based on comparing `.env`, `.env.staging`, and `.env.production`:

| Secret | Recommendation | Reason |
|---|---|---|
| **MUST be separate (different values):** | | |
| `DATABASE_URL` / `DIRECT_URL` | **SEPARATE** | Different databases! Production needs its own Supabase project. |
| `SUPABASE_URL` / `ANON_KEY` / `SERVICE_ROLE_KEY` | **SEPARATE** | Different Supabase project. Currently .env.production has NO Supabase entries. |
| `REDIS_URL` | **SEPARATE** | Production needs its own Redis (Upstash or similar). |
| `STRIPE_SECRET_KEY` | **SEPARATE** | SM already has `sk_live_51SCAlJ...`. (.env.production has stale test key — update it!) |
| `STRIPE_WEBHOOK_SECRET` | **SEPARATE** | Different webhook endpoint URL. |
| `STRIPE_METER_ID` | **SEPARATE** | Production Stripe account has different meter/price IDs. |
| `STRIPE_PRICE_*` (3 prices) | **SEPARATE** | Production Stripe account has different price IDs. |
| `DOCUSEAL_API_KEY` | **SEPARATE** | Already different — SM has production key. |
| `DOCUSEAL_WEBHOOK_SECRET` | **SEPARATE** | Already different — SM has production secret. |
| `SENTRY_DSN` / `SENTRY_ENVIRONMENT` | **SEPARATE** | Recommend separate Sentry project for clean error triage. |
| `NODE_ENV` / `APP_ENV` | **SEPARATE** | `production` vs `staging`. |
| `SESSION_S3_BUCKET` | **SEPARATE** | `callsaver-sessions-production` vs `callsaver-sessions-staging`. |
| `LIVEKIT_API_SECRET` | **SEPARATE** | Already different in .env.production. |
| `LIVEKIT_SIP_ENDPOINT` | **SEPARATE** | Already different in .env.production (`.pstn.` vs `.sip.`). |
| `LIVEKIT_WORKER_NAME` | **SEPARATE** | Already different in .env.production (has location ID suffix). |
| `CAL_WEBHOOK_SECRET` | **SEPARATE** | Different Cal.com webhook endpoint. |
| `E2E_TEST_SECRET` | **SEPARATE** | Different test credentials per env. |
| | | |
| **Can share (same value for both):** | | |
| `ATTIO_API_KEY` | **SHARE** | Same Attio workspace. .env.staging and .env.production have different keys but consider using one. |
| `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` | **SHARE** | Same Twilio account. |
| `NANGO_SECRET_KEY` | **SHARE** | Same Nango account (being migrated to Pipedream). |
| `PIPEDREAM_CLIENT_ID` / `CLIENT_SECRET` | **SHARE** | Same Pipedream project. |
| `PIPEDREAM_PROJECT_ID` | **SHARE** | Same project `proj_BgsRyvp`. |
| `PIPEDREAM_OAUTH_APP_ID_*` | **SHARE** | Same OAuth apps. |
| `OPENAI_API_KEY` | **SHARE** | Same OpenAI account. Same key in both .env files. |
| `GOOGLE_API_KEY` | **SHARE** | Same Google Cloud project. |
| `INTERCOM_ACCESS_TOKEN` / `CLIENT_SECRET` | **SHARE** | Same Intercom workspace. |
| `DEEPGRAM_API_KEY` | **SHARE** | Same Deepgram account. |
| `CARTESIA_API_KEY` | **SHARE** | Same Cartesia account. |
| `ASSEMBLYAI_API_KEY` | **SHARE** | Same AssemblyAI account. |
| `ANTHROPIC_API_KEY` | **SHARE** | Same Anthropic account. |
| `INTERNAL_API_KEY` / `PROVISION_API_KEY` | **SHARE** | Same keys. Internal auth — no isolation benefit. |
| `DOCUSEAL_API_URL` | **SHARE** | `https://forms.callsaver.ai` — shared DocuSeal server. |
| `BUSINESS_PROFILES_S3_BUCKET` | **SHARE** | `callsaver-business-profiles` — shared bucket. |
| `RENTCAST_API_KEY` | **SHARE** | Same RentCast account. |
| `FIRECRAWL_API_KEY` / `WEBHOOK_SECRET` | **SHARE** | Same Firecrawl account. |
| `DOCS_PASSWORD` | **SHARE** | Same docs password. |
| `QR_IP_HASH_SECRET` | **SHARE** | Same hashing. |
| `VAPID_PUBLIC_KEY` / `PRIVATE_KEY` / `SUBJECT` | **SHARE** | Same web push identity. |
| `SES_CONFIGURATION_SET` / `SES_FROM_EMAIL` | **SHARE** | Same SES domain. |
| | | |
| **Recommend separating (currently same but SHOULD separate):** | | |
| `OPENAI_API_KEY` | **CONSIDER SEPARATE** | For cost tracking and rate limit isolation. Create separate service account. |
| `DEEPGRAM_API_KEY` | **CONSIDER SEPARATE** | Same reason — voice AI usage is the primary cost driver. |
| `ATTIO_API_KEY` | **CONSIDER SEPARATE** | If staging test data shouldn't pollute production CRM. .env files already have different keys. |
| `PIPEDREAM_ENVIRONMENT` | **SEPARATE** | `.env.staging` has `production`, `.env` has `development`. Production should use `production`. This controls Pipedream's environment scoping for OAuth tokens. Staging may want `development` to avoid cross-pollination. |

### 2d. .env.production issues found

1. **`STRIPE_SECRET_KEY`** — .env.production has `sk_test_51SBSjO...` (sandbox/test key). SM production has `sk_live_51SCAlJ...` (correct live key). **Update .env.production to match SM.**
2. **`LIVEKIT_URL`** — missing entirely from .env.production. Needs to be set.
3. **`LIVEKIT_API_KEY`** — missing entirely from .env.production. Needs to be set.
4. **`SUPABASE_*`** — all 3 missing from .env.production. Production Supabase project needs to be created.
5. **`REDIS_URL`** — commented out in .env.production. Production Redis needs to be provisioned.
6. **`SENTRY_DSN`** — missing from .env.production.
7. **`AWS_SESSION_BUCKET`** — .env.production says `callsaver-sessions-staging`. Should be `callsaver-sessions-production`.
8. **`CAL_WEBHOOK_SECRET`** — missing from .env.production.
9. **`STRIPE_WEBHOOK_SECRET`** — missing from .env.production (production webhook not created yet).
10. **All STRIPE_METER_ID, STRIPE_PRICE_* values** — missing from .env.production (production Stripe account prices not set up yet).

### 2e. Orphaned secrets to delete

| Secret | Status |
|---|---|
| `callsaver/production/backend/STRIPE_CANCEL_URL` | Orphaned — removed from code |
| `callsaver/production/backend/STRIPE_PUBLISHABLE_KEY` | Orphaned — frontend env, not backend |
| `callsaver/production/backend/STRIPE_SUCCESS_URL` | Orphaned — removed from code |
| `callsaver/shared/crawl4ai/OPENAI_API_KEY` | Crawl4AI no longer on AWS |

---

## 3. IAM Policy Drift

### 3a. Manual inline policies on Backend Execution Role

| Policy Name | CDK Managed? | Purpose | Action |
|---|---|---|---|
| `ExecutionRoleDefaultPolicyA5B92313` | ✅ CDK | SM access for CDK-defined secrets | Keep |
| `S3CompanyWebsiteExtractionsAccess` | ❌ Manual | References non-existent `callsaver-company-website-extractions` bucket | **DELETE** (stale) |
| `StagingBackendSecretsWildcard` | ❌ Manual | `callsaver/staging/backend/*` wildcard SM access | **Keep until CDK covers all secrets**, then delete |

`StagingBackendSecretsWildcard` is the reason the deploy script's extra secrets (Pipedream, Firecrawl, etc.) work at all. For production, either:
- **(Preferred)** Fix CDK to declare all secrets → CDK generates per-secret IAM grants → no wildcard needed
- **(Fallback)** Create matching `ProductionBackendSecretsWildcard` manually on the production execution role

### 3b. Manual inline policies on Backend Task Role

| Policy Name | CDK Managed? | Purpose | Action |
|---|---|---|---|
| `TaskRoleDefaultPolicy07FC53DE` | ✅ CDK | S3 (sessions + business-profiles) + SES | Keep |
| `S3CompanyWebsiteExtractionsAccess` | ❌ Manual | Grants access to `callsaver-business-profiles` (misnamed) | **DELETE** — CDK already grants this via `grantReadWrite` |
| `Crawl4AIOpenAIAccess` | ❌ Manual | SM access for `callsaver/shared/crawl4ai/OPENAI_API_KEY` | **DELETE** — Crawl4AI no longer on AWS |
| `Crawl4AISSMAccess` | ❌ Manual | SSM access for Crawl4AI endpoint parameter | **DELETE** — Crawl4AI no longer on AWS |

### 3c. Agent roles

Agent execution role and task role match CDK exactly. No manual policies added. ✅

### 3d. Missing IAM grants for shared S3 buckets

The CDK backend task role only grants S3 access to `callsaver-sessions-{env}` and `callsaver-business-profiles`. The code also needs:

| Bucket | Used By | Operation | CDK Grant? |
|---|---|---|---|
| `callsaver-ai-cities-counties` | `prompt-setup.ts` | GetObject | ❌ Missing |
| `callsaver-ai-voice-samples` | `generate-organization-voice-samples.ts` | PutObject, GetObject | ❌ Missing |
| `callsaver-ai-forms` | DocuSeal (shared server) | Read/Write | N/A — DocuSeal EC2 has its own IAM, not ECS |

Currently works because the `SecretsManagerReadWrite` managed policy is overly broad and the S3 calls may be hitting the `callsaver-business-profiles` grant. But this is fragile.

**Action:** Add to CDK backend task role:
- `grantRead` on `callsaver-ai-cities-counties`
- `grantReadWrite` on `callsaver-ai-voice-samples`

---

## 4. S3 Buckets

### 4a. CDK-managed buckets

| Bucket | Exists | Shared? | Used By |
|---|---|---|---|
| `callsaver-sessions-staging` | ✅ | Per-env | Call recordings (staging) |
| `callsaver-sessions-production` | ❌ **Not created** | Per-env | CDK will create on prod deploy |
| `callsaver-business-profiles` | ✅ | Shared | Business data, Google Place details |
| `callsaver-ai-forms` | ✅ | Shared | DocuSeal documents (staging + production) |
| `callsaver-ai-cities-counties` | ✅ | Shared | Cities/counties data for prompts |
| `callsaver-ai-voice-samples` | ✅ | Shared (public read) | Voice sample audio files |

**Note:** `callsaver-ai-forms` is correctly in the shared `StorageStack` with `manageSharedBusinessBucket` controlling creation. For production CDK deploy, set `manage_shared_bucket=false` to avoid trying to recreate shared buckets.

### 4b. Non-CDK / legacy buckets

| Bucket | Status | Action |
|---|---|---|
| `callsaver-frontend-staging` | Legacy — not in code or CDK | Can delete (verify unused first) |
| `callsaver-web-ui-staging-v2` | Legacy — not in code or CDK | Can delete (verify unused first) |

### 4c. LiveKit Egress IAM user

`callsaver-livekit-egress` IAM user (not CDK-managed) has S3 put access to both `callsaver-sessions-staging` and `callsaver-sessions-production`. The production bucket doesn't exist yet but the IAM policy already references it. This is fine — the policy will work once the bucket is created by CDK.

---

## 5. ECR Repository Drift

| CDK Repo Name | ECR Repo Exists | Deploy Script Uses | Issue |
|---|---|---|---|
| `callsaver-node-api` | ✅ | `callsaver-node-api` | ✅ Match |
| `callsaver-livekit-python` | ✅ | `callsaver-agent` | ⚠️ Mismatch |
| (none) | `callsaver-agent` exists | Created by deploy script fallback | Not CDK-managed, no lifecycle rules |

**Action:** Update deploy script `ECR_REPO_NAME` from `callsaver-agent` to `callsaver-livekit-python` to match CDK. Then delete the orphaned `callsaver-agent` ECR repo.

---

## 6. Security Groups / Networking

All match CDK definitions exactly. ✅

| SG | CDK Definition | Deployed | Match |
|---|---|---|---|
| ALB SG | TCP 80, 443 from 0.0.0.0/0 | Same | ✅ |
| Service SG | TCP 8080 from ALB SG | Same | ✅ |
| Crawl4AI SG | TCP 11235 from VPC CIDR | Same | ✅ (can be deleted with Crawl4AI stack) |

**Note:** The Crawl4AI security group and Crawl4AI-Shared CloudFormation stack can be torn down since Crawl4AI is no longer running on AWS. This would free the NLB and ASG resources.

---

## 7. CloudFormation Stack Health

| Stack | Status | Issue |
|---|---|---|
| `Callsaver-Backend-staging` | `UPDATE_ROLLBACK_COMPLETE` | Last CDK deploy failed |
| `Callsaver-Network-staging` | `UPDATE_ROLLBACK_COMPLETE` | Last CDK deploy failed |
| `Callsaver-Agent-staging` | `CREATE_COMPLETE` | ✅ |
| `Callsaver-Storage-staging` | `UPDATE_COMPLETE` | ✅ |
| `Callsaver-Shared` | `CREATE_COMPLETE` | ✅ |
| `Crawl4AI-Shared` | `UPDATE_COMPLETE` | ✅ (can be deleted) |
| `Callsaver-DNS` | `UPDATE_COMPLETE` | ✅ |

**CRITICAL:** Backend and Network stacks are in `UPDATE_ROLLBACK_COMPLETE`. The stacks are still functional (running the pre-rollback config) but CDK will need to successfully update them before you can trust CDK for production. Fix CDK code first, then deploy to staging to validate.

---

## 8. Remediation Plan

### Phase 1: Fix CDK code (1-2 hours)

1. **Add 9 missing secrets** to `config.ts` SecretsNamespace + `backend-service-stack.ts`:
   - `calWebhookSecret`, `firecrawlApiKey`, `firecrawlWebhookSecret`
   - `pipedreamClientId`, `pipedreamClientSecret`, `pipedreamProjectId`, `pipedreamEnvironment`
   - `pipedreamOauthAppIdJobber`, `pipedreamOauthAppIdGoogleCalendar`

2. **Add `WEBSITE_EXTRACTION_PROVIDER`** as plain env var in `backend-service-stack.ts` (`firecrawl`)

3. **Fix agent `INTERNAL_API_KEY` path** in `agent-service-stack.ts` line 133:
   `secrets.provisionApiKey` → `secrets.internalApiKey`

4. **Remove Crawl4AI env vars** from `deploy-staging-local.sh` (CRAWL4AI_ENDPOINT, CRAWL4AI_WEBHOOK_URL, CRAWL4AI_WEBHOOK_SECRET)

5. **Add shared bucket IAM grants** in `backend-service-stack.ts`:
   - Import `callsaver-ai-cities-counties` bucket by name → `grantRead(taskRole)`
   - Import `callsaver-ai-voice-samples` bucket by name → `grantReadWrite(taskRole)`

### Phase 2: Deploy CDK to staging (validate)

6. **Deploy CDK to staging** with all fixes. Verify task definition has all secrets.
7. **Delete stale IAM policies:**
   - `S3CompanyWebsiteExtractionsAccess` (both execution + task roles)
   - `Crawl4AIOpenAIAccess` (task role)
   - `Crawl4AISSMAccess` (task role)
8. **Test VAPID** push notifications work with the CDK-deployed task def.

### Phase 3: Prepare production secrets (1-2 hours)

9. **Create production SM secrets** — 41 secrets needed. For the ~25 that share staging values, can script the copy:
   ```bash
   # Script: copy shared secrets from staging to production
   for secret in ATTIO_API_KEY TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN NANGO_SECRET_KEY \
     PIPEDREAM_CLIENT_ID PIPEDREAM_CLIENT_SECRET PIPEDREAM_PROJECT_ID \
     OPENAI_API_KEY GOOGLE_API_KEY INTERCOM_ACCESS_TOKEN INTERCOM_CLIENT_SECRET \
     DEEPGRAM_API_KEY CARTESIA_API_KEY ASSEMBLYAI_API_KEY ANTHROPIC_API_KEY \
     INTERNAL_API_KEY PROVISION_API_KEY BUSINESS_PROFILES_S3_BUCKET \
     RENTCAST_API_KEY FIRECRAWL_API_KEY FIRECRAWL_WEBHOOK_SECRET \
     DOCS_PASSWORD QR_IP_HASH_SECRET VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY VAPID_SUBJECT \
     SES_CONFIGURATION_SET SES_FROM_EMAIL DOCUSEAL_API_URL; do
     val=$(aws secretsmanager get-secret-value --secret-id "callsaver/staging/backend/$secret" \
       --region us-west-1 --query SecretString --output text)
     aws secretsmanager create-secret --name "callsaver/production/backend/$secret" \
       --secret-string "$val" --region us-west-1
   done
   ```

10. **Manually create production-specific secrets** (values differ from staging):
    - `DATABASE_URL`, `DIRECT_URL` — new production Supabase project
    - `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` — new production Supabase
    - `REDIS_URL` — new Upstash instance
    - `STRIPE_WEBHOOK_SECRET` — create webhook in live Stripe dashboard
    - `STRIPE_METER_ID`, `STRIPE_PRICE_*` — create in live Stripe account
    - `SENTRY_DSN`, `SENTRY_ENVIRONMENT` — create production Sentry project (or reuse with `production` env tag)
    - `NODE_ENV`=`production`, `APP_ENV`=`production`
    - `SESSION_S3_BUCKET`=`callsaver-sessions-production`
    - `LIVEKIT_URL`, `LIVEKIT_API_KEY` — from LiveKit project (determine if same project or new)
    - `LIVEKIT_API_SECRET`, `LIVEKIT_SIP_ENDPOINT`, `LIVEKIT_WORKER_NAME` — already different in .env.production
    - `LIVEKIT_OUTBOUND_TRUNK_ID` — TBD
    - `CAL_WEBHOOK_SECRET` — new webhook secret for production endpoint
    - `E2E_TEST_SECRET` — new production test secret

11. **Create production agent secrets** (`callsaver/production/agent/*`):
    Copy all 8 from staging (same API keys for OpenAI, Deepgram, Cartesia, AssemblyAI, Anthropic, Google). Egress AWS creds are same IAM user.

12. **Delete orphaned secrets:**
    - `callsaver/production/backend/STRIPE_CANCEL_URL`
    - `callsaver/production/backend/STRIPE_PUBLISHABLE_KEY`
    - `callsaver/production/backend/STRIPE_SUCCESS_URL`
    - `callsaver/shared/crawl4ai/OPENAI_API_KEY`

13. **Fix `.env.production`:**
    - Update `STRIPE_SECRET_KEY` to live key
    - Add missing entries (SUPABASE_*, REDIS_URL, SENTRY_DSN, LIVEKIT_URL, LIVEKIT_API_KEY, etc.)
    - Fix `AWS_SESSION_BUCKET` from `callsaver-sessions-staging` → `callsaver-sessions-production`

### Phase 4: Production deploy

14. **Deploy CDK for production:** `cdk deploy -c env=production -c manage_shared_bucket=false -c production.certificateArn=...`
15. **Align ECR repo naming:** Update agent deploy script to use `callsaver-livekit-python`
16. **(Optional) Tear down Crawl4AI stack:** `cdk destroy Crawl4AI-Shared`

---

## 9. Non-CDK Managed Resources

| Resource | Type | Purpose | Action |
|---|---|---|---|
| `callsaver-livekit-egress` IAM user | IAM User | S3 egress for LiveKit recordings | Keep — already has production bucket policy |
| `StagingBackendSecretsWildcard` | IAM Inline Policy | Wildcard SM access for staging execution role | Remove after CDK covers all secrets |
| `S3CompanyWebsiteExtractionsAccess` (x2) | IAM Inline Policy | Stale — wrong bucket name | **Delete** |
| `Crawl4AIOpenAIAccess` | IAM Inline Policy | Crawl4AI no longer on AWS | **Delete** |
| `Crawl4AISSMAccess` | IAM Inline Policy | Crawl4AI no longer on AWS | **Delete** |
| `callsaver-agent` ECR repo | ECR Repository | Used by deploy script (should use `callsaver-livekit-python`) | **Delete** after aligning deploy script |
| `callsaver-frontend-staging` S3 | S3 Bucket | Legacy frontend hosting | Verify unused, then delete |
| `callsaver-web-ui-staging-v2` S3 | S3 Bucket | Legacy frontend hosting | Verify unused, then delete |
| DocuSeal EC2 instance | EC2 | Shared DocuSeal server (staging + production) | Keep — shared across envs |
| `callsaver-ai-forms` S3 | S3 Bucket | DocuSeal documents (shared) | Keep — CDK-managed in StorageStack |

---

## 10. Production Infrastructure Decisions & Open Items

### 10a. Redis (Upstash) — Separate or Shared?

**Current staging:** Redis sidecar in ECS task (`redis://localhost:6379`), overriding the SM `REDIS_URL` which points to Upstash (`rediss://default:...@exact-finch-19822.upstash.io:6379`).

**Options for production:**
1. **Separate Upstash instance (recommended):** Create a new Upstash Redis database for production. ~$0-10/month on pay-per-use. Prevents staging BullMQ jobs from interfering with production queues.
2. **Reuse same Upstash:** Simpler, but staging and production share the same queue namespace. If a staging deploy corrupts queue state, production is affected. Mitigation: use queue name prefixes (`staging:*`, `production:*`).
3. **Redis sidecar in ECS (current staging pattern):** Zero cost but no persistence across deploys. If the task restarts, all pending BullMQ jobs are lost. Fine for staging, risky for production.

**Decision needed:** Separate Upstash instance vs reuse. If reusing, add environment prefixes to BullMQ queue names.

### 10b. Supabase — Must Be Separate

**Current staging:** `arjdfatbdpegoyefdqfo.supabase.co` (us-west-2 pooler)

**For production:** Create a new Supabase project. This gives you:
- Isolated database (no staging test data pollution)
- Separate auth users (staging test accounts won't exist in production)
- Independent connection pool limits
- Clean Prisma migration baseline

**Action items:**
1. Create new Supabase project (recommend us-west-2 for pooler, same as staging)
2. Run Prisma migrations against it
3. Create SM secrets: `DATABASE_URL`, `DIRECT_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
4. Update `.env.production` with new values

### 10c. Pipedream — Environment Mismatch Found

**Current state:**

| Source | `PIPEDREAM_ENVIRONMENT` value |
|---|---|
| SM secret (`callsaver/staging/backend/`) | `development` |
| `.env.staging` file | `production` |
| `.env.production` file | `production` |
| `.env` (local dev) | `development` |

The **deployed staging backend** uses the SM value = `development`. This means Pipedream OAuth tokens created in staging are scoped to Pipedream's `development` environment.

**Pipedream's environment model:** Pipedream Connect has two environments: `development` and `production`. OAuth tokens created in one environment are NOT accessible from the other. This means:
- If staging creates an OAuth connection (Jobber, GCal) in `development`, production (`production`) can't see it
- If you switch staging to `production`, both envs share the same OAuth token pool — a staging test disconnect could break production

**Recommended setup:**
- **Staging SM:** `development` (keep current — correct for isolation)
- **Production SM:** `production`
- **Fix `.env.staging`** to say `development` to match SM reality
- When onboarding real customers in production, their OAuth tokens are created in Pipedream's `production` environment and are isolated from staging test tokens

**Action:** Update `.env.staging` from `production` → `development` to match SM. Create `callsaver/production/backend/PIPEDREAM_ENVIRONMENT` = `production`.

### 10d. LiveKit — Same or Separate Project?

**Current state:**
- Staging: `callsaver-d8dm5v36.livekit.cloud` (API key: `APItoDBXQ7Tysvb`)
- .env.production has a different `LIVEKIT_API_SECRET` and `LIVEKIT_SIP_ENDPOINT` but is missing `LIVEKIT_URL` and `LIVEKIT_API_KEY`

**Trade-offs:**

| | Same Project | Separate Project |
|---|---|---|
| Cost | No extra base cost | Additional LiveKit project fee |
| SIP trunks | Shared — staging calls and production calls on same trunk | Isolated trunks |
| Egress | Shared egress capacity | Independent |
| Rooms | Same namespace (room names could collide) | Fully isolated |
| Monitoring | Mixed staging+production in LiveKit dashboard | Clean production-only metrics |

**If using same project:** The different `LIVEKIT_API_SECRET` in `.env.production` suggests a separate API key pair was already created within the same project. You'd still share the same `LIVEKIT_URL` but use separate API key/secret pairs.

**Decision needed:** TBD. If same project, set production `LIVEKIT_URL` = `wss://callsaver-d8dm5v36.livekit.cloud` and create a separate API key pair. If separate project, create new project in LiveKit Cloud.

---

## 11. Webhook Configuration for Production

All webhook endpoints that external services call need to be reconfigured from `staging.api.callsaver.ai` → `api.callsaver.ai`.

### 11a. Webhook endpoints inventory

| Service | Endpoint Path | Staging URL | Production URL | Config Location |
|---|---|---|---|---|
| **Stripe** | `/webhooks/stripe` | `https://staging.api.callsaver.ai/webhooks/stripe` | `https://api.callsaver.ai/webhooks/stripe` | Stripe Dashboard → Webhooks |
| **Cal.com** | `/webhooks/cal/booking-created` | `https://staging.api.callsaver.ai/webhooks/cal/booking-created` | `https://api.callsaver.ai/webhooks/cal/booking-created` | Cal.com → Settings → Webhooks |
| **Firecrawl** | `/webhooks/firecrawl` | `https://staging.api.callsaver.ai/webhooks/firecrawl` | `https://api.callsaver.ai/webhooks/firecrawl` | Sent in API call (automatic via `API_URL` env) |
| **DocuSeal** | `/webhooks/docuseal` | `https://staging.api.callsaver.ai/webhooks/docuseal` | `https://api.callsaver.ai/webhooks/docuseal` | DocuSeal server config (shared EC2) |
| **Intercom** | `/webhooks/intercom` | `https://staging.api.callsaver.ai/webhooks/intercom` | `https://api.callsaver.ai/webhooks/intercom` | Intercom Dashboard → Webhooks |

### 11b. Webhook secrets that need production values

| Secret | Status | Action |
|---|---|---|
| `STRIPE_WEBHOOK_SECRET` | ❌ Missing | Create production webhook in Stripe live dashboard, get signing secret |
| `CAL_WEBHOOK_SECRET` | ❌ Missing | Create production webhook in Cal.com, get secret |
| `DOCUSEAL_WEBHOOK_SECRET` | ✅ Already in SM | Production DocuSeal key already configured |
| `FIRECRAWL_WEBHOOK_SECRET` | ✅ Can share | Same Firecrawl account, same signing secret |
| `INTERCOM_CLIENT_SECRET` | ✅ Can share | Same Intercom workspace |

### 11c. Hardcoded staging URLs in code (must fix before production deploy)

These files have hardcoded `staging.api.callsaver.ai` fallbacks that would cause production to send webhooks/links to the staging URL:

| File | Line | Issue | Fix |
|---|---|---|---|
| `firecrawl-extraction.ts` | 317 | Falls back to `staging.api.callsaver.ai` | Use `getCurrentEnvironmentUrls().apiUrl` |
| `website-discovery.ts` | 160 | Hardcoded `staging.api.callsaver.ai` webhook URL | Use `getCurrentEnvironmentUrls().apiUrl` |
| `crawl4ai-client.ts` | 309 | Hardcoded staging fallback | Dead code (Crawl4AI removed) — can ignore or delete |
| `internal-test-routes.ts` | 131 | Hardcoded staging fallback | Dead code (Crawl4AI) — can ignore |
| `email/utils/brand-assets.ts` | 28,32 | Falls back to staging if no `API_URL` | Use `getCurrentEnvironmentUrls().apiUrl` |
| `server.ts` | 1018 | Falls back to staging for docs URL | Use `getCurrentEnvironmentUrls().apiUrl` |

**Note:** `email-config.ts` and `config/loader.ts` already have proper staging/production URL maps based on `APP_ENV`. The CORS config in `server.ts:355` correctly includes both staging and production origins. These are fine.

**Action:** Fix the 4 non-dead-code files to use `getCurrentEnvironmentUrls().apiUrl` instead of hardcoded staging URLs. This is a prerequisite for production deploy.

---

## 12. Crawl4AI Cleanup Plan

**Goal:** Preserve the CDK stack code for potential future redeployment, but tear down the running AWS resources to save ~$35/month.

### Currently running Crawl4AI resources:
- 1x `t3.small` EC2 instance (`i-0784b6ec55991a7a7`) — ~$15/month
- 1x NLB (internal, `Crawl4-Crawl-AreWIiHvB4Ad`) — ~$16-20/month
- 1x ASG (min=1, max=3, desired=1)
- 1x Launch Template
- 1x Security Group
- 1x SSM Parameter (`/callsaver/shared/crawl4ai/endpoint`)
- 1x CloudWatch Alarm + Scaling Policies

### Option A: Scale ASG to 0 (cheapest, quickest)
```bash
# Scale down to 0 instances — stops EC2 cost immediately
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "Crawl4AI-Shared-Crawl4AIASGB14C26B0-O66PLcNjEbeZ" \
  --min-size 0 --max-size 0 --desired-capacity 0 \
  --region us-west-1

# NLB still costs ~$16-20/month even with 0 targets
```
**Saves:** ~$15/month (EC2 only). NLB still costs ~$16-20/month.
**To restore:** Set min=1, desired=1, max=3.

### Option B: Delete the CloudFormation stack (saves all costs)
```bash
# Full teardown — deletes NLB, ASG, EC2, SG, etc.
# CDK stack code stays in infra/cdk/lib/crawl4ai-stack.ts
aws cloudformation delete-stack --stack-name Crawl4AI-Shared --region us-west-1
```
**Saves:** ~$35/month total.
**To restore:** `cdk deploy Crawl4AI-Shared` — recreates everything from the stack code.
**Risk:** The NLB DNS name will change on re-creation (need to update any references). But since nothing references it anymore (Firecrawl replaced Crawl4AI), this is fine.

### Recommended: Option B (delete stack)
- Save ~$35/month
- CDK code preserved in `infra/cdk/lib/crawl4ai-stack.ts`
- Can redeploy anytime with `cdk deploy Crawl4AI-Shared`
- Also delete the stale IAM policies and SM secret that reference Crawl4AI
- Remove the Crawl4AI webhook endpoint from `server.ts` (dead code)

### Cleanup checklist:
1. `aws cloudformation delete-stack --stack-name Crawl4AI-Shared --region us-west-1`
2. Delete SM secret: `aws secretsmanager delete-secret --secret-id callsaver/shared/crawl4ai/OPENAI_API_KEY --region us-west-1`
3. Delete IAM policies from backend task role: `Crawl4AIOpenAIAccess`, `Crawl4AISSMAccess`
4. Remove from deploy script: `CRAWL4AI_ENDPOINT`, `CRAWL4AI_WEBHOOK_URL`, `CRAWL4AI_WEBHOOK_SECRET` env vars
5. (Optional) Remove dead code: `crawl4ai-client.ts`, `website-discovery.ts` crawl4ai paths, `/webhooks/crawl4ai` endpoint in `server.ts`

---

## 13. Updated Production Launch Checklist (Priority Order)

### Week 1: Infrastructure & CDK fixes

- [ ] **Fix CDK code** (9 missing secrets, agent INTERNAL_API_KEY path, WEBSITE_EXTRACTION_PROVIDER env var, shared bucket IAM grants)
- [ ] **Fix hardcoded staging URLs** in firecrawl-extraction.ts, website-discovery.ts, brand-assets.ts, server.ts
- [ ] **Fix `.env.staging`** PIPEDREAM_ENVIRONMENT from `production` → `development`
- [ ] **Deploy CDK to staging** — validate all secrets, VAPID push, task definitions
- [ ] **Delete Crawl4AI stack** and clean up stale IAM/SM resources
- [ ] **Delete stale IAM policies** (S3CompanyWebsiteExtractionsAccess, Crawl4AI*)

### Week 2: Production environment setup

- [ ] **Create production Supabase project** + run Prisma migrations
- [ ] **Create production Upstash Redis** instance (or decide on shared)
- [ ] **Create Stripe production webhook** at `https://api.callsaver.ai/webhooks/stripe` → get signing secret
- [ ] **Create Stripe production prices** (meter, implementation fee, usage standard, usage enterprise)
- [ ] **Create Cal.com production webhook** at `https://api.callsaver.ai/webhooks/cal/booking-created` → get secret
- [ ] **Configure DocuSeal production webhook** URL on shared EC2 server
- [ ] **Configure Intercom production webhook** URL
- [ ] **Decide LiveKit setup** (same project with separate key pair, or new project)
- [ ] **Create Sentry production project** (or reuse with `production` environment tag)
- [ ] **Create all 41 production SM secrets** (script shared ones, manually create unique ones)
- [ ] **Create 8 production agent SM secrets** (copy from staging)
- [ ] **Delete orphaned SM secrets** (3 Stripe + 1 Crawl4AI)
- [ ] **Fix `.env.production`** (Stripe live key, AWS_SESSION_BUCKET, add missing entries)

### Week 3: Production deploy & verify

- [ ] **Deploy CDK for production** (`cdk deploy -c env=production`)
- [ ] **Align ECR repo naming** (agent deploy script → `callsaver-livekit-python`)
- [ ] **Deploy backend to production** (update deploy script for production)
- [ ] **Deploy agent to production** (update deploy script for production)
- [ ] **Verify all webhooks** (Stripe test event, Cal.com test booking, Firecrawl test scrape)
- [ ] **Verify push notifications** (VAPID)
- [ ] **Verify Pipedream OAuth** (test Jobber + GCal connect flow in production)
- [ ] **DNS cutover** — point `api.callsaver.ai` to production ALB
