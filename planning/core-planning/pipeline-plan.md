# Cal.com → Google Places → Enrichment Pipeline Plan

> **Date:** February 13, 2026
> **Status:** DRAFT — iterate before implementing
> **Goal:** Tie together `~/callsaver-api`, `~/lead-gen-production`, `~/callsaver-attio-crm-schema`, and `~/callsaver-crawl4ai` into one tight pipeline that handles both automatic (Cal.com booking) and manual (bulk lead upload) flows.

---

## Current State Summary

### What Exists Today

| Repo | Language | What It Does |
|------|----------|-------------|
| `~/callsaver-api` | TypeScript | Cal.com webhook at `POST /webhooks/cal/booking-created`. Extracts uid, QR session, UTMs, attendee name/email. Stores `rawPayload` JSON. Does **NOT** extract `businessNameAndLocation`, phone, scheduling software, or notes. Does **NOT** create Attio records. |
| `~/lead-gen-production` | Node.js | Google Places API text search across geographic locations (NorCal: 1,879 leads, San Diego: ~1,692 leads). Multi-category LLM classification. Transforms to Attio format. Has sitemap analysis + crawl target identification. |
| `~/callsaver-attio-crm-schema` | Node.js | Attio CRM schema (Company, Person, Deal). Bulk lead insertion with rate limiting. Company has: `google_place_id`, `lead_origin`, `s3_business_profile_json_url`, `enriched`, etc. `lead_origin` options include `website_calcom_booking`. |
| `~/callsaver-crawl4ai` | Python | Full pipeline: Attio fetch → link analysis → Crawl4AI crawling → GPT-4o schema extraction → S3 upload. 99.7% coverage (2,306/2,312 companies). Requires Crawl4AI Docker on `localhost:11235`. |

### Cal.com Booking Fields (from callsaver.ai landing page)

| Field Slug | Type | Required | Notes |
|-----------|------|----------|-------|
| `name` | Name | ✅ | Attendee full name |
| `email` | Email | ✅ | Attendee email |
| `businessNameAndLocation` | Short Text | ✅ | **KEY FIELD** — used for Google Places lookup |
| `attendeePhoneNumber` | Phone | Optional | Business or personal phone |
| `schedulingSoftware` | MultiSelect | Optional | Current scheduling tools they use |
| `notes` | Long Text | Optional | Additional context |
| `What is this meeting about?` | Short Text | Hidden | Pre-filled or auto-set |
| `QR Session ID` | Short Text | Hidden | Links to QR scan attribution |

### Cal.com Webhook Payload Structure

Cal.com sends custom question responses in `payload.responses` keyed by the question slug:
```json
{
  "uid": "cal-booking-abc123",
  "startTime": "2026-02-14T10:00:00Z",
  "attendees": [{ "name": "John Doe", "email": "john@acmeplumbing.com" }],
  "responses": {
    "name": { "value": "John Doe" },
    "email": { "value": "john@acmeplumbing.com" },
    "businessNameAndLocation": { "value": "Acme Plumbing, San Diego CA" },
    "attendeePhoneNumber": { "value": "+16195551234" },
    "schedulingSoftware": { "value": ["ServiceTitan", "Google Calendar"] },
    "notes": { "value": "Interested in AI answering service for after-hours calls" },
    "location": { "value": "..." }
  },
  "metadata": { "qr_sid": "..." }
}
```

### Attio Company Schema (relevant fields)

```
name, domains, description, address, phone_number, email
account_status (lead/customer)
lead_origin (website_calcom_booking / in_person / google_places_api)
google_place_id, google_place_url, google_place_last_synced
google_reviews_rating_v2, google_reviews_count, google_primary_type
google_pure_service_area_business
s3_business_profile_json_url, enriched
vapi_prompt, generator, og_description
utm_source, utm_medium, utm_campaign, utm_term, utm_content
notes
```

