# Firecrawl Migration Plan: Add Firecrawl Website Extraction (Alongside Crawl4AI)

**Date:** Feb 14, 2026  
**Status:** Draft (v2)  
**Scope:** Add Firecrawl managed API as an alternative website extraction provider in the Cal.com booking pipeline, keeping Crawl4AI code in place for backwards compatibility and fallback

---

## 1. Current Architecture (Crawl4AI)

The Cal.com booking pipeline (`cal-booking-pipeline.ts` Step 2.6) currently does:

```
Google Place Details → website URL
    ↓
website-discovery.ts: discoverTargetUrls()
    → Crawl4AI /seed endpoint (BM25 sitemap scoring, self-hosted EC2)
    → Returns top 15 relevant URLs
    ↓
website-discovery.ts: submitExtractionJob()
    → Crawl4AI /crawl/job endpoint (async, webhook callback)
    → Fire-and-forget
    ↓
server.ts: POST /webhooks/crawl4ai
    → Receives crawled markdown
    ↓
website-extraction.ts: processExtractionWebhook()
    → Sends markdown to OpenAI gpt-4o-mini (our own API key)
    → Validates against WebsiteExtractionProfileSchema (Zod)
    → Stores JSON to S3 (callsaver-business-profiles/{attioCompanyRecordId}/website_extraction.json)
    → Updates Attio Company with s3_business_profile_json_url
```

### Files involved:
- `src/services/website-discovery.ts` — URL discovery via Crawl4AI /seed + extraction job submission
- `src/services/website-extraction.ts` — Webhook processing, OpenAI extraction, S3 storage, Attio update
- `src/services/crawl4ai-client.ts` — Full Crawl4AI HTTP client (SSM, Secrets Manager integration)
- `src/config/runtime.ts` — crawl4aiEndpoint, crawl4aiWebhookUrl, crawl4aiWebhookSecret config
- `src/server.ts` — POST /webhooks/crawl4ai endpoint
- `src/routes/internal-test-routes.ts` — POST /internal/crawl4ai-webhook test endpoint
- `infra/cdk/` — Crawl4AI-Shared CDK stack (EC2, NLB, ASG, IAM)

### Pain points:
- **EC2 management overhead** — patching, scaling, monitoring a self-hosted Crawl4AI server
- **Webhook complexity** — async webhook flow with custom headers for metadata passing
- **Two-step extraction** — Crawl4AI returns raw markdown, then we run a separate OpenAI call to extract structured data
- **BM25 URL discovery** — basic keyword matching, no semantic understanding of page relevance
- **Slow dev iteration** — 5-10 min CDK deploys to test changes

---

## 2. Proposed Architecture (Firecrawl — alongside Crawl4AI)

**Key design decision:** Both providers coexist. A `WEBSITE_EXTRACTION_PROVIDER` env var (`firecrawl` | `crawl4ai`) controls which path runs. Crawl4AI code stays untouched.

### Pipeline Flow (Firecrawl path — event-driven with webhooks):

```
Cal.com booking pipeline (cal-booking-pipeline.ts)
    ↓
STEP 1: Firecrawl /v2/map (synchronous, ~1-2s)
    → Input: website URL
    → Options: { limit: 100 }
    → Returns: [{ url, title, desc }]
    ↓
STEP 2: GPT-4o-mini structured output (synchronous, ~2-3s)
    → Select 5-15 target pages from map
    → Uses URL + title + description context
    ↓
STEP 3: Firecrawl /v2/batch/scrape (fire-and-forget with webhook)
    → POST with urls + formats: ['markdown'] + webhook config
    → webhook.url = https://staging.api.callsaver.ai/webhooks/firecrawl
    → webhook.events = ['batch_scrape.completed']
    → webhook.metadata = { attioCompanyRecordId, calBookingUid, businessName, targetUrls }
    → Returns immediately with { id, url } (batch job ID)
    → Update Attio: firecrawl_batch_id, extraction_status = 'scraping'
    ↓
    ... Firecrawl scrapes pages asynchronously ...
    ↓
STEP 4: Firecrawl webhook → POST /webhooks/firecrawl
    → Event: batch_scrape.completed
    → Verify signature: X-Firecrawl-Signature (HMAC-SHA256)
    → Payload: { success, type, id, data: [], metadata }
    → Fetch full results via GET /v2/batch/scrape/{id}
    → Return 200 immediately, process async via setImmediate()
    ↓
STEP 5: Concatenate all page markdown (token-aware)
    → Count tokens with tiktoken (o200k_base encoding)
    → If ≤ 110k tokens: direct concatenation
    → If > 110k tokens: per-page summarization → then concatenate
    ↓
STEP 6: Single GPT-4o-mini structured output
    → Input: concatenated markdown + V3 extraction prompt
    → Output: WebsiteExtractionProfileV3
    → Uses zodResponseFormat for type safety
    ↓
STEP 7: Store to S3 + Update Attio (shared logic)
    → S3: callsaver-business-profiles/{id}/website_extraction.json
    → Attio: s3_business_profile_json_url, extraction_status = 'completed'
```

