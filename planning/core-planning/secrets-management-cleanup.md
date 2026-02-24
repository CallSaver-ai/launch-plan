# Secrets Management Cleanup Plan

**Created:** 2026-02-15
**Status:** Draft
**Priority:** High (blocking production launch)

## Problem Summary

The staging environment has three overlapping sources of environment variables/secrets that have diverged over time:

1. **`.env.staging`** — plaintext file with ALL credentials (local dev only, gitignored but previously committed)
2. **AWS Secrets Manager** — 51 entries (intended source of truth for ECS)
3. **Deploy script** (`scripts/deploy-staging-local.sh`) — patches ECS task definition at deploy time, overriding CDK

This creates confusion about which values are actually used, causes IAM permission errors when adding secrets via the deploy script (bypasses CDK auto-granting), and leaves stale credentials scattered across files.

---

## Phase 1: Remove Dead/Stale References

### 1.1 Remove BETTER_AUTH_SECRET (no longer used)

BetterAuth was replaced by Supabase Auth. The secret is still referenced in code but never actually called.

**Files to clean up:**
- `src/config/init.ts` — remove `BETTER_AUTH_SECRET` from `moduleLevelConfig` (line 45) and delete dead `getModuleAuthSecret()` function (lines 93-105)
- `src/server.ts` — remove BetterAuth cookie logging (lines ~402-404)
- `.env.staging` — remove `BETTER_AUTH_SECRET` line (line 27)
- `.env.local` — remove `BETTER_AUTH_SECRET` line
- `.env` — remove `BETTER_AUTH_SECRET` line
- `.env.production` — remove `BETTER_AUTH_SECRET` line
- `.env.test` — remove `BETTER_AUTH_SECRET` line
- Test files — remove/update `BETTER_AUTH_SECRET` references (many test files set it as a dummy env var)

**AWS Secrets Manager:**
- `BETTER_AUTH_SECRET` does NOT exist in Secrets Manager (never created), so no SM cleanup needed.

### 1.2 Remove SendGrid References (replaced by SES)

SendGrid is no longer used. SES is the email provider.

**Files to clean up:**
- `.env.staging` — remove `SENDGRID_API_KEY`, `SENDGRID_FROM_EMAIL`, `SENDGRID_FROM_NAME` (lines 58-60)
- `.env.local` — remove same three lines
- `.env` — remove same three lines
- `.env.production` — remove same three lines
- `src/config/loader.ts` — remove SendGrid entries from Zod schema if present

**AWS Secrets Manager:**
- No SendGrid secrets exist in SM, so no SM cleanup needed.

### 1.3 Delete Orphaned Secrets Manager Entries

These secrets exist in SM but are NOT referenced by any ECS task definition or code:

| Secret | Reason for Deletion |
|--------|-------------------|
| `callsaver/staging/backend/STRIPE_CANCEL_URL` | Unused — checkout URLs are hardcoded from `envUrls.baseUrl` in `stripe-checkout-v2.ts` |
| `callsaver/staging/backend/STRIPE_PUBLISHABLE_KEY` | Unused — only in `config/loader.ts` as optional, never read at runtime in backend |
| `callsaver/staging/backend/STRIPE_SUCCESS_URL` | Unused — same as CANCEL_URL |

**Commands:**
```bash
aws secretsmanager delete-secret --secret-id callsaver/staging/backend/STRIPE_CANCEL_URL --region us-west-1 --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id callsaver/staging/backend/STRIPE_PUBLISHABLE_KEY --region us-west-1 --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id callsaver/staging/backend/STRIPE_SUCCESS_URL --region us-west-1 --force-delete-without-recovery
```

Also clean up the optional Zod entries in `src/config/loader.ts`:
- Remove `STRIPE_PUBLISHABLE_KEY` (line 77)
- Remove `STRIPE_SUCCESS_URL` (line 139)
- Remove `STRIPE_CANCEL_URL` (line 140)

### 1.4 Remove `SESSION_COOKIE_NAME` from `.env.staging`