### Attio Person Schema (relevant fields)

```
name (first_name, last_name), emails, phone_numbers
company (record_reference → Company)
title, preferred_channel, notes
```

---

## The Two Flows

### Flow A: Automatic — Cal.com Booking → Full Pipeline

```
Cal.com booking webhook
  → callsaver-api extracts businessNameAndLocation + contact info
  → Creates/updates Attio Company (lead_origin: website_calcom_booking)
  → Creates/updates Attio Person (linked to Company)
  → Google Places Text Search using businessNameAndLocation
    → If match: update Company with google_place_id, rating, reviews, etc.
    → If no match: flag for manual review
  → (Future) Trigger website crawl + enrichment if domain found
```

### Flow B: Manual — Bulk Lead Generation + Upload

```
Run Google Places search (lead-gen-production)
  → Transform to Attio format
  → Upload to Attio (callsaver-attio-crm-schema)
  → Run crawl4ai pipeline (website crawl + LLM extraction)
  → Upload schemas to S3
  → Update Attio with S3 URLs + set enriched=true
```

### Flow C: Manual Google Place ID Entry

```
Manually enter google_place_id in Attio Company record
  → Script/API fetches Google Places Details for that ID
  → Updates Company with full Google data (address, phone, rating, reviews, website)
  → If website found: trigger crawl + enrichment
```

---

## Implementation Plan

### Phase 1: Enhance Cal.com Webhook (callsaver-api)

**Goal:** Extract ALL booking fields from the Cal.com webhook and create Attio records.

#### 1.1 Update CalBooking Prisma Model

Add new fields to store the extracted booking data:

```prisma
model CalBooking {
  // ... existing fields ...
  businessNameAndLocation  String?   @map("business_name_and_location")
  attendeePhoneNumber      String?   @map("attendee_phone_number")
  schedulingSoftware       String[]  @map("scheduling_software")
  bookingNotes             String?   @map("booking_notes")
  meetingSubject           String?   @map("meeting_subject")
  // Attio integration
  attioCompanyRecordId     String?   @map("attio_company_record_id")
  attioPersonRecordId      String?   @map("attio_person_record_id")
  googlePlaceId            String?   @map("google_place_id")
  pipelineStatus           String?   @map("pipeline_status") // pending, attio_created, places_searched, enriched, failed
}
```

#### 1.2 Update Webhook Handler

Extract `businessNameAndLocation`, `attendeePhoneNumber`, `schedulingSoftware`, `notes` from `payload.responses`:

```typescript
// Extract custom booking fields from responses
const responses = payload.responses || {};
const businessNameAndLocation = responses.businessNameAndLocation?.value || null;
const attendeePhoneNumber = responses.attendeePhoneNumber?.value || null;
const schedulingSoftware = responses.schedulingSoftware?.value || [];
const bookingNotes = responses.notes?.value || null;
const meetingSubject = responses['What is this meeting about?']?.value || null;
```

#### 1.3 Create Attio Service Module

New file: `src/services/attio.ts`

- `createOrUpdateCompany(data)` — Upsert Attio Company record
  - Use `domains` or `name` for matching
  - Set `lead_origin: website_calcom_booking`
  - Set `account_status: lead`
  - Pass UTM fields from the booking
- `createOrUpdatePerson(data, companyRecordId)` — Upsert Attio Person record
  - Link to Company via `company` field
  - Set name, email, phone from booking data

**Environment variables needed:**
- `ATTIO_API_KEY` — already exists in the API's AWS Secrets Manager

#### 1.4 Create Google Places Service Module

New file: `src/services/google-places.ts`

- `searchPlaces(query: string)` — Text search using `businessNameAndLocation`
  - Uses Google Places API (New): `POST https://places.googleapis.com/v1/places:searchText`
  - Returns top results with place_id, name, address, rating, reviews, website, phone