### Pipeline Flow (Crawl4AI path — improved with shared token-aware extraction):

```
cal-booking-pipeline.ts
    ↓
discoverTargetUrls() → Crawl4AI /seed (BM25) → Top 15 URLs
    ↓
submitExtractionJob() → Crawl4AI /crawl/job → Webhook callback
    ↓
POST /webhooks/crawl4ai → processExtractionWebhook()
    ↓
Token-aware markdown preparation (shared with Firecrawl path):
    → Count tokens with tiktoken (o200k_base encoding)
    → If ≤ 110k tokens: use concatenated markdown as-is
    → If > 110k tokens: per-page summarization → then concatenate
    ↓
OpenAI GPT-4o-mini extraction → S3 + Attio
```

**Crawl4AI extraction improvement:** The existing `website-extraction.ts` currently truncates markdown at a hard 50k character limit. This will be upgraded to use the same tiktoken-based token counting and tiered summarization approach as the Firecrawl path. Both providers will share a common `prepareMarkdownForExtraction()` utility from a new `src/services/extraction-utils.ts` module.

### Key architectural changes:

| Aspect | Crawl4AI (kept) | Firecrawl (new) |
|--------|----------------|------------------|
| **Infrastructure** | Self-hosted EC2 (CDK stack) | Managed API (no infra) |
| **URL discovery** | BM25 keyword scoring on sitemap | Firecrawl /map + GPT-4o-mini semantic selection |
| **Scraping** | Crawl4AI headless browser | Firecrawl managed scraping |
| **Extraction** | Crawl → markdown → OpenAI | Firecrawl → markdown → concat → single OpenAI structured output |
| **Flow** | Async (webhook) | Async (webhook) — same pattern! |
| **Webhook endpoint** | `POST /webhooks/crawl4ai` | `POST /webhooks/firecrawl` |
| **Webhook security** | Custom `X-Webhook-Secret` header | HMAC-SHA256 via `X-Firecrawl-Signature` |
| **Switching** | `WEBSITE_EXTRACTION_PROVIDER=crawl4ai` | `WEBSITE_EXTRACTION_PROVIDER=firecrawl` |

### Why webhook-based (not synchronous polling):
- **Event-driven**: Matches the existing Crawl4AI architecture — both providers use the same fire-and-forget + webhook pattern
- **No long-running requests**: The booking pipeline returns quickly after submitting the batch scrape job (~3-5s for map + URL selection + job submission)
- **Resilient**: If the server restarts during scraping, the webhook will still fire and be processed
- **Scalable**: No open connections or polling loops consuming server resources
- **Consistent**: Both Crawl4AI and Firecrawl paths follow the same async webhook pattern, making the provider switch cleaner

### Why markdown concat + single OpenAI call (not per-page Firecrawl JSON extraction):
- **Full context**: GPT-4o-mini sees ALL page content at once, so it can deduplicate across pages and make better decisions about field population
- **Our prompt, our quality**: We control the extraction prompt and can iterate on it without depending on Firecrawl's extraction engine
- **Consistent**: Same extraction approach as Crawl4AI path (markdown → OpenAI), just different scraping provider
- **Cost control**: One OpenAI call per website instead of N calls (one per page)

### Firecrawl Webhook Details:

**Batch scrape request** (Step 3):
```typescript
const response = await fetch('https://api.firecrawl.dev/v2/batch/scrape', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${firecrawlApiKey}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    urls: targetUrls,
    formats: ['markdown'],
    webhook: {
      url: 'https://staging.api.callsaver.ai/webhooks/firecrawl',
      headers: {
        'X-Internal-API-Key': internalApiKey,
      },
      metadata: {
        attioCompanyRecordId,
        calBookingUid,
        businessName,
      },
      events: ['batch_scrape.completed'],
    },
  }),
});
// Returns: { success: true, id: 'batch-id-xxx', url: '...' }
```