This was a BetterAuth config. Remove from all `.env*` files.

---

## Phase 2: Fix Deploy Script Fragility

### 2.1 Remove Hardcoded ARN Suffixes

The deploy script uses full ARNs with random 6-char suffixes (e.g., `-t9Mu4r`). ECS can resolve secrets by name without the suffix. If a secret is ever recreated, the suffix changes and the deploy breaks.

**Current (fragile):**
```json
{"name": "FIRECRAWL_API_KEY", "valueFrom": "arn:aws:secretsmanager:us-west-1:836347236108:secret:callsaver/staging/backend/FIRECRAWL_API_KEY-t9Mu4r"}
```

**Fixed (resilient):**
```json
{"name": "FIRECRAWL_API_KEY", "valueFrom": "arn:aws:secretsmanager:us-west-1:836347236108:secret:callsaver/staging/backend/FIRECRAWL_API_KEY"}
```

**Secrets to fix in `scripts/deploy-staging-local.sh`:**
- `FIRECRAWL_API_KEY` — remove `-t9Mu4r`
- `FIRECRAWL_WEBHOOK_SECRET` — remove `-h0rPWk`
- `LIVEKIT_SIP_ENDPOINT` — remove `-MHzwhI`
- `LIVEKIT_WORKER_NAME` — remove `-8ekrJq`
- `LIVEKIT_OUTBOUND_TRUNK_ID` — remove `-JxsS0p`

### 2.2 Move `CRAWL4AI_WEBHOOK_SECRET` to Secrets Manager

Currently hardcoded as plaintext env var in the deploy script:
```json
{"name": "CRAWL4AI_WEBHOOK_SECRET", "value": "crawl4ai-webhook-secret-staging"}
```

**Action:**
1. Create SM secret: `callsaver/staging/backend/CRAWL4AI_WEBHOOK_SECRET`
2. Update deploy script to reference it as a secret, not an env var
3. Add to CDK `config.ts` and `backend-service-stack.ts`
4. Grant IAM permission (or let CDK handle it on next CDK deploy)

---

## Phase 3: Reclassify Config vs Secrets

These are NOT credentials — they're configuration values that don't need Secrets Manager. Move them to plaintext environment variables in CDK (saves cost, reduces IAM complexity).