- `getPlaceDetails(placeId: string)` — Fetch full details for a known place_id
  - Uses: `GET https://places.googleapis.com/v1/places/{placeId}`
  - **Must use the same full field mask as the provisioning flow** (`src/utils.ts:4081-4110`): `id, name, displayName, addressComponents, formattedAddress, shortFormattedAddress, plusCode, location, viewport, reviews, rating, userRatingCount, reviewSummary, primaryType, primaryTypeDisplayName, types, photos, paymentOptions, regularOpeningHours, nationalPhoneNumber, internationalPhoneNumber, generativeSummary, websiteUri, pureServiceAreaBusiness, googleMapsLinks, googleMapsUri, iconBackgroundColor, iconMaskBaseUri`
  - **Structure the result** using the same `googlePlaceDetails` schema from `syncGooglePlaceDetails()` (`src/utils.ts:4263-4328`)
  - **Store to S3** at `s3://callsaver-company-website-extractions/{attioRecordId}/google_place_details.json` — this powers the demo pipeline (Phase 2.4) so leads get personalized voice agent demos even before they're provisioned
- `selectBestMatch(query: string, results: Place[])` — (Optional) Use LLM to select most accurate match if multiple results

**Environment variables needed:**
- `GOOGLE_API_KEY` — already in config schema and used by provisioning. Use the same key from `.env.staging` / AWS Secrets Manager.

**Decision point:** Should we auto-select the first result, or use an LLM to pick the best match? 