**Webhook payload** (Step 4 — `batch_scrape.completed`):
```json
{
  "success": true,
  "type": "batch_scrape.completed",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "data": [],
  "metadata": {
    "attioCompanyRecordId": "...",
    "calBookingUid": "...",
    "businessName": "..."
  }
}
```

**Note:** The `batch_scrape.completed` event's `data` array is empty — we need to fetch the full results via `GET /v2/batch/scrape/{id}` using the batch ID from the payload.

**Webhook signature verification** (`X-Firecrawl-Signature`):
```typescript
// Header format: sha256=<hex-digest>
const signature = req.get('X-Firecrawl-Signature');
const [algorithm, hash] = signature.split('=');
const expectedSignature = crypto
  .createHmac('sha256', firecrawlWebhookSecret)
  .update(req.body)  // raw body, before JSON parsing
  .digest('hex');
crypto.timingSafeEqual(Buffer.from(hash, 'hex'), Buffer.from(expectedSignature, 'hex'));
```

**Firecrawl webhook secret**: Found in Firecrawl dashboard → Settings → Advanced tab. Must be stored as `FIRECRAWL_WEBHOOK_SECRET` in Secrets Manager and .env files.

---

## 3. Schema Update: V3 Alignment

The current `callsaver-api` schema (`website-extraction.ts`) has fields not in V3:
- `founded_year` — **DROP** (available from Google Place Details)
- `after_hours_fee_policy` — **DROP** (rarely populated, low value)
- `payment_methods` — **DROP** (rarely populated, low value)

The V3 schema (`lead-gen-production`) adds:
- `membership_plan_benefits` — **ALREADY EXISTS** in current schema
- `frequently_asked_questions` — **ALREADY EXISTS** in current schema

**Action:** Adopt the V3 schema from `lead-gen-production/extraction/extract_website_profiles.py` as the canonical schema. Port the Pydantic model to a Zod schema for use with OpenAI's `zodResponseFormat`.

---

## 4. Implementation Plan

### Phase 1: Local Test Script (no deploy needed) ← START HERE
**Goal:** Validate the full Firecrawl pipeline locally against real websites before touching the API codebase.

**File:** `scripts/test-firecrawl-extraction.ts`

```
Usage: npx tsx scripts/test-firecrawl-extraction.ts https://www.oak.plumbing
       npx tsx scripts/test-firecrawl-extraction.ts https://www.oak.plumbing --max-pages 10 --save

Reads from .env: FIRECRAWL_API_KEY, OPENAI_API_KEY
```

Steps in the test script:
1. Accept a URL argument
2. Call Firecrawl `/v2/map` → discover all site URLs with titles/descriptions
3. Call OpenAI gpt-4o-mini structured output → select 5-15 target pages
4. Call Firecrawl `/v2/batch/scrape` with `formats: ['markdown']` → get per-page markdown
5. Concatenate all page markdown into single document (with URL headers per section)
6. Call OpenAI gpt-4o-mini structured output with `zodResponseFormat` → extract WebsiteExtractionProfileV3
7. Print final JSON to stdout; optionally save to `scripts/output/`

**Dependencies:** `@mendable/firecrawl-js` (already installed as devDependency)

**No AWS, no S3, no Attio needed** — pure local execution for rapid iteration.

### Phase 2: New Service Module
**Goal:** Create `src/services/firecrawl-extraction.ts` alongside existing Crawl4AI code.

This module has two halves — the **submission** side (called from the booking pipeline) and the **webhook processing** side (called from the webhook endpoint).

**Submission exports** (called from `cal-booking-pipeline.ts`):
```typescript
// Steps 1-3: Map → URL selection → submit batch scrape with webhook
export async function submitFirecrawlExtraction(
  websiteUrl: string,
  businessName: string,
  attioCompanyRecordId: string,
  calBookingUid: string,
): Promise<{
  batchId: string;
  mapResults: number;
  targetUrls: string[];
  error?: string;
}>
```

**Webhook processing exports** (called from `POST /webhooks/firecrawl`):
```typescript
// Steps 4-7: Fetch results → concat markdown → extract → S3 + Attio
export async function processFirecrawlWebhook(
  batchId: string,
  metadata: { attioCompanyRecordId: string; calBookingUid: string; businessName: string },
): Promise<{
  profile: WebsiteExtractionProfileV3 | null;
  pagesScraped: number;
  markdownTokens: number;
  wasSummarized: boolean;
  error?: string;
}>
```

