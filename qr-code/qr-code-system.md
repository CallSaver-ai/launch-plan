# QR Code Tracking System — Comprehensive Reference

> **Last updated:** Feb 9, 2026
> **Repo:** `~/callsaver-api`
> **Status:** ✅ Phase 1 testing COMPLETED (Feb 9, 2026) — scan tracking verified end-to-end on staging. Cal.com webhook attribution (Phase 2) deferred.

---

## 1. System Overview

The QR code system tracks business card scans and attributes Cal.com demo bookings back to specific QR codes using a deterministic session ID (`qr_sid`). It supports **A/B testing** with multiple variants per campaign.

### Flow Diagram

```
1. User scans QR code on business card
       ↓
2. GET /q/:short_code  (API logs scan, generates qr_sid UUID)
       ↓
3. 302 Redirect → /book?qr_sid=xxx&utm_source=qr_code&utm_medium=business_card&...
       ↓
4. /book page renders Cal.com inline embed (forwardQueryParams: true)
       ↓
5. User books appointment via Cal.com
       ↓
6. Cal.com fires webhook → POST /webhooks/cal/booking-created
       ↓
7. API extracts qr_sid from webhook payload, links booking → scan → variant
       ↓
8. GET /qr/variants/:id/stats returns conversion metrics
```

---

## 2. API Endpoints

### 2.1 QR Scan — `GET /q/:short_code`

**Purpose:** Entry point when a user scans the QR code. Logs the scan event and redirects to the booking page with tracking parameters.

| Aspect | Detail |
|--------|--------|
| **Auth** | None (public) |
| **Rate limit** | 20 req/min per IP hash + variant |
| **Response** | `302 Redirect` |
| **Cookie set** | `qr_sid` (30-day expiry, SameSite=Lax, secure in prod) |