**Recommendation:** Start with first result (it's usually correct for specific business+location queries). Add LLM selection later if accuracy is an issue. Also store all results in the CalBooking raw data so we can review.

#### 1.5 Wire It All Together in the Webhook

After creating the CalBooking record:

```
1. Extract businessNameAndLocation from responses
2. If present:
   a. Create Attio Company (name parsed from businessNameAndLocation, lead_origin=website_calcom_booking)
   b. Create Attio Person (attendee name/email/phone, linked to Company)
   c. Google Places Text Search with businessNameAndLocation
   d. If match found:
      - Update Attio Company with google_place_id, google_place_url, rating, reviews, website domain, address, phone
      - Update CalBooking with google_place_id
   e. Update CalBooking with attioCompanyRecordId, attioPersonRecordId, pipelineStatus
3. Return 200 to Cal.com (webhook must respond quickly)
```

**Important:** The Attio + Google Places work should be done **asynchronously** (fire-and-forget or via a queue) so the webhook responds within Cal.com's timeout. Options:
- **Option A (simple):** `setImmediate()` / `process.nextTick()` — run after response is sent
- **Option B (robust):** SQS queue or BullMQ job — retry-friendly, better for production
- **Recommendation:** Start with Option A, move to Option B when volume warrants it

---

### Phase 2: Event-Driven Google Place Details Sync + Lead Profile Storage (callsaver-api)

**Goal:** When a `google_place_id` is set (either automatically from Phase 1 or manually entered in Attio), fetch the **full** Google Place Details — using the same field mask the `/provision` endpoint uses — and store it to S3. This data powers the **demo pipeline**: even though these leads are not provisioned users on the platform, we need the same rich data (hours, reviews, service area, phone, address, photos, etc.) to generate custom demo system prompts for voice agent demos during sales calls.

#### 2.1 Why This Matters

The provisioning flow (`src/services/provision-execution.ts`) calls `fetchGooglePlaceDetails()` and stores the result as `googlePlaceDetails` on a `Location` record. This structured data is used by `prompt-setup.ts` to:
- Build the **system prompt** for the voice agent (business name, hours, services, FAQs, service areas)
- Extract **timezone** from address components
- Match **service areas** against our cities/counties database
- Set up **brands serviced**, **discounts**, **estimate policies** from the S3 business profile

For leads (not yet customers), we don't have a `Location` record — but we still need this data to run a **custom demo** showing the lead what their AI agent would sound like.

#### 2.2 New API Endpoint: `POST /internal/enrich-lead`

```json
{
  "attioCompanyRecordId": "...",      // Required: Attio Company record ID
  "googlePlaceId": "ChIJ...",         // Optional: if not provided, search by company name+address
  "source": "manual" | "calcom_auto"  // How this enrichment was triggered
}
```

**This endpoint does:**

1. **Resolve Google Place ID:**
   - If `googlePlaceId` provided → use it directly
   - If not → fetch company name+address from Attio → Google Places Text Search → take best match

2. **Fetch Full Google Place Details** (same field mask as provisioning):
   ```
   id, name, displayName, addressComponents, formattedAddress,
   shortFormattedAddress, plusCode, location, viewport, reviews,
   rating, userRatingCount, reviewSummary, primaryType,
   primaryTypeDisplayName, types, photos, paymentOptions,
   regularOpeningHours, nationalPhoneNumber, internationalPhoneNumber,
   generativeSummary, websiteUri, pureServiceAreaBusiness,
   googleMapsLinks, googleMapsUri, iconBackgroundColor, iconMaskBaseUri
   ```
   This is the exact same field mask from `fetchGooglePlaceDetails()` in `src/utils.ts:4081-4110`.

3. **Structure the data** using the same `googlePlaceDetails` schema from `syncGooglePlaceDetails()` in `src/utils.ts:4263-4328`:
   ```json
   {
     "placeId": "ChIJ...",
     "syncedAt": "2026-02-13T...",
     "contact": { "nationalPhoneNumber", "internationalPhoneNumber" },
     "address": { "formatted", "shortFormatted", "components", "city", "county", "state", "zipCode", "country" },
     "location": { "latitude", "longitude" },
     "business": { "name", "displayName", "types", "primaryType", "rating", "userRatingCount", "reviewSummary", "photos", "website", "paymentOptions", "pureServiceAreaBusiness" },
     "maps": { "links", "uri", "iconBackgroundColor", "iconMaskBaseUri" },
     "hours": { "regularOpeningHours", "structured" },
     "reviews": [...],
     "generativeSummary": "..."
   }
   ```

4. **Store to S3** at `s3://callsaver-company-website-extractions/{attioRecordId}/google_place_details.json`
   - Same bucket used by crawl4ai for `schema.json` files
   - Lead profiles and provisioned-user profiles live side-by-side, keyed by Attio record ID

5. **Update Attio Company** with:
   - `google_place_id` (if newly resolved)
   - `google_place_url`
   - `google_place_last_synced`
   - `google_reviews_rating_v2`, `google_reviews_count`
   - `google_primary_type`
   - `google_pure_service_area_business`
   - `phone_number` (from internationalPhoneNumber)
   - `address` (from formattedAddress)
   - `domains` (extracted from websiteUri)
   - `s3_business_profile_json_url` → pointing to the S3 file

6. **Update CalBooking** (if triggered from Phase 1 webhook):
   - `googlePlaceId`, `pipelineStatus: "enriched"`

#### 2.3 Event-Driven Trigger: Attio Workflow

Attio has built-in Workflows that can trigger HTTP requests when records change. This is the ideal event-driven solution — no polling, no external tools.

**Workflow: "Google Place ID → Enrich Lead"**

1. **Trigger:** `Record updated` on the **Company** object, filtered to the `google_place_id` attribute
   - Fires whenever `google_place_id` is set or changed on any Company record
   - Provides the record's data + new/previous values as variables

2. **Condition (Filter):** `Updated record > google_place_id > is not empty`
   - Only continue if a Place ID was actually set (not cleared)

3. **Action: Send HTTP request**
   - **Method:** `POST`
   - **URL:** `https://staging.api.callsaver.ai/internal/enrich-lead` (swap to `api.callsaver.ai` for production)
   - **Headers:**
     - `Content-Type: application/json`
     - `Authorization: Bearer {INTERNAL_API_KEY}` (use the existing `INTERNAL_API_KEY` from config for auth)
   - **Body:**
     ```json
     {
       "attioCompanyRecordId": "{{Updated record > Record ID}}",
       "googlePlaceId": "{{Updated record > google_place_id > New value}}",
       "source": "attio_workflow"
     }
     ```

4. **(Optional) Parse JSON** on the response to extract status/error for logging

**This means:** You paste a Google Place ID into Attio → Attio fires the workflow → our API fetches full Place Details → stores to S3 → updates all Attio fields automatically. Zero manual steps after entering the Place ID.

**Also useful:** Attio's `Record command` trigger adds a **"Run workflow" button** to Company records. This gives you a manual "Enrich Now" button you can click on any Company record to trigger the same flow — useful for re-syncing or enriching companies that already have a `google_place_id`.

**Setup steps (in Attio UI):**
1. Go to Automations → Workflows → Create workflow
2. Add trigger: `Record updated` → Object: `Company` → Attribute: `google_place_id`
3. Add condition: `Filter` → `Updated record > google_place_id > is not empty`
4. Add action: `Send HTTP request` → configure as above
5. Publish the workflow

**Second workflow (optional): "Manual Enrich" button**
1. Add trigger: `Record command` → Object: `Company`
2. Add action: `Send HTTP request` → same config but use `Updated record > google_place_id` (current value, not new value)
3. Publish — now every Company record has a "Run workflow" button

#### 2.4 Demo Pipeline Integration

With the Google Place Details stored in S3, the demo pipeline can:

1. **Fetch the lead's profile** from `s3://.../google_place_details.json`
2. **Generate a demo system prompt** using the same `generateSystemPrompt()` logic from `prompt-setup.ts` — business name, hours, phone, service areas, reviews
3. **Optionally combine with crawl4ai data** (if `schema.json` also exists for this record) — services, FAQs, brands, estimate policies
4. **Spin up a temporary LiveKit agent** with the custom prompt for the demo call

This means every lead gets a **personalized demo** even though they're not a provisioned user.

#### 2.5 Batch Enrichment Script

New script in `~/callsaver-api/scripts/enrich-leads.ts`:

```
1. Query Attio for Companies where:
   - google_place_id is set BUT s3_business_profile_json_url is empty
   - OR google_place_id is empty AND lead_origin = website_calcom_booking
2. For each: call POST /internal/enrich-lead
3. Rate limit to respect Google Places API quotas (stay under 25 QPS)
4. Log results + failed records for retry
```

---

### Phase 3: Website Crawling + Schema Extraction

**Goal:** Crawl company websites and extract structured business profiles.

#### 3.1 Crawl4AI Infrastructure Decision

**Current:** Crawl4AI runs in Docker on `localhost:11235`. This works for local batch processing but not for production webhook-triggered crawls.

**Options:**
| Option | Cost | Latency | Reliability |
|--------|------|---------|-------------|
| **Local Docker** (current) | Free | Low | Only when machine is on |
| **EC2 instance** (t3.small) | ~$15/mo | Low | Always on |
| **ECS Fargate task** (on-demand) | Pay per use | High (cold start) | Auto-scaling |
| **Skip crawling for Cal.com leads** | Free | N/A | N/A |

**Recommendation:** For now, **skip automatic crawling for Cal.com leads**. The Google Places data (rating, reviews, phone, website, address) is sufficient for the initial demo/qualification call. Website crawling can be done as a **batch process** later (run locally or on EC2 when needed).

For the existing bulk pipeline (Flow B), keep using local Docker. If you need always-on crawling, spin up a `t3.small` EC2 (~$15/mo).

#### 3.2 Batch Enrichment Pipeline (existing, needs consolidation)

The existing crawl4ai pipeline already works well:
1. `01_fetch_attio_data.py` — fetch companies from Attio
2. `02_calculate_link_stats.py` — analyze links
3. `03_process_universal_links.py` — filter relevant URLs
4. `04_crawl_websites.py` — crawl via Crawl4AI Docker
5. `05_extract_schemas.py` — GPT-4o extraction to `business_schema.json`
6. `06_upload_to_s3.py` — upload to `callsaver-company-website-extractions/{record_id}/schema.json`

**What's needed:** A simple runner script that ties these together for newly added companies (e.g., just the ones where `enriched=false`).

---

### Phase 4: Pipeline Consolidation

**Goal:** Make it easy to run the full pipeline from one place.

#### 4.1 Recommended Folder Structure

Keep the repos separate but create a **runner script** in `~/callsaver-api` (or a new `~/callsaver-pipeline` folder) that orchestrates:

```
~/callsaver-api/
  src/services/attio.ts          # NEW: Attio API client
  src/services/google-places.ts  # NEW: Google Places API client
  scripts/
    enrich-companies.ts          # NEW: Batch Google Places enrichment
    
~/lead-gen-production/           # KEEP AS-IS: Bulk lead generation
  src/fetch_places.js            # Google Places text search
  src/transform_to_attio.js      # Transform to Attio format
  
~/callsaver-attio-crm-schema/   # KEEP AS-IS: Schema + bulk insert
  scripts/insert_unified_leads.js
  
~/callsaver-crawl4ai/           # KEEP AS-IS: Website crawl + extraction
  src/01-06 pipeline scripts
```

#### 4.2 Shared Configuration

The Google Places API key is used in both `lead-gen-production` and `callsaver-api`. Currently:
- `lead-gen-production`: in `.env` as `GOOGLE_PLACES_API_KEY`
- `callsaver-api`: has `GOOGLE_MAPS_API_KEY` in config (for frontend Maps features)

**Action:** Ensure the same API key works for both Places Text Search and Places Details.

The Attio API key is used in:
- `callsaver-attio-crm-schema`: in `.env` as `ATTIO_API_KEY`
- `callsaver-crawl4ai`: in `.env` as `ATTIO_ACCESS_TOKEN`
- `callsaver-api`: needs to be added (for webhook → Attio integration)

---

## Implementation Priority

### Must Do (Phase 1 — this sprint)

1. **Update Cal.com webhook** to extract `businessNameAndLocation`, `attendeePhoneNumber`, `schedulingSoftware`, `notes` from `payload.responses`
2. **Add Attio service** to `callsaver-api` — create Company + Person from booking data
3. **Add Google Places service** to `callsaver-api` — search by `businessNameAndLocation`, return place details
4. **Wire webhook → Attio + Google Places** (async, after returning 200)
5. **Update CalBooking Prisma schema** with new fields
6. **Test end-to-end** with a real Cal.com booking from callsaver.ai

### Should Do (Phase 2 — next sprint)

7. **Manual enrichment endpoint** (`POST /internal/enrich-company`) for entering google_place_id
8. **Batch enrichment script** for existing Attio companies without Google Places data
9. **Run crawl4ai pipeline** on new Cal.com leads that have websites

### Nice to Have (Phase 3+)

10. **LLM-based match selection** for Google Places results
11. **EC2 Crawl4AI** for always-on website crawling
12. **Queue-based pipeline** (SQS/BullMQ) for robust async processing
13. **Consolidate repos** into monorepo or better orchestration

---

## Open Questions — RESOLVED

1. **Cal.com webhook URL:** ✅ Not yet configured. User will configure Cal.com to point at `https://staging.api.callsaver.ai/webhooks/cal/booking-created` manually.

2. **Cal.com response field names:** ⚠️ Still need to verify. Trigger a test booking and inspect `rawPayload` in the DB to confirm the exact keys in `payload.responses`.

3. **Google Places API key:** ✅ Use `GOOGLE_MAPS_API_KEY` from the API's `.env.staging` / AWS Secrets Manager. Same key is stored in both places for consistency (local dev + deployed).

4. **Attio API key for the API:** Need to add `ATTIO_API_KEY` to AWS Secrets Manager for staging. Use the same key as `callsaver-attio-crm-schema`.

5. **Duplicate handling:** Still TBD. Start with Attio's built-in domain matching. If no domain (Cal.com bookings), match by `google_place_id` after Places lookup.

6. **What Cal.com webhooks to listen to?** ✅ Only `booking-created` for now. No need for cancelled/rescheduled at this time.

---

## ⚠️ Staging → Production Migration Checklist

**This pipeline is being built on staging first.** Before production launch, the following must happen:

- [ ] Cal.com webhook URL: Update from `staging.api.callsaver.ai` → `api.callsaver.ai`
- [ ] AWS Secrets Manager: Ensure `ATTIO_API_KEY` and `GOOGLE_MAPS_API_KEY` are in production secrets
- [ ] Verify Google Places API key works in production environment
- [ ] Test full flow end-to-end on production (booking → Attio → Places → enrichment)
- [ ] Update `CAL_WEBHOOK_SECRET` in production environment
- [ ] Review Attio rate limits for production volume

---

## Cost Estimates

| Service | Usage | Cost |
|---------|-------|------|
| Google Places Text Search | ~$0.032 per request (SKU: Text Search) | ~$3.20 per 100 bookings |
| Google Places Details | ~$0.017 per request (Basic) | ~$1.70 per 100 lookups |
| Attio API | Free tier (25 writes/sec limit) | $0 |
| OpenAI GPT-4o (schema extraction) | ~$0.01-0.03 per company | ~$3 per 100 companies |
| Crawl4AI (self-hosted Docker) | Free (local) or ~$15/mo (EC2) | $0-15/mo |
| S3 storage | Negligible for JSON files | ~$0.01/mo |

**Total for 100 Cal.com bookings:** ~$5 (Google Places only, no crawling)
**Total for 100 companies with full crawl:** ~$8 (Places + extraction)

---

## Diagram

```
                        ┌─────────────────────────┐
                        │   callsaver.ai landing   │
                        │   Cal.com booking form   │
                        └──────────┬──────────────┘
                                   │ webhook
                                   ▼
                        ┌─────────────────────────┐
                        │    callsaver-api         │
                        │                          │
                        │  1. Store CalBooking     │
                        │  2. Extract fields:      │
                        │     - businessNameAndLoc  │
                        │     - phone, email, name │
                        │  3. Return 200           │
                        │                          │
                        │  (async after response): │
                        │  4. Create Attio Company │
                        │  5. Create Attio Person  │
                        │  6. Google Places search │
                        │  7. Update Attio w/ data │
                        └──────────┬──────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
             ┌──────────┐  ┌──────────┐  ┌──────────────┐
             │  Attio   │  │  Google  │  │  S3 bucket   │
             │   CRM    │  │  Places  │  │  (profiles)  │
             │          │  │   API    │  │              │
             └──────────┘  └──────────┘  └──────────────┘
                    ▲                           ▲
                    │                           │
             ┌──────────────────────────────────┘
             │  (batch, later)
             │
      ┌──────┴──────────────┐
      │  callsaver-crawl4ai │
      │  Website crawl +    │
      │  LLM extraction +   │
      │  S3 upload          │
      └─────────────────────┘


   MANUAL FLOW (separate):
   
   lead-gen-production          attio-crm-schema          crawl4ai
   ┌─────────────────┐         ┌──────────────────┐      ┌─────────────┐
   │ Google Places    │───────▶│ Insert leads to  │─────▶│ Crawl +     │
   │ bulk search     │  attio  │ Attio CRM        │      │ Extract +   │
   │ + transform     │  format │                  │      │ S3 upload   │
   └─────────────────┘         └──────────────────┘      └─────────────┘
```