### Phase 3: Pipeline Integration (Provider Switch + Webhook Endpoint)
**Goal:** Add Firecrawl as an alternative provider in `cal-booking-pipeline.ts` Step 2.6, and add the Firecrawl webhook endpoint.

Changes:
1. **`cal-booking-pipeline.ts`** — Add provider switch:
   ```typescript
   if (runtimeConfig.websiteExtractionProvider === 'firecrawl') {
     // Firecrawl path: map → select → submit batch scrape (fire-and-forget)
     const result = await submitFirecrawlExtraction(
       websiteUrl, businessName, attioCompanyRecordId, calBookingUid
     );
     // Update Attio with discovery results + batch ID
     // Extraction completes asynchronously via webhook
   } else {
     // Existing Crawl4AI path (unchanged)
     const discoveryResult = await discoverTargetUrls(websiteDomain);
     await submitExtractionJob(...);
   }
   ```
2. **`server.ts`** — Add `POST /webhooks/firecrawl` endpoint:
   ```typescript
   app.post('/webhooks/firecrawl', express.raw({ type: 'application/json' }), async (req, res) => {
     // 1. Verify X-Firecrawl-Signature (HMAC-SHA256)
     // 2. Parse payload, extract batch ID + metadata
     // 3. Return 200 immediately
     // 4. setImmediate → processFirecrawlWebhook(batchId, metadata)
   });
   ```
3. **`runtime.ts`** — Add `firecrawlApiKey`, `firecrawlWebhookSecret`, and `websiteExtractionProvider` config
4. **`deploy-staging-local.sh`** — Add secrets + env vars
5. **Crawl4AI code** — Untouched. All existing files remain as-is.

### Phase 4: Decommission Crawl4AI (future, separate decision)
**Deferred.** Once Firecrawl is validated in production for weeks/months:
- Remove Crawl4AI-Shared CDK stack
- Delete SSM parameter `/callsaver/shared/crawl4ai/endpoint`
- Delete Secrets Manager secret `callsaver/shared/crawl4ai/OPENAI_API_KEY`
- Terminate EC2 instances
- **Save ~$50-100/month** in EC2 costs

---

## 5. Secrets & Configuration

### New secrets/env vars needed:

| Variable | Value | Where | Type |
|----------|-------|-------|------|
| `FIRECRAWL_API_KEY` | `fc-ffe17b10b22d4198b292e7d2e6a11ad0` | Secrets Manager + all .env files | Secret (sensitive) |
| `FIRECRAWL_WEBHOOK_SECRET` | *(from Firecrawl dashboard → Settings → Advanced)* | Secrets Manager + all .env files | Secret (sensitive) |
| `WEBSITE_EXTRACTION_PROVIDER` | `firecrawl` or `crawl4ai` | Environment variable + all .env files | Plain env var |

### AWS Secrets Manager:

```bash
# Create the Firecrawl API key secret
aws secretsmanager create-secret \
  --name callsaver/staging/backend/FIRECRAWL_API_KEY \
  --secret-string "fc-ffe17b10b22d4198b292e7d2e6a11ad0" \
  --region us-west-1

# Create the Firecrawl webhook secret (get value from Firecrawl dashboard → Settings → Advanced)
aws secretsmanager create-secret \
  --name callsaver/staging/backend/FIRECRAWL_WEBHOOK_SECRET \
  --secret-string "2d6f1b4f445ed258ecf6e48e0a7aca31aa7f2af0e07d3c8a84a778f6fd43d607" \
  --region us-west-1

# For production (same keys or different):
aws secretsmanager create-secret \
  --name callsaver/production/backend/FIRECRAWL_API_KEY \
  --secret-string "fc-ffe17b10b22d4198b292e7d2e6a11ad0" \
  --region us-west-1

aws secretsmanager create-secret \
  --name callsaver/production/backend/FIRECRAWL_WEBHOOK_SECRET \
  --secret-string "2d6f1b4f445ed258ecf6e48e0a7aca31aa7f2af0e07d3c8a84a778f6fd43d607" \
  --region us-west-1
```

### .env files (add to all):