**What happens:**
1. Validates `short_code` format (alphanumeric, 3-50 chars)
2. Looks up `QrVariant` by `short_code` (includes parent `QrCode`)
3. Generates `qr_sid` (UUID v4)
4. Extracts client IP → HMAC-SHA256 hash (privacy-preserving)
5. Reads Vercel geo headers (city, country, region, postal code, timezone)
6. Detects bots via user-agent pattern matching
7. Creates `QrScanEvent` record asynchronously (doesn't block redirect)
8. Sets `qr_sid` cookie
9. Returns `302` redirect to: `{redirect_url}?qr_sid=xxx&utm_source=...&utm_medium=...&utm_campaign=...&utm_content=...`

**Error codes:**
- `400` — Invalid short_code format
- `404` — Short code not found
- `429` — Rate limited
- `500` — Server error

### 2.2 Booking Page — `GET /book`

**Purpose:** Renders a standalone HTML page with Cal.com inline embed. Forwards all query params (including `qr_sid` and UTMs) to the Cal.com embed.

| Aspect | Detail |
|--------|--------|
| **Auth** | None (public) |
| **Cal.com link** | `alexsikand/demo` |
| **Key config** | `forwardQueryParams: true` |
| **Layout** | `month_view` |

**Important:** The `forwardQueryParams: true` setting is what passes `qr_sid` into Cal.com so it appears in the webhook payload when a booking is created.

### 2.3 Cal Webhook — `POST /webhooks/cal/booking-created`

**Purpose:** Receives booking events from Cal.com. Extracts `qr_sid` to link the booking back to the original QR scan.

| Aspect | Detail |
|--------|--------|
| **Auth** | `CAL_WEBHOOK_SECRET` header (optional — skipped if not configured) |
| **Rate limit** | Standard webhook rate limit |
| **Response** | `200 OK` with `{ success: true, cal_booking_uid: "..." }` |

**What it extracts from the Cal.com payload:**

| Field | Source in payload | Purpose |
|-------|-------------------|---------|
| `cal_booking_uid` | `payload.uid` or `payload.id` or `payload.bookingUid` | Unique booking identifier |
| `qr_sid` | `payload.metadata.qr_sid` → `payload.responses.qr_sid` → `payload.answers.qr_sid` → `payload.customInputs.qr_sid` | Links booking to scan |
| `scheduled_at` | `payload.startTime` | When the meeting is scheduled |
| `attendee_name` | `payload.attendees[0].name` | Who booked |
| `attendee_email` | `payload.attendees[0].email` | Their email |
| `cal_event_type` | `payload.eventType.slug` | Which event type |
| UTMs | `payload.utm_source`, etc. | Marketing attribution |

**Attribution logic:**
1. If `qr_sid` is found in the payload, find the latest `QrScanEvent` with matching `session_id`
2. Get the `qr_variant_id` from that scan event
3. Upsert `CalBooking` record with `qr_variant_id` denormalized for easy reporting

### 2.4 Stats — `GET /qr/variants/:id/stats`

**Purpose:** Returns conversion metrics for a specific variant.

| Aspect | Detail |
|--------|--------|
| **Auth** | Required (`requireAuth` middleware) |
| **Query params** | `from` (ISO date, optional), `to` (ISO date, optional) |
| **Default range** | All time (if no dates provided) |

**Response:**
```json
{
  "variant_id": "cuid",
  "variant_key": "A",
  "period": { "from": "ISO", "to": "ISO" },
  "scans": { "total": 100, "unique_scanners": 85 },
  "bookings": { "total": 12 },
  "conversion_rate": 12.00
}
```

- `conversion_rate` is a **percentage** (bookings / scans × 100), rounded to 2 decimal places

---

## 3. Database Models

### 3.1 `qr_codes` — Campaigns

| Column | Type | Purpose |
|--------|------|---------|
| `id` | cuid (PK) | Primary key |
| `name` | string | Campaign name (e.g., `business_cards_feb_2026`) |
| `description` | string? | Human-readable description |
| `active` | boolean | Whether campaign is active (default: true) |
| `default_redirect_url` | string | Fallback redirect if variant has no redirect_url |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### 3.2 `qr_variants` — A/B Test Variants

| Column | Type | Purpose |
|--------|------|---------|
| `id` | cuid (PK) | Primary key |
| `qr_code_id` | FK → qr_codes | Parent campaign |
| `variant_key` | string | "A", "B", etc. |
| `label` | string | Human-readable label |
| `short_code` | string (unique) | The code in the URL: `/q/{short_code}` |
| `redirect_url` | string? | Override redirect URL (falls back to campaign default) |
| `utm_source` | string? | e.g., `qr_code` |
| `utm_medium` | string? | e.g., `business_card` |
| `utm_campaign` | string? | e.g., `business_cards_feb_2026` |
| `utm_content` | string? | e.g., `variant_a` — **this differentiates A/B variants** |
| `utm_term` | string? | Optional keyword |
| `active` | boolean | Default: true |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### 3.3 `qr_scan_events` — Individual Scans

| Column | Type | Purpose |
|--------|------|---------|
| `id` | cuid (PK) | Primary key |
| `qr_variant_id` | FK → qr_variants | Which variant was scanned |
| `session_id` | string (indexed) | The `qr_sid` UUID — **key for attribution** |
| `scanned_at` | datetime | When the scan occurred |
| `ip_address` | string? | Raw IP (for debugging) |
| `ip_hash` | string? (indexed) | HMAC-SHA256 of IP — for dedup without storing raw IP |
| `user_agent` | string? | Browser/device user agent |
| `accept_language` | string? | Browser language preference |
| `referrer` | string? | HTTP referer header |
| `request_id` | string? | X-Request-ID header |
| `vercel_ip_city` | string? | Geo: city (from Vercel headers) |
| `vercel_ip_country` | string? | Geo: country code |
| `vercel_ip_country_region` | string? | Geo: state/region |
| `vercel_ip_postal_code` | string? | Geo: postal/zip code |
| `vercel_ip_timezone` | string? | Geo: timezone |
| `is_bot` | boolean | Whether user-agent matched bot patterns |
| `landing_url` | string? | The full redirect URL that was generated |
| `created_at` | datetime | |

### 3.4 `cal_bookings` — Booking Records

| Column | Type | Purpose |
|--------|------|---------|
| `id` | cuid (PK) | Primary key |
| `cal_booking_uid` | string (unique) | Cal.com's unique booking ID |
| `session_id` | string? | The `qr_sid` — links to scan event |
| `qr_variant_id` | FK → qr_variants? | **Denormalized** — which variant led to this booking |
| `cal_event_type` | string? | Which Cal.com event type |
| `scheduled_at` | datetime? | When the meeting is scheduled |
| `attendee_name` | string? | Who booked |
| `attendee_email` | string? | Their email |
| `utm_source` | string? | Marketing attribution |
| `utm_medium` | string? | |
| `utm_campaign` | string? | |
| `utm_content` | string? | |
| `utm_term` | string? | |
| `raw_payload` | JSON? | Full Cal.com webhook payload (for debugging) |
| `created_at` | datetime | |
| `updated_at` | datetime | |

---

## 4. Tracked Parameters

### 4.1 UTM Parameters (appended to redirect URL)

| Parameter | Purpose | Example Value |
|-----------|---------|---------------|
| `utm_source` | Traffic source | `qr_code` |
| `utm_medium` | Marketing medium | `business_card` |
| `utm_campaign` | Campaign name | `business_cards_feb_2026` |
| `utm_content` | **A/B variant differentiator** | `variant_a` or `variant_b` |
| `utm_term` | Optional keyword | (unused currently) |

**GA4 picks these up automatically** when the user lands on the page with UTMs in the URL.

### 4.2 Session Tracking

| Parameter | Purpose | How it's used |
|-----------|---------|---------------|
| `qr_sid` | Deterministic session ID (UUID v4) | Set as URL param + cookie. Links scan → booking |
| `qr_sid` cookie | 30-day persistent tracking | Backup if URL param is lost. `HttpOnly=false`, `SameSite=Lax` |

### 4.3 Geo/Device Data (captured at scan time)

| Data Point | Source | Purpose |
|-----------|--------|---------|
| IP hash | HMAC-SHA256 of client IP | Deduplication, rate limiting (privacy-preserving) |
| City | `x-vercel-ip-city` header | Geo analytics |
| Country | `x-vercel-ip-country` header | Geo analytics |
| Region | `x-vercel-ip-country-region` header | State-level geo |
| Postal code | `x-vercel-ip-postal-code` header | Zip-level geo |
| Timezone | `x-vercel-ip-timezone` header | Timezone analytics |
| User agent | `User-Agent` header | Device/browser analytics |
| Language | `Accept-Language` header | Language preference |
| Referrer | `Referer` header | Where they came from |
| Is bot | Derived from user-agent | Filter out crawlers in reporting |

**Note:** Vercel geo headers are only available when the API is behind Vercel's edge network. On ECS/ALB, these will be `null`. Consider whether the `/q/` endpoint should be proxied through Vercel or if you need an alternative geo solution for ECS.

---

## 5. Environment Variables

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `QR_IP_HASH_SECRET` | **Yes** | `test_secret_for_qr_ip_hash` (dev) | HMAC secret for IP hashing |
| `CAL_WEBHOOK_SECRET` | No | None (allows all) | Shared secret for Cal.com webhook auth |
| `PUBLIC_QR_BASE_URL` | No | Request origin | Base URL for generating QR code URLs |

**⚠️ Current state:** `QR_IP_HASH_SECRET` is set to `test_secret_for_qr_ip_hash` in `.env`. **Must generate a proper secret for production:**
```bash
openssl rand -hex 32
```

---

## 6. Variant Strategy

### 6.1 How You'll Use Variants

The QR code on your **business cards stays the same** (one permanent short code). But you'll create **different QR codes for flyers** to track:

- **Which geographic area** the flyer was distributed in (e.g., downtown vs suburbs)
- **Which type of business** received it (e.g., plumbing supply shops vs Home Depot vs HVAC distributors)
- **Which copy/design** the flyer had (different headlines, offers, etc.)

Each flyer variant gets its own `short_code` and `utm_content`, so you can see in the stats dashboard exactly which distribution channel is driving the most scans and bookings.

### 6.2 Example Variant Plan

| Variant | Short Code | utm_content | Physical Medium | Distribution |
|---------|------------|-------------|-----------------|--------------|
| Business Card | `bcard` | `business_card` | Business card (permanent) | Handed out at meetings, networking |
| Flyer - Plumbing | `flyer-plumb` | `flyer_plumbing_supply` | Flyer v1 | Plumbing supply shops |
| Flyer - Home Depot | `flyer-hd` | `flyer_home_depot` | Flyer v1 | Home Depot bulletin boards |
| Flyer - HVAC | `flyer-hvac` | `flyer_hvac_supply` | Flyer v1 | HVAC supply stores |
| Flyer - Downtown | `flyer-dt` | `flyer_downtown` | Flyer v2 (different copy) | Downtown area businesses |
| Flyer - Suburbs | `flyer-sub` | `flyer_suburbs` | Flyer v2 | Suburban area businesses |

**QR URLs printed on materials:**
- Business card: `https://api.callsaver.ai/q/bcard`
- Plumbing flyer: `https://api.callsaver.ai/q/flyer-plumb`
- Home Depot flyer: `https://api.callsaver.ai/q/flyer-hd`
- etc.

### 6.3 What You Can Measure

With this setup, you can answer questions like:
- "Are plumbing supply shops or Home Depot flyers driving more demo bookings?"
- "Is the downtown copy performing better than the suburban copy?"
- "What's my conversion rate from business card scans vs flyer scans?"
- "Which geographic area has the highest scan-to-booking ratio?"

### 6.4 Current Seed Data (placeholder — needs updating)

The seed script (`scripts/seed-qr-variants.ts`) currently creates placeholder data:

| Item | Current (placeholder) | Should be |
|------|----------------------|-----------|
| **Campaign name** | `business_cards_dec_2025` | `outreach_feb_2026` |
| **Variant A short_code** | `abc123` | `bcard` |
| **Variant A utm_content** | `variant_a` | `business_card` |
| **Variant B short_code** | `def456` | `flyer-plumb` (first flyer) |
| **Variant B utm_content** | `variant_b` | `flyer_plumbing_supply` |
| **Redirect URL** | `/book` | `/book` (relative, works since /book is on API) |

**Action items before printing:**
1. Update seed script with real variant names/codes for your actual distribution plan
2. You can add more than 2 variants — create as many as you need for each flyer type/location
3. Generate a proper `QR_IP_HASH_SECRET` for production
4. Run seed script against production database
5. Generate QR code images for each short code URL
6. Print business cards and flyers with their respective QR codes

---

## 7. Known Issues & Gaps

### 7.1 Critical — Redirect URL is relative `/book`

The seed data sets `redirect_url: '/book'`. The `buildRedirectUrl()` function tries `new URL(baseUrl)` which will throw on a relative path, falling back to string concatenation. This means the redirect will be: `/book?qr_sid=xxx&utm_source=...` — a **relative redirect from the API domain**.

**Impact:** If the API is at `staging.api.callsaver.ai`, the user gets redirected to `staging.api.callsaver.ai/book` which is actually correct since the `/book` endpoint is on the API. But for production, you need to decide:
- **Option A:** Keep `/book` on the API (current setup) — redirect stays relative, works fine
- **Option B:** Move booking page to landing page — update redirect to `https://www.callsaver.ai/book`

### 7.2 Cal.com Hidden Field Setup

The webhook extraction code looks for `qr_sid` in multiple places (metadata, responses, answers, customInputs). **You must configure Cal.com** to capture `qr_sid`:

1. Go to Cal.com Dashboard → Event Types → `alexsikand/demo`
2. Add a **Hidden** booking question with identifier `qr_sid`
3. This ensures `qr_sid` appears in the webhook payload

**If this is not configured, bookings will never link to scans.**

### 7.3 Cal.com Webhook Setup

You need to configure Cal.com to send webhooks:

1. Go to Cal.com Dashboard → Settings → Developer → Webhooks
2. Add webhook URL: `https://api.callsaver.ai/webhooks/cal/booking-created` (production) or `https://staging.api.callsaver.ai/webhooks/cal/booking-created` (staging)
3. Event: `BOOKING_CREATED`
4. Set secret header if using `CAL_WEBHOOK_SECRET`

### 7.4 Vercel Geo Headers

The scan endpoint captures Vercel geo headers (`x-vercel-ip-city`, etc.). These are **only available when requests pass through Vercel's edge network**. Since the API runs on ECS behind an ALB, these headers will all be `null` unless:
- The QR redirect goes through a Vercel-hosted proxy first
- You add CloudFront geo headers instead (different header names)

### 7.5 QR_IP_HASH_SECRET

Currently set to `test_secret_for_qr_ip_hash` — must be rotated to a proper random secret before production. Existing hashes will no longer match after rotation (affects dedup counts).

### 7.6 `calLink` in `/book` page

The `/book` endpoint has `calLink: "https://cal.com/alexsikand/demo"`. This should be just `"alexsikand/demo"` (without the full URL prefix) per Cal.com embed docs. Verify this works correctly.

---

## 8. Phase 1 Testing Plan (QR Scan Only — No Cal.com)

> **Goal:** Generate a QR code, scan it with your phone, and confirm data lands in the staging database. Cal.com/booking attribution is a separate concern for all traffic sources and will be handled later.

### 8.0 Field-by-Field Analysis: Keep, Remove, or Defer?

| # | Field | Verdict | Reasoning |
|---|-------|---------|-----------|
| 1 | `qr_variant_id` | **KEEP** | Core. Links scan to variant. Without this, nothing works. |
| 2 | `session_id` (qr_sid) | **KEEP** | Core. The UUID that ties scan → future booking attribution. Even if we defer Cal.com integration, this costs nothing to generate and store now. |
| 3 | `scanned_at` | **KEEP** | Core. Timestamp is essential for any analytics. |
| 4 | `ip_address` | **KEEP** | Useful for debugging. Low cost. Could remove later if privacy is a concern, but you're the only user right now. |
| 5 | `ip_hash` | **KEEP** | Powers "unique scanners" metric in stats. Without it, you can only count total scans, not unique people. Worth it. |
| 6 | `user_agent` | **KEEP** | Tells you device type (iPhone vs Android vs desktop). Valuable to know if your flyer scanners are iOS or Android users. Low cost. |
| 7 | `accept_language` | **LOW VALUE** | Marginal. Tells you browser language. Not actionable for a US-focused SMB product. Keep for now (it's one line of code), but not worth worrying about if it's null. |
| 8 | `referrer` | **ALWAYS NULL for QR** | When someone scans a QR code, there's no HTTP referrer — it's a direct navigation. This will be null 99% of the time. Keep the column (zero cost) but don't expect data. |
| 9 | `request_id` | **LOW VALUE** | Debug-only field. Will be null unless you add a request ID middleware. Not important. |
| 10 | `vercel_ip_city` | **⚠️ DEAD WEIGHT** | Your API runs on ECS behind ALB, NOT behind Vercel's edge. These headers will **always be null**. |
| 11 | `vercel_ip_country` | **⚠️ DEAD WEIGHT** | Same — always null on ECS. |
| 12 | `vercel_ip_country_region` | **⚠️ DEAD WEIGHT** | Same — always null on ECS. |
| 13 | `vercel_ip_postal_code` | **⚠️ DEAD WEIGHT** | Same — always null on ECS. |
| 14 | `vercel_ip_timezone` | **⚠️ DEAD WEIGHT** | Same — always null on ECS. |
| 15 | `is_bot` | **KEEP** | Cheap check. Filters out Google/Bing crawlers that might hit your QR URLs if they're linked anywhere. |
| 16 | `landing_url` | **KEEP** | Stores the full redirect URL that was generated. Useful for debugging "did the UTMs get appended correctly?" |

**Summary:** 5 Vercel geo columns will always be null since your API isn't behind Vercel. Everything else is either essential or cheap enough to keep. No code changes needed for Phase 1 — just be aware those geo fields will be empty.

### 8.0a Should We Simplify?

**Verdict: No major simplification needed.** Here's why:

| Concern | Assessment |
|---------|------------|
| **Too many DB columns?** | No. 16 columns is normal for an analytics event table. The 5 Vercel geo columns are dead weight but harmless — a future migration could drop them or repurpose them for CloudFront geo headers if needed. |
| **Is rate limiting overcomplicated?** | No. It's 15 lines of code using `express-rate-limit` with in-memory store. Protects against someone accidentally refreshing the QR URL in a loop or a crawler hammering it. Costs nothing in complexity. Keep it. |
| **Is bot detection overcomplicated?** | No. It's a simple string match on user-agent. One function, no external dependencies. Keeps your scan counts clean. |
| **Is IP hashing overcomplicated?** | No. One line of HMAC-SHA256. Gives you "unique scanners" metric which is the difference between "100 scans" and "100 scans from 3 people." |
| **Is the qr_sid/cookie system overcomplicated?** | For Phase 1 (scan tracking only), the cookie is unnecessary. But it costs one line of code and will be useful when you add Cal.com attribution later. Leave it. |

**Bottom line:** The system is well-scoped. Don't remove anything. Just accept that the 5 Vercel geo columns will be null and move on to testing.

### 8.1 Prerequisites

- [ ] Staging API is running at `https://staging.api.callsaver.ai`
- [ ] Database migration for QR tables has been applied
- [ ] Seed data exists in staging database (or we create it)
- [ ] `QR_IP_HASH_SECRET` is set in staging secrets

### 8.2 Step 1: Verify QR Tables Exist in Staging DB

```bash
# Connect to staging database and check tables
# (via Prisma Studio or direct psql)
npx prisma studio
# → Verify qr_codes, qr_variants, qr_scan_events tables exist
```

### 8.3 Step 2: Seed Staging Data

Either run the seed script against staging, or create a variant manually. We need at minimum:
- 1 QR code campaign
- 1 variant with a known `short_code`

```bash
# Option A: Run seed script
DATABASE_URL="<staging-db-url>" npx tsx scripts/seed-qr-variants.ts

# Option B: Create via Prisma Studio manually
```

### 8.4 Step 3: Test via curl (from local machine)

```bash
# Basic scan — should return 302 redirect
curl -v https://staging.api.callsaver.ai/q/abc123

# Expected:
# < HTTP/2 302
# < location: /book?utm_source=qr_code&utm_medium=business_card&utm_campaign=...&qr_sid=<uuid>
# < set-cookie: qr_sid=<uuid>; ...
```

### 8.5 Step 4: Generate QR Code Image

```bash
# Use any QR code generator (online or CLI)
# URL to encode: https://staging.api.callsaver.ai/q/abc123
#
# Free options:
# - https://www.qrcode-monkey.com/
# - https://goqr.me/
# - CLI: npx qrcode -o qr-test.png "https://staging.api.callsaver.ai/q/abc123"
```

### 8.6 Step 5: Scan with Phone

1. Open your phone camera
2. Point at the QR code image on your screen
3. Tap the URL that appears
4. **You should be redirected** to the `/book` page on the staging API
5. Note the URL in your phone's browser — it should contain `qr_sid=`, `utm_source=`, etc.

### 8.7 Step 6: Verify Database Entry

```bash
# Open Prisma Studio or query the staging database
npx prisma studio
# → Open qr_scan_events table
# → Find the latest entry
```

**Check each field:**

| Field | Expected Value | Concern if Empty |
|-------|---------------|------------------|
| `qr_variant_id` | Links to your variant | ❌ BROKEN if empty |
| `session_id` | UUID like `a1b2c3d4-...` | ❌ BROKEN if empty |
| `scanned_at` | Recent timestamp | ❌ BROKEN if empty |
| `ip_address` | Your phone's IP or ALB IP | Might be ALB internal IP — check |
| `ip_hash` | 64-char hex string | Empty if `QR_IP_HASH_SECRET` not set |
| `user_agent` | Your phone's browser UA | Should have iPhone/Android string |
| `accept_language` | `en-US,...` or similar | May be null — not critical |
| `referrer` | **Expect null** | Normal for QR scans (direct navigation) |
| `request_id` | **Expect null** | Normal — no request ID middleware |
| `vercel_ip_city` | **Expect null** | Expected — API is on ECS, not Vercel |
| `vercel_ip_country` | **Expect null** | Expected |
| `vercel_ip_country_region` | **Expect null** | Expected |
| `vercel_ip_postal_code` | **Expect null** | Expected |
| `vercel_ip_timezone` | **Expect null** | Expected |
| `is_bot` | `false` | Should be false for a real phone scan |
| `landing_url` | Full redirect URL with UTMs | Shows the URL you were redirected to |

### 8.8 Step 7: Verify the Redirect Actually Works

After scanning, you should land on the `/book` page. Verify:
- [ ] The page loads (HTML with Cal.com embed)
- [ ] The URL bar in your phone browser shows the UTM params and `qr_sid`
- [ ] The Cal.com embed renders (even if you don't book)

### 8.9 What to Do With Results

**If everything works:** Phase 1 is complete. You have a working QR → scan → database pipeline. Next steps are:
1. Decide on your real variant plan (business card code, flyer codes)
2. Update seed script with production variants
3. Generate production QR codes
4. Order business cards and flyers

**If IP address is wrong (shows ALB internal IP):** The `extractClientIp` function may need to be updated to read `X-Forwarded-For` from ALB correctly. Check ALB settings.

**If `ip_hash` is empty:** `QR_IP_HASH_SECRET` isn't set in staging Secrets Manager.

**If scan event isn't created at all:** Check staging API logs for errors. The scan event is created asynchronously — an error might be silently swallowed.

---

## 9. Phase 2+ Testing (Deferred)

### 9.1 Unit Tests (run when needed)

```bash
npx vitest run tests/routes/qr-tracking.test.ts
npx vitest run tests/utils/qr-tracking-utils.test.ts
npx vitest run tests/routes/qr-variants-stats.test.ts
```

### 9.2 Cal.com Webhook Integration (separate from QR)

**Test 8: Cal webhook with qr_sid**
```bash
# First, scan to get a qr_sid
QR_SID=$(curl -s -o /dev/null -w "%{redirect_url}" http://localhost:3000/q/abc123 | grep -oP 'qr_sid=\K[^&]+')
echo "qr_sid: $QR_SID"

# Then simulate Cal.com webhook
curl -X POST http://localhost:3000/webhooks/cal/booking-created \
  -H "Content-Type: application/json" \
  -d '{
    "uid": "test-booking-001",
    "startTime": "2026-02-15T10:00:00Z",
    "attendees": [{"name": "Test User", "email": "test@example.com"}],
    "eventType": {"slug": "demo"},
    "metadata": {"qr_sid": "'$QR_SID'"},
    "responses": {}
  }'
```
**Expected:** `{ "success": true, "cal_booking_uid": "test-booking-001" }`

**Test 9: Verify attribution**
```bash
# Check cal_bookings table in Prisma Studio
# Verify: session_id matches qr_sid, qr_variant_id is set
```

### 8.6 Manual E2E Test — Stats

**Test 10: Get variant stats**
```bash
# Get variant ID from database (Prisma Studio or seed output)
VARIANT_ID="<paste-variant-a-id-here>"

curl -H "Authorization: Bearer <your-auth-token>" \
  http://localhost:3000/qr/variants/$VARIANT_ID/stats
```
**Expected:**
```json
{
  "variant_id": "...",
  "variant_key": "A",
  "scans": { "total": 1, "unique_scanners": 1 },
  "bookings": { "total": 1 },
  "conversion_rate": 100.00
}
```

### 8.7 Full E2E Test (Phone Scan Simulation)

This is the ultimate test — simulates what happens when someone scans your business card:

1. **Generate a QR code image** pointing to `http://localhost:3000/q/abc123` (use any QR generator)
2. **Scan with your phone** — should redirect to the `/book` page with UTMs
3. **Book a demo** through the Cal.com embed
4. **Check webhook** — verify the booking is recorded with `qr_sid` linked
5. **Check stats endpoint** — verify conversion shows up

### 8.8 Staging E2E Test

Same as above but using:
- Scan URL: `https://staging.api.callsaver.ai/q/abc123`
- Booking page: `https://staging.api.callsaver.ai/book`
- Webhook URL configured in Cal.com: `https://staging.api.callsaver.ai/webhooks/cal/booking-created`

---

## 9. Pre-Production Checklist

- [ ] Generate proper `QR_IP_HASH_SECRET` (`openssl rand -hex 32`)
- [ ] Add `QR_IP_HASH_SECRET` to AWS Secrets Manager for production
- [ ] Update seed script: new campaign name, branded short codes, full redirect URL
- [ ] Run seed script against production database
- [ ] Configure Cal.com hidden field `qr_sid` on `alexsikand/demo` event
- [ ] Configure Cal.com webhook pointing to production API
- [ ] Set `CAL_WEBHOOK_SECRET` in both Cal.com and Secrets Manager
- [ ] Verify `calLink` in `/book` endpoint works (with or without `https://cal.com/` prefix)
- [ ] Decide on geo header strategy (Vercel proxy vs CloudFront headers vs skip)
- [ ] Generate QR code images for business cards
- [ ] Print business cards with QR codes
- [ ] Run full E2E test on staging
- [ ] Run unit tests pass

---

## 10. Files Reference

| File | Purpose |
|------|---------|
| `src/server.ts:14340-14439` | QR scan endpoint `GET /q/:short_code` |
| `src/server.ts:14441-14552` | Cal webhook `POST /webhooks/cal/booking-created` |
| `src/server.ts:14554-14650` | Stats endpoint `GET /qr/variants/:id/stats` |
| `src/server.ts:14652-14780` | Booking page `GET /book` |
| `src/utils/qr-tracking.ts` | IP extraction, hashing, bot detection, URL building |
| `src/middleware/qr-rate-limit.ts` | Rate limiting (20 req/min per IP+variant) |
| `src/middleware/cal-webhook-auth.ts` | Cal webhook secret verification |
| `scripts/seed-qr-variants.ts` | Database seed script |
| `tests/routes/qr-tracking.test.ts` | Route-level tests |
| `tests/utils/qr-tracking-utils.test.ts` | Utility function tests |
| `tests/routes/qr-variants-stats.test.ts` | Stats endpoint tests |
| `prisma/schema.prisma` | QrCode, QrVariant, QrScanEvent, CalBooking models |
| `docs/archive/misc/QR_TRACKING.md` | Original documentation |
| `docs/archive/plans/qr-tracking-implementation-plan.md` | Implementation plan |