| Current SM Secret | Value | Should Be |
|-------------------|-------|-----------|
| `APP_ENV` | `staging` | Plaintext env var |
| `NODE_ENV` | `production` | Plaintext env var |
| `SENTRY_ENVIRONMENT` | `staging` | Plaintext env var |
| `SESSION_S3_BUCKET` | `callsaver-sessions-staging` | Plaintext env var |
| `BUSINESS_PROFILES_S3_BUCKET` | `callsaver-business-profiles` | Plaintext env var |
| `LIVEKIT_WORKER_NAME` | `callsaver-agent` | Plaintext env var |
| `LIVEKIT_SIP_ENDPOINT` | `3ntbgc4zbx6.sip.livekit.cloud` | Plaintext env var |
| `SES_CONFIGURATION_SET` | (config value) | Plaintext env var |
| `SES_FROM_EMAIL` | (email address) | Plaintext env var |
| `DOCS_PASSWORD` | `100million!` | Keep as secret (it's a password) |

**Action:** Update CDK `backend-service-stack.ts` to move these from `secrets:` to `environment:` block. Then delete the SM entries after next CDK deploy.

---

## Phase 4: Switch Staging to Upstash (Production Parity)

**Current situation:**
- CDK defines `REDIS_URL` from Secrets Manager (which has the Upstash URL)
- CDK also creates a Redis sidecar for staging (`useRedisSidecar: envName === 'staging'`)
- Deploy script OVERRIDES `REDIS_URL` to `redis://localhost:6379` (sidecar)

This is contradictory — CDK pulls from SM (Upstash) but the deploy script overrides it to use the sidecar.

**Recommendation:** Switch staging to use **Upstash** (same as production) for better production parity. For e2e testing, we want staging to behave identically to production. The sidecar was a cost optimization from early development, but Upstash free tier is sufficient for staging traffic.

**Benefits of Upstash for staging:**
- Production parity — catches Redis-related bugs (connection timeouts, reconnection, stale cache)
- Persistent state — survives deploys, useful for debugging
- Observable via Upstash dashboard
- Simplifies CDK and deploy script (no sidecar container management)

**Action:**
1. Verify `REDIS_URL` in SM (`callsaver/staging/backend/REDIS_URL`) points to Upstash staging instance
2. Set `useRedisSidecar: false` for staging in `infra/cdk/bin/callsaver.ts` (line 94)
3. Remove the `REDIS_URL` plaintext override from the deploy script
4. Remove the sidecar container injection from the deploy script (`ensureRedisContainer` function)
5. On next CDK deploy, the sidecar container definition will be removed automatically
6. Keep Upstash URL in `.env.staging` for local dev (local dev also uses Upstash, matching staging)

---

## Phase 5: AI Provider Keys for Python Agent

These keys are used by the **Python LiveKit agent** (separate ECS service), NOT the Node.js backend:

| Key | Used in Node.js? | Used in Python Agent? | In Node .env.staging? |
|-----|-------------------|----------------------|----------------------|
| `DEEPGRAM_API_KEY` | No | Yes (STT) | Yes |
| `CARTESIA_API_KEY` | Yes (voice sample scripts) | Yes (TTS) | Yes |
| `ASSEMBLYAI_API_KEY` | No | Yes (fallback STT) | Yes |
| `ANTHROPIC_API_KEY` | No | Yes (fallback LLM) | Yes |

**Current state:**
- Python agent CDK stack (`agent-service-stack.ts`) already injects these from `callsaver/staging/agent/*` namespace
- `.env.staging` has them for local dev convenience

**Action:**
- Keep ALL of these in `.env.staging` for now (they don't hurt anything and are convenient for local dev)
- These keys live in the `callsaver/staging/agent/*` SM namespace for ECS (already correct)
- No changes needed — this is informational only
- If local Python agent dev needs them, they can source from the main `.env.staging` or use a separate `.env` in `livekit-python/`

---

## Phase 6: Converge Deploy Script with CDK (Medium-Term)

The deploy script should ideally only:
1. Build Docker image
2. Push to ECR
3. Swap image URI in the task definition
4. Force new deployment

It should NOT manage secrets or env vars. Those should be managed exclusively by CDK.

**Current flow (fragile):**
```
CDK deploy → creates task def with secrets + IAM perms
Deploy script → inherits base task def, patches in extra secrets (no IAM perms!)
```

**Target flow (robust):**
```
CDK deploy → creates task def with ALL secrets + IAM perms (source of truth)
Deploy script → only swaps image URI, preserves everything else
```

**Action:**
1. Move all 6 deploy-script-only secrets into CDK
2. Run `cdk deploy` to update task def + IAM perms
3. Simplify deploy script to only modify `.image` field
4. Remove all `+ [{...secrets...}]` blocks from deploy script

---

## Phase 7: Establish Secrets Manager as Single Source of Truth (Gradual)

**Approach:** Keep `.env.staging` for local dev convenience, but make Secrets Manager the authoritative source. Create a sync script so `.env.staging` can be refreshed from SM at any time.

**Step 1: Create `scripts/sync-env-from-sm.sh`**

This script pulls current values from SM and overwrites `.env.staging`:

```bash
#!/bin/bash
# Syncs .env.staging from AWS Secrets Manager (source of truth)
# Usage: ./scripts/sync-env-from-sm.sh

set -e
ENV_FILE=".env.staging"
BACKUP_FILE=".env.staging.backup.$(date +%Y%m%d_%H%M%S)"

# Backup current file
if [ -f "$ENV_FILE" ]; then
  cp "$ENV_FILE" "$BACKUP_FILE"
  echo "📦 Backed up current $ENV_FILE to $BACKUP_FILE"
fi

echo "🔄 Pulling secrets from AWS Secrets Manager..."

# Pull backend secrets
aws secretsmanager list-secrets --filter Key=name,Values=callsaver/staging/backend \
  --query 'SecretList[].Name' --output json --region us-west-1 | \
  jq -r '.[]' | sort | while read secret_name; do
    env_var=$(echo "$secret_name" | sed 's|callsaver/staging/backend/||')
    value=$(aws secretsmanager get-secret-value --secret-id "$secret_name" \
      --query SecretString --output text --region us-west-1 2>/dev/null || echo "FETCH_ERROR")
    if [ "$value" != "FETCH_ERROR" ]; then
      echo "${env_var}=${value}"
    else
      echo "# FAILED TO FETCH: ${env_var}" >&2
    fi
  done > "$ENV_FILE"

# Append local-only vars that aren't in SM
cat >> "$ENV_FILE" << 'EOF'

# Local-only configuration (not in Secrets Manager)
SKIP_TWILIO_PURCHASE=false
OPENAI_MODEL=gpt-4.1-mini-2025-04-14
TEST_FALLBACK_PROVIDERS=false
FEATURE_ATTIO_SYNC_ENABLED=true
ENABLE_ATTIO_WORKERS=false
MAGIC_LINK_CALLBACK_URL=/dashboard
MAGIC_LINK_NEW_USER_CALLBACK_URL=/onboarding
EOF

echo "✅ $ENV_FILE written with $(wc -l < $ENV_FILE) lines"
echo "💡 Run 'diff $BACKUP_FILE $ENV_FILE' to see what changed"
```

**Step 2: When values drift, run the sync script instead of manually editing `.env.staging`**

**Step 3 (long-term): Replace `.env.staging` with `.env.staging.example`**
- `.env.staging.example` — committed to git, contains placeholder values and comments
- New devs run `./scripts/sync-env-from-sm.sh` to generate their local `.env.staging`
- This prevents secrets from ever being committed to git again

This ensures:
- `.env.staging` stays convenient for local dev
- SM is the single source of truth
- Drift is fixable with one command
- No secrets need to be deleted from `.env.staging` (just refreshed)

---

## Execution Order

| Step | Phase | Risk | Time |
|------|-------|------|------|
| 1 | 2.1 — Fix ARN suffixes in deploy script | Low | 5 min |
| 2 | 1.3 — Delete orphaned SM entries | Low | 5 min |
| 3 | 1.1 — Remove BETTER_AUTH_SECRET from code + .env files | Low | 15 min |
| 4 | 1.2 — Remove SendGrid references from .env files | Low | 10 min |
| 5 | 1.4 — Remove SESSION_COOKIE_NAME from .env files | Low | 2 min |
| 6 | 7 — Create `scripts/sync-env-from-sm.sh` | Low | 15 min |
| 7 | 4 — Switch staging Redis to Upstash | Medium | 15 min (requires CDK deploy) |
| 8 | 3 — Reclassify config vs secrets in CDK | Medium | 30 min (requires CDK deploy) |
| 9 | 6 — Converge deploy script with CDK | Medium | 1 hr (requires CDK deploy) |
| 10 | 2.2 — Move CRAWL4AI_WEBHOOK_SECRET to SM | Low | 10 min |

**Total estimated time:** ~2.5 hours

**Note on `.env.staging`:** We are NOT deleting secrets from `.env.staging`. It remains a convenient local dev file. We only remove dead references (BetterAuth, SendGrid, SESSION_COOKIE_NAME) that are no longer used anywhere. The sync script (Phase 7) provides a way to refresh it from SM when values drift.

---

## Notes

- All changes should be tested on staging before applying to production
- Production has its own set of SM secrets under `callsaver/production/backend/*` — same patterns likely exist there
- The CDK stack for production should be audited similarly after staging cleanup
- After cleanup, document the "how to add a new secret" process so this doesn't drift again