```bash
# Website extraction provider: 'firecrawl' or 'crawl4ai'
WEBSITE_EXTRACTION_PROVIDER=firecrawl
FIRECRAWL_API_KEY=fc-ffe17b10b22d4198b292e7d2e6a11ad0
FIRECRAWL_WEBHOOK_SECRET=2d6f1b4f445ed258ecf6e48e0a7aca31aa7f2af0e07d3c8a84a778f6fd43d607
```

Files to update:
- `.env` — local development (already has FIRECRAWL_API_KEY, add FIRECRAWL_WEBHOOK_SECRET)
- `.env.local` — local overrides
- `.env.staging` — staging config
- `.env.production` — production config (when ready)

### deploy-staging-local.sh changes:

In the `updateBackend` jq function, add:
```jq
# In the .environment section, add:
{ "name": "WEBSITE_EXTRACTION_PROVIDER", "value": "firecrawl" }

# In the .secrets section, add:
{ "name": "FIRECRAWL_API_KEY", "valueFrom": "arn:aws:secretsmanager:us-west-1:836347236108:secret:callsaver/staging/backend/FIRECRAWL_API_KEY" },
{ "name": "FIRECRAWL_WEBHOOK_SECRET", "valueFrom": "arn:aws:secretsmanager:us-west-1:836347236108:secret:callsaver/staging/backend/FIRECRAWL_WEBHOOK_SECRET" }
```

### IAM: Execution role needs access to new secrets

Add inline policy (or update existing) on the ECS execution role (`Callsaver-Backend-staging-ExecutionRole605A040B-Rug2UnKSiKT0`):
```json
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": [
    "arn:aws:secretsmanager:us-west-1:836347236108:secret:callsaver/staging/backend/FIRECRAWL_API_KEY*",
    "arn:aws:secretsmanager:us-west-1:836347236108:secret:callsaver/staging/backend/FIRECRAWL_WEBHOOK_SECRET*"
  ]
}
```

### runtime.ts changes:

```typescript
// Add to runtimeConfigSchema:
firecrawlApiKey: z.string().optional(),
firecrawlWebhookSecret: z.string().optional(),
websiteExtractionProvider: z.enum(['firecrawl', 'crawl4ai']).default('crawl4ai'),

// Add to runtimeConfig parse:
firecrawlApiKey: process.env.FIRECRAWL_API_KEY,
firecrawlWebhookSecret: process.env.FIRECRAWL_WEBHOOK_SECRET,
websiteExtractionProvider: process.env.WEBSITE_EXTRACTION_PROVIDER ?? 'crawl4ai',
```

### Existing Crawl4AI config (kept as-is):
- `CRAWL4AI_ENDPOINT` — SSM parameter, set in CDK
- `CRAWL4AI_WEBHOOK_URL` — plain env var in deploy script
- `CRAWL4AI_WEBHOOK_SECRET` — plain env var in deploy script

---

## 6. Cost Comparison

### Crawl4AI (current):
- EC2 instance(s): ~$50-100/month base (t3.medium or similar)
- OpenAI gpt-4o-mini: ~$0.002-0.005 per extraction (50k tokens input)
- Total per extraction: EC2 amortized + ~$0.005

### Firecrawl (proposed):
- Map: 1 credit per call
- Batch scrape: 1 credit per URL scraped (5-15 URLs = 5-15 credits per extraction)
- Firecrawl pricing: varies by plan (Hobby: 500 credits/mo free, Scale: $0.005-0.01/credit)
- OpenAI gpt-4o-mini: ~$0.001 (URL selection) + ~$0.003-0.005 (extraction from concat markdown)
- **No EC2 costs**

**Estimated per-extraction cost:** ~$0.05-0.15 (Firecrawl credits) + ~$0.005 (OpenAI)  
**Break-even:** If doing <500 extractions/month, Firecrawl Hobby tier may suffice. At scale, compare Firecrawl plan pricing against EC2 costs.

---

## 7. Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Firecrawl API downtime | Fall back to `crawl4ai` provider — just flip env var |
| Rate limits on Firecrawl | Start with Scale plan; batch scrape handles queuing internally |
| Markdown too long for context | Token-aware tiered approach: direct concat if ≤110k tokens, per-page summarization if larger, token-precise truncation as safety net |
| Map endpoint misses URLs | Map includes sitemap; coverage should be >= Crawl4AI BM25 approach |
| Batch scrape timeout | Set reasonable timeout (120s); handle gracefully |
| Schema drift | Single source of truth in callsaver-api after migration |
| Provider switch causes regression | Both providers tested independently; switch is env-var-only (no code deploy needed) |

---

## 8. Testing Strategy

### Local test script (Phase 1):
Test against real websites used in production:
- `https://www.oak.plumbing` — plumbing company
- A few other domains from Attio with known good/bad extraction results
- Compare output quality against current Crawl4AI extractions

### Staging (Phase 3):
- Deploy with `WEBSITE_EXTRACTION_PROVIDER=firecrawl`
- Run a few real bookings through the pipeline
- Compare extraction quality and S3 output
- If issues, flip back to `WEBSITE_EXTRACTION_PROVIDER=crawl4ai` — no code change needed

### Regression:
- Ensure all V3 schema fields are populated at similar rates
- Check S3 storage path unchanged
- Check Attio update still works

---

## 9. Implementation Sequence

```
1. ✅ Create local test script (Phase 1)
   └─ Validate Firecrawl map → GPT URL selection → batch scrape markdown → concat → GPT extraction
   └─ Test on https://www.oak.plumbing — 16/18 fields populated, 58s total
   └─ Token-aware tiered approach: tiktoken counting + summarization fallback

2. ✅ Add FIRECRAWL_API_KEY + WEBSITE_EXTRACTION_PROVIDER to .env files (all 4)
   └─ .env, .env.local, .env.staging, .env.production

3. ✅ Get FIRECRAWL_WEBHOOK_SECRET from Firecrawl dashboard
   └─ Added to all .env files

4. Create AWS Secrets Manager secrets                              ← NEXT
   └─ callsaver/staging/backend/FIRECRAWL_API_KEY
   └─ callsaver/staging/backend/FIRECRAWL_WEBHOOK_SECRET
   └─ Add IAM policy to execution role

5. Create shared extraction-utils.ts
   └─ prepareMarkdownForExtraction() — tiktoken counting + tiered summarization
   └─ summarizePage() — per-page GPT-4o-mini summarization for oversized content
   └─ Shared by both Crawl4AI and Firecrawl extraction paths

6. Update Crawl4AI extraction (website-extraction.ts)
   └─ Replace hard 50k char truncation with shared prepareMarkdownForExtraction()
   └─ Both providers now use identical token-aware extraction logic

7. Create firecrawl-extraction.ts (Phase 2)
   └─ Submission side: submitFirecrawlExtraction() — map + select + submit batch scrape
   └─ Webhook side: processFirecrawlWebhook() — fetch results + shared extraction + S3 + Attio
   └─ Add runtime.ts config: firecrawlApiKey, firecrawlWebhookSecret, websiteExtractionProvider

8. Integrate into pipeline (Phase 3)
   └─ Add provider switch in cal-booking-pipeline.ts
   └─ Add POST /webhooks/firecrawl endpoint in server.ts
   └─ Update deploy-staging-local.sh with new secrets + env vars
   └─ Deploy to staging

9. Validate on staging (1-2 days)
   └─ Monitor extraction quality, costs, and timing
   └─ Crawl4AI remains available as instant fallback (flip env var)

10. (Future) Decommission Crawl4AI (Phase 4)
   └─ Only after extended Firecrawl validation
   └─ Remove CDK stack, EC2, secrets
```

---

## 10. Open Questions

1. **Firecrawl plan selection** — Which tier? Hobby (500 free credits), Scale ($49/mo, 10k credits)? Need to estimate monthly extraction volume.
2. **Fallback for map failures** — If /map returns 0 results (e.g., JS-heavy SPA with no sitemap), should we fall back to scraping just the homepage?
3. **Batch scrape concurrency** — Firecrawl handles this internally, but should we cap at 10-15 URLs to control costs?
4. **Production secret** — Use same Firecrawl API key for staging + production, or create separate keys for cost tracking?
5. **Firecrawl webhook secret** — Need to retrieve from Firecrawl dashboard → Settings → Advanced tab. Is it per-account or per-project?
6. **`batch_scrape.completed` data field is empty** — The completed event payload has `data: []`. We need to confirm: do we fetch full results via `GET /v2/batch/scrape/{id}`, or do we accumulate `batch_scrape.page` events? Fetching on completion is simpler and more reliable.
7. **Webhook retry behavior** — Does Firecrawl retry failed webhook deliveries? If our server is temporarily down, do we lose the event? May need a fallback polling mechanism for missed webhooks.
