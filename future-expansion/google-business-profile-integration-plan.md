# Google Business Profile Integration — Cross-Vertical Core Platform Capability

> **Date:** 2026-02-24  
> **Status:** Strategic Planning  
> **Scope:** Integrate Google Business Profile (GBP) APIs as a universal, vertical-agnostic capability for all businesses on the CallSaver platform  
> **Reference:** [Multi-Vertical Architecture Evolution](./multi-vertical-architecture-evolution.md)

---

## Table of Contents

1. [Strategic Rationale](#1-strategic-rationale)
2. [API Landscape — What Google Offers](#2-api-landscape--what-google-offers)
3. [What We Already Have](#3-what-we-already-have)
4. [Architecture — GBP as a Core Module](#4-architecture--gbp-as-a-core-module)
5. [Authentication & Onboarding Flow](#5-authentication--onboarding-flow)
6. [Feature Modules](#6-feature-modules)
7. [Database Schema](#7-database-schema)
8. [Backend Implementation](#8-backend-implementation)
9. [Voice Agent Integration](#9-voice-agent-integration)
10. [Frontend — GBP Dashboard](#10-frontend--gbp-dashboard)
11. [Cross-Vertical Value Matrix](#11-cross-vertical-value-matrix)
12. [Implementation Phases](#12-implementation-phases)
13. [API Access & Compliance](#13-api-access--compliance)

---

## 1. Strategic Rationale

### Why Google Business Profile is the universal wedge

Every local business — regardless of vertical — has a Google Business Profile. It is the single most important digital presence for local businesses, driving:
- **Discovery**: 46% of all Google searches have local intent
- **Trust**: Reviews on Google are the #1 factor consumers use to evaluate a local business
- **Conversion**: Businesses with complete GBP profiles get 7x more clicks
- **Calls**: "Click to call" from Google Maps/Search is a primary call source

### Why this is a core platform capability, not a vertical feature

| Vertical | Uses GBP? | Key GBP features |
|---|---|---|
| **Field Service** (HVAC, plumbing, electrical) | Yes | Reviews, services list, posts, hours, service area |
| **Legal** (law firms) | Yes | Reviews, posts, practice areas, hours |
| **Wellness** (salons, spas, fitness) | Yes | Reviews, services, booking links, posts, photos |
| **Automotive** (repair shops) | Yes | Reviews, services, posts, hours |
| **Hospitality** (hotels, restaurants) | Yes | Reviews, menu/offerings, posts, photos, hours |
| **Property Management** | Yes | Reviews, hours, posts |
| **Booking** (any appointment business) | Yes | Reviews, booking links, hours |

**GBP applies to 100% of our target verticals.** It belongs in `src/core/`, not in any vertical-specific module.

### The competitive moat

Most vertical SaaS platforms (Jobber, Housecall Pro, Vagaro, etc.) do NOT manage their customers' Google Business Profiles. By offering GBP management as a built-in feature, we:
1. **Increase stickiness** — businesses see tangible value beyond call handling
2. **Create a data loop** — call data → review solicitation → better ratings → more calls
3. **Justify higher ARPU** — GBP management is a premium upsell ($20-50/mo on its own)
4. **Build the replacement case** — "Why use 3 tools when CallSaver does it all?"

---

## 2. API Landscape — What Google Offers

Google's Business Profile APIs are split across multiple services:

### 2.1 My Business Business Information API
**Purpose:** Manage location data (CRUD), services, attributes, categories  
**Base URL:** `https://mybusinessbusinessinformation.googleapis.com/v1`  
**Key endpoints:**
- `accounts.locations.create` / `locations.get` / `locations.patch` / `locations.delete`
- `locations.updateAttributes` — set WhatsApp URL, text messaging URL, booking links
- `categories.list` — discover Google's predefined service categories
- `locations.patch?updateMask=serviceItems` — set structured/free-form services

### 2.2 My Business Account Management API
**Purpose:** Manage accounts, location groups, admins, invitations  
**Base URL:** `https://mybusinessaccountmanagement.googleapis.com/v1`  
**Key endpoints:**
- `accounts.list` — list accounts for authenticated user
- `accounts.locations.list` — list locations under an account
- `locations.transfer` — transfer location ownership
- `accounts.admins.create` / `accounts.invitations.accept`

### 2.3 My Business Verifications API
**Purpose:** Verify business locations (postcard, phone, SMS, email)  
**Base URL:** `https://mybusinessverifications.googleapis.com/v1`  
**Key endpoints:**
- `locations.getVoiceOfMerchantState` — check if location is verified
- `locations.fetchVerificationOptions` — get available verification methods
- `locations.verify` — initiate verification
- `locations.verifications.complete` — complete with PIN

### 2.4 My Business API v4 (Legacy but active)
**Purpose:** Reviews, posts, insights, media, Q&A  
**Base URL:** `https://mybusiness.googleapis.com/v4`  
**Key endpoints:**
- `accounts.locations.reviews.list` / `.get` / `.updateReply`
- `accounts.locations.localPosts` — create/edit/delete posts (Event, CTA, Offer)
- `accounts.locations.reportInsights` — search queries, driving directions, actions
- `accounts.locations.media` — manage photos
- `accounts.locations.batchGetReviews` — multi-location review fetch

### 2.5 My Business Notifications API
**Purpose:** Real-time notifications via Cloud Pub/Sub  
**Key events:** `GOOGLE_UPDATE` (location changes), `NEW_REVIEW`, `UPDATED_REVIEW`

### 2.6 Key Constraints
- **OAuth 2.0 required** — business owner must authenticate and grant access
- **API access requires approval** — must apply at https://developers.google.com/my-business/content/prereqs
- **Rate limits apply** — varies by endpoint
- **Verification required for Search/Maps visibility** — unverified locations can still be used in Ads
- **Service list updates replace the whole list** — no individual service CRUD
- **Product posts cannot be created via API** — only Event, CTA, and Offer posts

---

## 3. What We Already Have

The codebase already has a rich foundation for GBP integration:

### 3.1 Google Places API (New) — Read-Only Enrichment

| Existing Function | File | What it does |
|---|---|---|
| `fetchGooglePlaceDetails()` | `src/utils.ts:4425` | Fetches full place data (address, hours, reviews, rating, photos, etc.) |
| `syncGooglePlaceDetails()` | `src/utils.ts:4521` | Saves structured place data to `Location.googlePlaceDetails` JSON |
| `searchGooglePlaces()` | `src/services/cal-booking-pipeline.ts:75` | Text Search to find Place IDs for leads |
| `getGooglePlaceId()` | `src/utils.ts:706` | Extracts Place ID from Attio company record |

### 3.2 Data Already Stored Per Location

The `Location.googlePlaceDetails` JSON column already contains:

```json
{
  "placeId": "ChIJ...",
  "syncedAt": "2026-02-20T...",
  "contact": { "nationalPhoneNumber": "...", "internationalPhoneNumber": "..." },
  "address": { "formatted": "...", "city": "...", "state": "...", "zipCode": "..." },
  "location": { "latitude": 37.7749, "longitude": -122.4194 },
  "business": {
    "name": "...", "displayName": "...",
    "types": ["plumber", "..."],
    "primaryType": "plumber",
    "rating": 4.7, "userRatingCount": 142,
    "reviewSummary": "...",
    "website": "https://...",
    "pureServiceAreaBusiness": false
  },
  "hours": { "regularOpeningHours": { "periods": [...] } },
  "reviews": [{ "name": "...", "rating": 5, "comment": "...", "createTime": "..." }],
  "generativeSummary": "..."
}
```

### 3.3 The Gap: Read vs. Write

**What we have (Google Places API):** Read-only snapshot of public data. Cannot modify anything.

**What GBP APIs add:** Full read/write management of the business's profile, including:
- Reply to reviews
- Create/edit posts
- Update hours, services, attributes
- View performance insights
- Manage verification
- Set WhatsApp/text messaging URLs
- Sync service catalog to Google

**The bridge:** We already have the Place ID for every location. The GBP APIs use the same location identifier (converted via `googleLocations.search`). So connecting GBP management is a natural extension of what we already do.

---

## 4. Architecture — GBP as a Core Module

Per the [multi-vertical architecture evolution plan](./multi-vertical-architecture-evolution.md), GBP belongs in `src/core/` because it's vertical-agnostic.

```
src/
  core/
    gbp/                                    ← NEW: Google Business Profile module
      GbpClient.ts                          ← HTTP client for all GBP APIs
      GbpService.ts                         ← Business logic layer
      types.ts                              ← GBP-specific types
      sync/
        ReviewSyncService.ts                ← Periodic review fetch + notification handling
        InsightsSyncService.ts              ← Periodic insights fetch
        LocationSyncService.ts              ← Bidirectional location data sync
      actions/
        ReviewReplyService.ts               ← AI-generated + manual review replies
        PostService.ts                      ← Create/manage Google posts
        ServiceListSyncService.ts           ← Sync service catalog to GBP
        VerificationService.ts              ← Guide businesses through verification
      routes/
        gbp-routes.ts                       ← REST API endpoints for GBP features
        gbp-internal-tools.ts              ← Voice agent tool endpoints

  routes/
    field-service-tools.ts                  ← Existing (unchanged)
    gbp-tools.ts                           ← NEW: Voice agent GBP tool endpoints

livekit-python/
  tools/
    definitions/
      gbp.py                               ← NEW: GBP voice agent tool definitions
```

### Why NOT an adapter?

GBP is NOT a vertical adapter (like Jobber or HCP). It's a **cross-cutting concern** that sits alongside every vertical:

```
Organization
  ├── Vertical: "field-service"
  │     └── Adapter: JobberAdapter (or HCP, SF, CRM)
  │
  ├── Google Business Profile: GbpService          ← ALWAYS available
  │     ├── Reviews, Posts, Insights, Services
  │     └── Location data sync
  │
  └── Google Calendar: CalendarAdapter              ← Optional scheduling layer
```

A field-service business uses Jobber for jobs AND GBP for reviews/posts.  
A law firm uses Clio for matters AND GBP for reviews/posts.  
A salon uses Vagaro for appointments AND GBP for reviews/posts.

**GBP is the one integration every business needs, regardless of vertical.**

---

## 5. Authentication & Onboarding Flow

### 5.1 OAuth 2.0 via Pipedream Connect

GBP APIs require OAuth 2.0 with the business owner's Google account. We already use Pipedream Connect for Google Calendar OAuth. GBP uses the same Google OAuth flow with additional scopes.

**Required scopes:**
```
https://www.googleapis.com/auth/business.manage
```

This single scope covers all GBP APIs (Business Information, Account Management, Verifications, Reviews, Posts, Insights).

**Pipedream integration:**
- App slug: `google_my_business` (or custom OAuth app)
- OAuth app ID: to be created in Pipedream
- Stored in: `IntegrationConnection` table (same as Google Calendar)

### 5.2 Onboarding Flow

```
1. User clicks "Connect Google Business Profile" on Integrations page
2. Pipedream Connect opens Google OAuth consent screen
3. User authenticates with their Google account (same one that owns GBP)
4. On callback:
   a. Store OAuth tokens in IntegrationConnection
   b. Call accounts.list to get GBP accounts
   c. Call accounts.locations.list to get locations
   d. Match GBP location to our Location record (by Place ID or address)
   e. Store GBP account ID + location ID mapping
   f. Initial sync: fetch reviews, insights, current services
   g. Check verification status
```

### 5.3 Location Matching

We already have the Google Place ID for each location (from provisioning). The GBP API's `googleLocations.search` endpoint can match by business name + address. We can also match by comparing the Place ID from our `Location.googlePlaceDetails.placeId` with the GBP location's `locationId`.

```typescript
// Pseudocode: match our Location to GBP location
async function matchGbpLocation(location: Location, gbpLocations: GbpLocation[]) {
  const ourPlaceId = location.googlePlaceDetails?.placeId;
  
  // Strategy 1: Direct Place ID match
  for (const gbpLoc of gbpLocations) {
    if (gbpLoc.metadata?.mapsUri?.includes(ourPlaceId)) {
      return gbpLoc;
    }
  }
  
  // Strategy 2: Address + name fuzzy match
  for (const gbpLoc of gbpLocations) {
    if (fuzzyMatch(gbpLoc.title, location.name) && 
        addressMatch(gbpLoc.storefrontAddress, location.googlePlaceDetails?.address)) {
      return gbpLoc;
    }
  }
  
  return null; // No match — user must select manually
}
```

---

## 6. Feature Modules

### 6.1 Review Management (HIGH PRIORITY)

**Capabilities:**
- Fetch all reviews for a location
- Get reviews across multiple locations (batch)
- Reply to reviews (manual or AI-generated)
- Delete review replies
- Track review trends over time
- Real-time new review notifications via Pub/Sub

**API endpoints used:**
```
GET  /v4/accounts/{id}/locations/{id}/reviews          → List all reviews
GET  /v4/accounts/{id}/locations/{id}/reviews/{id}     → Get specific review
POST /v4/accounts/{id}/locations:batchGetReviews        → Multi-location reviews
PUT  /v4/accounts/{id}/locations/{id}/reviews/{id}/reply → Reply to review
DELETE /v4/accounts/{id}/locations/{id}/reviews/{id}/reply → Delete reply
```

**AI Review Reply:**
One of the biggest value-adds. When a new review comes in:
1. Classify sentiment (positive/negative/neutral)
2. Generate a personalized reply using the business's tone/voice
3. Present to business owner for approval (or auto-post if enabled)
4. Track response rate and average response time

```typescript
// Example AI review reply generation
async function generateReviewReply(review: GbpReview, businessContext: BusinessContext): Promise<string> {
  const prompt = `You are a ${businessContext.verticalDisplayName} business owner.
    Business: ${businessContext.businessName}
    Review rating: ${review.starRating}/5
    Review text: "${review.comment}"
    Reviewer: ${review.reviewer.displayName}
    
    Write a warm, professional reply. If positive, thank them and mention what they liked.
    If negative, apologize and offer to make it right. Keep it under 150 words.`;
  
  return await llm.generate(prompt);
}
```

**Review Solicitation (Post-Call):**
After a successful service call, automatically send a review request:
1. Voice agent completes call → call record logged
2. If call had positive outcome (appointment booked, service scheduled)
3. Wait N hours/days (configurable)
4. Send SMS with review link: `https://search.google.com/local/writereview?placeid={placeId}`

This creates the **data flywheel**: better call handling → more satisfied customers → more positive reviews → higher Google ranking → more calls → more revenue.

### 6.2 Google Posts (MEDIUM PRIORITY)

**Capabilities:**
- Create Event posts (seasonal promotions, open houses)
- Create Call-to-Action posts (Book, Order, Shop, Learn More, Sign Up, Call)
- Create Offer posts (coupons, discounts with terms & conditions)
- Edit and delete existing posts
- Track post performance

**API endpoints used:**
```
POST   /v4/accounts/{id}/locations/{id}/localPosts     → Create post
PATCH  /v4/accounts/{id}/locations/{id}/localPosts/{id} → Edit post
DELETE /v4/accounts/{id}/locations/{id}/localPosts/{id} → Delete post
GET    /v4/accounts/{id}/locations/{id}/localPosts      → List posts
```

**CTA action types:** `BOOK`, `ORDER`, `SHOP`, `LEARN_MORE`, `SIGN_UP`, `CALL`

**Cross-vertical post templates:**

| Vertical | Post Type | Example |
|---|---|---|
| **Field Service** | Offer | "Spring HVAC tune-up — $79 (reg. $129). Book now!" |
| **Legal** | CTA (CALL) | "Free 15-minute consultation for personal injury cases" |
| **Wellness** | Offer | "New client special: 20% off first visit. Use code WELCOME20" |
| **Automotive** | Offer | "Free brake inspection with any oil change this month" |
| **Hospitality** | Event | "Live jazz every Friday night. Reserve your table!" |
| **Restaurant** | CTA (ORDER) | "Order our new summer menu online!" |

**AI Post Generation:**
Generate weekly posts based on:
- Business vertical and services
- Seasonal relevance
- Past post performance
- Local events/weather

### 6.3 Business Insights Dashboard (MEDIUM PRIORITY)

**Capabilities:**
- Search query metrics (direct vs. discovery vs. branded)
- Customer actions (website visits, direction requests, phone calls, messages)
- Photo views and engagement
- Driving direction requests by origin area
- Trends over time (weekly/monthly/quarterly)

**API endpoints used:**
```
POST /v4/accounts/{id}/locations:reportInsights
  → basicRequest: QUERIES_DIRECT, QUERIES_INDIRECT, QUERIES_CHAIN
  → basicRequest: VIEWS_MAPS, VIEWS_SEARCH
  → basicRequest: ACTIONS_WEBSITE, ACTIONS_PHONE, ACTIONS_DRIVING_DIRECTIONS
  → drivingDirectionsRequest: numDays=NINETY
```

**Dashboard value:**
This is DATA that businesses currently can only see by logging into Google Business Profile directly. Surfacing it in our dashboard means:
- Businesses spend more time in our app
- We can correlate GBP metrics with call volume
- We can show ROI: "Your Google calls increased 34% since joining CallSaver"

### 6.4 Service Catalog Sync (HIGH PRIORITY)

**Capabilities:**
- List predefined Google service types for the business's category
- Set services on the business's Google profile
- Support both structured (Google-defined) and free-form (custom) services
- Bidirectional sync: our service catalog → Google, or Google → our catalog

**API endpoints used:**
```
GET   /v1/categories?filter=displayname={name}&view=FULL   → List predefined services
GET   /v1/locations/{id}?readMask=serviceItems              → Get current services
PATCH /v1/locations/{id}?updateMask=serviceItems             → Set all services
```

**Key constraint:** Updating services replaces the entire list. No individual service add/remove.

**Sync strategy:**
```
Location.services (our DB) ←→ GBP serviceItems
  ┌──────────────────────────────────────────────┐
  │ 1. Fetch Google's predefined services for    │
  │    the business's category (e.g., "plumber") │
  │ 2. Match our services to Google's IDs        │
  │ 3. For services without a Google match,       │
  │    create FreeFormServiceItem entries         │
  │ 4. Push the combined list to GBP             │
  └──────────────────────────────────────────────┘
```

This means when a business updates their service menu in our app, it automatically reflects on Google Search/Maps.

### 6.5 Location Data Management (LOW PRIORITY initially)

**Capabilities:**
- Update business hours (sync from our system → Google)
- Update phone number, website URL
- Update business description
- Set WhatsApp and text messaging URLs
- Accept/reject Google-suggested updates
- Monitor for Google-initiated changes via Pub/Sub

**API endpoints used:**
```
PATCH /v1/locations/{id}?updateMask=title,regularHours,...     → Update location
PATCH /v1/locations/{id}/attributes?attributeMask=url_whatsapp → Set WhatsApp URL
PATCH /v1/locations/{id}/attributes?attributeMask=url_text_messaging → Set SMS URL
GET   /v1/locations/{id}?readMask=...                          → Get location data
```

**WhatsApp/SMS integration opportunity:**
We provision phone numbers for businesses. We can set the business's CallSaver number as the text messaging URL on Google, so customers who text from Google go through our system too.

```typescript
// Auto-set text messaging URL to our provisioned number
await gbpClient.updateAttributes(gbpLocationId, {
  attributeMask: 'attributes/url_text_messaging',
  attributes: [{
    name: 'attributes/url_text_messaging',
    uriValues: [{ uri: `sms:${provisionedPhoneNumber}` }]
  }]
});
```

### 6.6 Verification Management (LOW PRIORITY)

**Capabilities:**
- Check if a location is verified
- Fetch verification options (postcard, phone, SMS, email)
- Initiate verification process
- Complete verification with PIN

Many businesses on our platform may already be verified. For those that aren't, we can guide them through verification directly in our app instead of requiring them to go to the Google Business Profile UI.

### 6.7 Google Ads Integration (FUTURE)

**Capabilities:**
- Sync GBP locations to Google Ads for location extension ads
- Use labels to associate locations with specific ad campaigns
- Manage unverified locations for Ads purposes

This is a future premium feature for businesses that run Google Ads. We can offer a unified "Google presence management" experience.

---

## 7. Database Schema

### 7.1 New Tables

```prisma
// Google Business Profile connection per location
model GbpConnection {
  id                 String   @id @default(cuid())
  locationId         String   @unique @map("location_id")
  organizationId     String   @map("organization_id")
  
  // GBP identifiers
  gbpAccountId       String   @map("gbp_account_id")       // "accounts/12345"
  gbpLocationId      String   @map("gbp_location_id")      // "locations/67890"
  gbpLocationName    String?  @map("gbp_location_name")     // Display name on Google
  
  // Verification status
  isVerified         Boolean  @default(false) @map("is_verified")
  verificationMethod String?  @map("verification_method")   // "PHONE_CALL", "EMAIL", etc.
  
  // Sync state
  lastReviewSync     DateTime? @map("last_review_sync")
  lastInsightsSync   DateTime? @map("last_insights_sync")
  lastServiceSync    DateTime? @map("last_service_sync")
  lastLocationSync   DateTime? @map("last_location_sync")
  
  // Feature flags per connection
  autoReplyEnabled    Boolean @default(false) @map("auto_reply_enabled")
  autoPostEnabled     Boolean @default(false) @map("auto_post_enabled")
  serviceSyncEnabled  Boolean @default(true) @map("service_sync_enabled")
  reviewSolicitationEnabled Boolean @default(false) @map("review_solicitation_enabled")
  
  createdAt          DateTime @default(now()) @map("created_at")
  updatedAt          DateTime @updatedAt @map("updated_at")
  
  // Relations
  location           Location     @relation(fields: [locationId], references: [id], onDelete: Cascade)
  organization       Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  reviews            GbpReview[]
  posts              GbpPost[]
  insightSnapshots   GbpInsightSnapshot[]
  
  @@index([organizationId])
  @@map("gbp_connections")
}

// Cached reviews with our metadata
model GbpReview {
  id                String   @id @default(cuid())
  gbpConnectionId   String   @map("gbp_connection_id")
  
  // Google's review data
  googleReviewId    String   @map("google_review_id")      // "accounts/.../reviews/..."
  reviewerName      String   @map("reviewer_name")
  reviewerPhotoUrl  String?  @map("reviewer_photo_url")
  starRating        Int      @map("star_rating")            // 1-5
  comment           String?
  reviewTime        DateTime @map("review_time")
  
  // Reply data
  replyComment      String?  @map("reply_comment")
  replyTime         DateTime? @map("reply_time")
  replyStatus       String   @default("none") @map("reply_status") // none, draft, posted, failed
  
  // AI-generated draft
  aiDraftReply      String?  @map("ai_draft_reply")
  aiSentiment       String?  @map("ai_sentiment")           // positive, negative, neutral, mixed
  
  // Our metadata
  isNew             Boolean  @default(true) @map("is_new")  // Unseen by business owner
  flagged           Boolean  @default(false)                 // Flagged for attention
  
  createdAt         DateTime @default(now()) @map("created_at")
  updatedAt         DateTime @updatedAt @map("updated_at")
  
  gbpConnection     GbpConnection @relation(fields: [gbpConnectionId], references: [id], onDelete: Cascade)
  
  @@unique([gbpConnectionId, googleReviewId])
  @@index([gbpConnectionId, reviewTime])
  @@index([starRating])
  @@map("gbp_reviews")
}

// Posts created through our platform
model GbpPost {
  id                String   @id @default(cuid())
  gbpConnectionId   String   @map("gbp_connection_id")
  
  // Google's post data
  googlePostId      String?  @map("google_post_id")         // Set after publishing
  
  // Post content
  topicType         String   @map("topic_type")             // EVENT, OFFER, STANDARD
  summary           String                                   // Post body text
  actionType        String?  @map("action_type")            // BOOK, ORDER, SHOP, LEARN_MORE, SIGN_UP, CALL
  actionUrl         String?  @map("action_url")
  
  // Event fields
  eventTitle        String?  @map("event_title")
  eventStartDate    DateTime? @map("event_start_date")
  eventEndDate      DateTime? @map("event_end_date")
  
  // Offer fields
  couponCode        String?  @map("coupon_code")
  redeemUrl         String?  @map("redeem_url")
  termsConditions   String?  @map("terms_conditions")
  
  // Media
  mediaUrl          String?  @map("media_url")
  mediaFormat       String?  @map("media_format")            // PHOTO, VIDEO
  
  // Status
  status            String   @default("draft")               // draft, scheduled, published, failed, deleted
  scheduledFor      DateTime? @map("scheduled_for")
  publishedAt       DateTime? @map("published_at")
  
  createdAt         DateTime @default(now()) @map("created_at")
  updatedAt         DateTime @updatedAt @map("updated_at")
  
  gbpConnection     GbpConnection @relation(fields: [gbpConnectionId], references: [id], onDelete: Cascade)
  
  @@index([gbpConnectionId, status])
  @@map("gbp_posts")
}

// Periodic insights snapshots
model GbpInsightSnapshot {
  id                String   @id @default(cuid())
  gbpConnectionId   String   @map("gbp_connection_id")
  
  // Time period
  periodStart       DateTime @map("period_start")
  periodEnd         DateTime @map("period_end")
  
  // Search metrics
  queriesDirect     Int?     @map("queries_direct")          // Searched for business name
  queriesIndirect   Int?     @map("queries_indirect")        // Searched for category/product
  queriesChain      Int?     @map("queries_chain")           // Searched for brand/chain
  
  // View metrics
  viewsMaps         Int?     @map("views_maps")
  viewsSearch       Int?     @map("views_search")
  
  // Action metrics
  actionsWebsite    Int?     @map("actions_website")
  actionsPhone      Int?     @map("actions_phone")
  actionsDrivingDirections Int? @map("actions_driving_directions")
  
  // Photo metrics
  photosViewsMerchant  Int?  @map("photos_views_merchant")
  photosViewsCustomer  Int?  @map("photos_views_customer")
  photosCountMerchant  Int?  @map("photos_count_merchant")
  photosCountCustomer  Int?  @map("photos_count_customer")
  
  // Raw data
  rawInsights       Json?    @map("raw_insights")            // Full API response
  
  createdAt         DateTime @default(now()) @map("created_at")
  
  gbpConnection     GbpConnection @relation(fields: [gbpConnectionId], references: [id], onDelete: Cascade)
  
  @@unique([gbpConnectionId, periodStart, periodEnd])
  @@index([gbpConnectionId, periodStart])
  @@map("gbp_insight_snapshots")
}
```

### 7.2 Existing Table Changes

```prisma
model Location {
  // ... existing fields ...
  gbpConnection     GbpConnection?     // NEW: one-to-one
}

model Organization {
  // ... existing fields ...
  gbpConnections    GbpConnection[]    // NEW: one-to-many
}
```

---

## 8. Backend Implementation

### 8.1 GBP Client

```typescript
// src/core/gbp/GbpClient.ts

export class GbpClient {
  private accessToken: string;
  
  constructor(accessToken: string) {
    this.accessToken = accessToken;
  }
  
  // ═══════════════ Account Management ═══════════════
  
  async listAccounts(): Promise<GbpAccount[]> {
    return this.get('https://mybusinessaccountmanagement.googleapis.com/v1/accounts');
  }
  
  async listLocations(accountId: string): Promise<GbpLocation[]> {
    return this.get(`https://mybusinessbusinessinformation.googleapis.com/v1/${accountId}/locations`);
  }
  
  // ═══════════════ Reviews ═══════════════
  
  async listReviews(accountId: string, locationId: string, pageToken?: string): Promise<ReviewsResponse> {
    const url = `https://mybusiness.googleapis.com/v4/${accountId}/${locationId}/reviews`;
    return this.get(url, { pageToken });
  }
  
  async batchGetReviews(accountId: string, locationNames: string[]): Promise<ReviewsResponse> {
    return this.post(`https://mybusiness.googleapis.com/v4/${accountId}/locations:batchGetReviews`, {
      locationNames, pageSize: 50, orderBy: 'updateTime desc'
    });
  }
  
  async replyToReview(reviewName: string, comment: string): Promise<void> {
    await this.put(`https://mybusiness.googleapis.com/v4/${reviewName}/reply`, { comment });
  }
  
  async deleteReviewReply(reviewName: string): Promise<void> {
    await this.delete(`https://mybusiness.googleapis.com/v4/${reviewName}/reply`);
  }
  
  // ═══════════════ Posts ═══════════════
  
  async createPost(accountId: string, locationId: string, post: CreatePostInput): Promise<GbpPostResponse> {
    return this.post(`https://mybusiness.googleapis.com/v4/${accountId}/${locationId}/localPosts`, post);
  }
  
  async editPost(postName: string, updates: Partial<CreatePostInput>, updateMask: string): Promise<void> {
    await this.patch(`https://mybusiness.googleapis.com/v4/${postName}?updateMask=${updateMask}`, updates);
  }
  
  async deletePost(postName: string): Promise<void> {
    await this.delete(`https://mybusiness.googleapis.com/v4/${postName}`);
  }
  
  // ═══════════════ Insights ═══════════════
  
  async reportInsights(accountId: string, request: InsightsRequest): Promise<InsightsResponse> {
    return this.post(`https://mybusiness.googleapis.com/v4/${accountId}/locations:reportInsights`, request);
  }
  
  // ═══════════════ Services ═══════════════
  
  async listCategories(filter: string, regionCode: string): Promise<CategoryResponse> {
    return this.get(`https://mybusinessbusinessinformation.googleapis.com/v1/categories`, {
      filter: `displayname=${filter}`, regionCode, languageCode: 'EN', view: 'FULL'
    });
  }
  
  async getServices(locationId: string): Promise<ServiceItem[]> {
    const loc = await this.get(`https://mybusinessbusinessinformation.googleapis.com/v1/${locationId}`, {
      readMask: 'serviceItems'
    });
    return loc.serviceItems || [];
  }
  
  async setServices(locationId: string, serviceItems: ServiceItem[]): Promise<void> {
    await this.patch(`https://mybusinessbusinessinformation.googleapis.com/v1/${locationId}?updateMask=serviceItems`, {
      serviceItems
    });
  }
  
  // ═══════════════ Location Data ═══════════════
  
  async patchLocation(locationId: string, data: Partial<GbpLocationData>, updateMask: string): Promise<void> {
    await this.patch(
      `https://mybusinessbusinessinformation.googleapis.com/v1/${locationId}?updateMask=${updateMask}`,
      data
    );
  }
  
  async updateAttributes(locationId: string, attributeMask: string, attributes: GbpAttribute[]): Promise<void> {
    await this.patch(
      `https://mybusinessbusinessinformation.googleapis.com/v1/${locationId}/attributes?attributeMask=${attributeMask}`,
      { attributes }
    );
  }
  
  // ═══════════════ Verification ═══════════════
  
  async getVoiceOfMerchantState(locationId: string): Promise<VoiceOfMerchantState> {
    return this.get(`https://mybusinessverifications.googleapis.com/v1/${locationId}:getVoiceOfMerchantState`);
  }
  
  async fetchVerificationOptions(locationId: string): Promise<VerificationOption[]> {
    return this.post(`https://mybusinessverifications.googleapis.com/v1/${locationId}:fetchVerificationOptions`, {
      languageCode: 'en'
    });
  }
  
  async verify(locationId: string, method: string, input: VerificationInput): Promise<void> {
    await this.post(`https://mybusinessverifications.googleapis.com/v1/${locationId}:verify`, {
      method, languageCode: 'en', ...input
    });
  }
  
  async completeVerification(locationId: string, verificationId: string, pin: string): Promise<void> {
    await this.post(
      `https://mybusinessverifications.googleapis.com/v1/${locationId}/verifications/${verificationId}:complete`,
      { pin }
    );
  }
  
  // ═══════════════ HTTP helpers ═══════════════
  
  private async get(url: string, params?: Record<string, string>) { /* ... */ }
  private async post(url: string, body: any) { /* ... */ }
  private async put(url: string, body: any) { /* ... */ }
  private async patch(url: string, body: any) { /* ... */ }
  private async delete(url: string) { /* ... */ }
}
```

### 8.2 REST API Endpoints

```
// User-facing (authenticated via session)
GET    /me/gbp/connection                    → Get GBP connection status
POST   /me/gbp/connect                       → Initiate GBP connection
DELETE /me/gbp/disconnect                     → Disconnect GBP
POST   /me/gbp/match-location                → Match GBP location to our location

GET    /me/gbp/reviews                        → List reviews (with AI sentiment)
POST   /me/gbp/reviews/:reviewId/reply        → Post reply to review
DELETE /me/gbp/reviews/:reviewId/reply        → Delete reply
POST   /me/gbp/reviews/:reviewId/generate-reply → AI-generate reply draft

GET    /me/gbp/posts                          → List posts
POST   /me/gbp/posts                          → Create post
PATCH  /me/gbp/posts/:postId                  → Edit post
DELETE /me/gbp/posts/:postId                  → Delete post
POST   /me/gbp/posts/generate                 → AI-generate post content

GET    /me/gbp/insights                       → Get insights dashboard data
GET    /me/gbp/insights/trends                → Get trends over time

GET    /me/gbp/services                       → Get current GBP service list
POST   /me/gbp/services/sync                  → Sync our services → GBP

GET    /me/gbp/verification-status            → Check verification state
POST   /me/gbp/verify                         → Initiate verification
POST   /me/gbp/verify/complete                → Complete verification with PIN

// Internal (voice agent tools)
POST   /internal/tools/gbp/get-recent-reviews → Voice agent: "How are my reviews?"
POST   /internal/tools/gbp/get-rating         → Voice agent: "What's my Google rating?"
POST   /internal/tools/gbp/get-insights       → Voice agent: "How many people found us this month?"
```

---

## 9. Voice Agent Integration

GBP data makes the voice agent smarter and gives business owners voice-accessible insights.

### 9.1 Inbound Call Enhancement

When a caller calls, the agent can reference GBP data:
```
Caller: "I saw you had great reviews on Google"
Agent: → [uses cached GBP data]
       "Thank you! We're proud of our 4.8-star rating from 247 reviews.
        How can I help you today?"
```

### 9.2 Business Owner Voice Commands

When the business owner calls their own number (detected by phone match):
```
Owner: "How are my Google reviews this week?"
Agent: → gbp_get_recent_reviews
       "You received 3 new reviews this week — all 5 stars! 
        One customer said 'Amazing service, will definitely use again.'
        Would you like me to draft replies?"

Owner: "What's my Google traffic looking like?"
Agent: → gbp_get_insights
       "This month you've had 1,247 views on Google Search and 
        389 views on Google Maps. Phone calls from Google are up 
        15% compared to last month."
```

### 9.3 Post-Call Review Solicitation

```
[After successful appointment booking]
Agent: "Your appointment is confirmed for Thursday at 2pm. 
        After your service, we'd love if you could leave us 
        a review on Google — it really helps!"
        
[System sends SMS 24 hours after appointment]:
"Hi [Name]! Thank you for choosing [Business]. 
 We'd love your feedback: [review link]"
```

### 9.4 Python Tool Definitions

```python
# tools/definitions/gbp.py

GBP_TOOLS = [
    ToolDefinition(
        name='gbp-get-recent-reviews',
        endpoint='get-recent-reviews',
        description='Get recent Google reviews for the business',
        params=[]
    ),
    ToolDefinition(
        name='gbp-get-rating',
        endpoint='get-rating',
        description='Get the current Google rating and review count',
        params=[]
    ),
    ToolDefinition(
        name='gbp-get-insights',
        endpoint='get-insights',
        description='Get Google Business Profile performance metrics',
        params=[
            ToolParam('period', str, 'Time period: week, month, quarter', default='month')
        ]
    ),
]
```

---

## 10. Frontend — GBP Dashboard

### 10.1 New Pages

```
/gbp                     → GBP Overview (rating, recent reviews, quick insights)
/gbp/reviews             → Full review list with reply management
/gbp/posts               → Post creation and management
/gbp/insights            → Detailed analytics dashboard
/gbp/services            → Service catalog sync
/gbp/settings            → GBP connection settings, auto-reply config
```

### 10.2 Integration in Existing Pages

- **Dashboard page**: Add "Google Reviews" widget (rating, review count, recent review)
- **Integrations page**: Add Google Business Profile integration card
- **Sidebar**: Add "Google Profile" section with sub-items (Reviews, Posts, Insights)

### 10.3 Review Management UI

```
┌─────────────────────────────────────────────────┐
│ Google Reviews                    ★ 4.8 (247)   │
│                                                  │
│ ┌─ Filter: All | Needs Reply | Negative ──────┐ │
│ │                                              │ │
│ │ ★★★★★  John Smith · 2 hours ago             │ │
│ │ "Best plumber in town! Fixed our leak..."    │ │
│ │ [AI Draft Reply] [Reply] [Flag]              │ │
│ │                                              │ │
│ │ ★★☆☆☆  Jane Doe · 1 day ago                │ │
│ │ "Showed up late and charged more than..."    │ │
│ │ ⚠️ AI Draft: "Hi Jane, we sincerely..."      │ │
│ │ [Edit & Post] [Reply Manually] [Dismiss]     │ │
│ │                                              │ │
│ └──────────────────────────────────────────────┘ │
│                                                  │
│ Review Trends (30 days)                          │
│ ████████████████████░░  4.7 avg (12 new)        │
│ Response rate: 92% · Avg response time: 2.3h    │
└─────────────────────────────────────────────────┘
```

---

## 11. Cross-Vertical Value Matrix

### What GBP features matter most per vertical

| Feature | Field Service | Legal | Wellness | Automotive | Hospitality | Property Mgmt |
|---|---|---|---|---|---|---|
| **Review management** | ★★★ | ★★★ | ★★★ | ★★★ | ★★★ | ★★ |
| **AI review replies** | ★★★ | ★★★ | ★★★ | ★★★ | ★★★ | ★★ |
| **Review solicitation** | ★★★ | ★★ | ★★★ | ★★★ | ★★★ | ★ |
| **Service list sync** | ★★★ | ★★ | ★★★ | ★★★ | ★★ | ★ |
| **Google Posts** | ★★ | ★★ | ★★★ | ★★ | ★★★ | ★ |
| **Insights dashboard** | ★★★ | ★★ | ★★★ | ★★★ | ★★★ | ★★ |
| **Hours sync** | ★★ | ★★ | ★★★ | ★★ | ★★★ | ★★ |
| **Booking link** | ★★ | ★★ | ★★★ | ★★ | ★★★ | ★ |
| **Verification** | ★★ | ★★ | ★★ | ★★ | ★★ | ★★ |
| **Ads integration** | ★★ | ★★ | ★★ | ★★ | ★ | ★ |

★★★ = Critical  ★★ = Valuable  ★ = Nice-to-have

**Every vertical gets massive value from reviews + AI replies + insights.** This confirms GBP is a core, not vertical-specific, feature.

---

## 12. Implementation Phases

### Phase 1: Foundation + Review Management — 20-28 hours

| Task | Hours | Notes |
|---|---|---|
| GBP API access application & approval | 1-2 | Apply at Google developer portal |
| Pipedream OAuth app for GBP | 2-3 | Create custom OAuth app with `business.manage` scope |
| `GbpClient.ts` — HTTP client | 4-6 | All API calls, token refresh, error handling |
| `GbpConnection` migration + model | 2-3 | New tables: gbp_connections, gbp_reviews |
| OAuth flow: connect/disconnect | 3-4 | Integrations page, token storage |
| Location matching logic | 2-3 | Match our Location to GBP location |
| Review sync service | 3-4 | Fetch reviews, store locally, detect new |
| Frontend: Reviews page | 3-4 | List, filter, reply |
| **Subtotal** | **20-29** | |

### Phase 2: AI Review Replies + Solicitation — 10-14 hours

| Task | Hours | Notes |
|---|---|---|
| AI reply generation (LLM integration) | 3-4 | Sentiment analysis + reply draft |
| Reply posting flow (draft → approve → post) | 2-3 | UI + API |
| Auto-reply option (for 5-star reviews) | 1-2 | Config flag |
| Review solicitation SMS after appointments | 3-4 | SMS trigger + review link generation |
| Review trends widget on Dashboard | 1-2 | Rating trend, response rate |
| **Subtotal** | **10-15** | |

### Phase 3: Posts + Service Sync — 12-16 hours

| Task | Hours | Notes |
|---|---|---|
| `GbpPost` migration + model | 1-2 | New table |
| Post creation/edit/delete API | 3-4 | Support Event, CTA, Offer |
| AI post generation | 2-3 | Vertical-aware templates |
| Frontend: Posts management page | 3-4 | Create, preview, publish |
| Service catalog sync to GBP | 3-4 | Our services → Google serviceItems |
| **Subtotal** | **12-17** | |

### Phase 4: Insights + Advanced — 10-14 hours

| Task | Hours | Notes |
|---|---|---|
| `GbpInsightSnapshot` migration + model | 1-2 | New table |
| Insights sync service (weekly) | 2-3 | Fetch + store metrics |
| Frontend: Insights dashboard | 4-6 | Charts, trends, comparisons |
| Voice agent GBP tools | 2-3 | Python tool definitions + Node endpoints |
| **Subtotal** | **9-14** | |

### Phase 5: Location Mgmt + Verification — 8-12 hours

| Task | Hours | Notes |
|---|---|---|
| Hours/phone/website sync to GBP | 2-3 | Bidirectional |
| WhatsApp/SMS URL auto-set | 1-2 | Set our number on GBP |
| Google Updates monitoring | 2-3 | Accept/reject flow |
| Verification flow | 2-3 | UI for unverified businesses |
| Pub/Sub real-time notifications | 1-2 | NEW_REVIEW, GOOGLE_UPDATE events |
| **Subtotal** | **8-13** | |

### Total Effort

| Phase | Hours | Dependencies |
|---|---|---|
| **Phase 1:** Foundation + Reviews | 20-29 | GBP API approval |
| **Phase 2:** AI Replies + Solicitation | 10-15 | Phase 1 |
| **Phase 3:** Posts + Service Sync | 12-17 | Phase 1 |
| **Phase 4:** Insights + Voice Tools | 9-14 | Phase 1 |
| **Phase 5:** Location + Verification | 8-13 | Phase 1 |
| **Total** | **59-88** | |

Phases 2-5 can run in parallel after Phase 1. Realistic timeline: **4-6 weeks** for a single developer, **2-3 weeks** with 2 developers.

---

## 13. API Access & Compliance

### 13.1 Getting API Access

1. **Apply for access** at https://developers.google.com/my-business/content/prereqs
2. Requirements:
   - Valid Google Account
   - Valid Google Cloud project
   - Legitimate business purpose (we qualify: SaaS platform managing businesses' GBP)
   - Business website URL (callsaver.ai)
3. Approval typically takes **1-3 weeks**

### 13.2 API Usage Policies

Key constraints from the [GBP API policies](https://developers.google.com/my-business/content/policies):
- **Must not** create fake reviews or manipulate review scores
- **Must not** create locations that don't represent real businesses
- **Must** respect rate limits
- **Must** obtain explicit consent from business owners before managing their profiles
- All API actions must reflect the business owner's intent

### 13.3 Rate Limits

From [Usage Limits](https://developers.google.com/my-business/content/limits):
- Varies by endpoint
- Implement exponential backoff for 429 responses
- Cache responses where possible (reviews, insights)
- Batch operations where supported (batchGetReviews)

### 13.4 Data Retention

- Reviews: Cache locally, sync periodically (every 6 hours)
- Insights: Snapshot weekly, retain 1 year
- Posts: Store in our DB, mirror to Google
- Location data: Sync on demand, cache 24 hours

---

## Appendix A: Relationship to Multi-Vertical Architecture

From the [multi-vertical architecture evolution plan](./multi-vertical-architecture-evolution.md), GBP integration maps to the **Shared Kernel** (`src/core/`):

```
src/core/
  BaseAdapter.ts           ← Existing (shared across verticals)
  CallerContext.ts          ← Existing
  phoneVerification.ts     ← Existing
  errors.ts                ← Existing
  gbp/                     ← NEW: this plan
    GbpClient.ts
    GbpService.ts
    types.ts
    sync/
    actions/
    routes/
```

GBP is the **first cross-vertical core module** — it validates the `src/core/` architecture pattern before we extract the adapter registry and tool builder generics. It's a clean, bounded module that doesn't touch vertical-specific code.

## Appendix B: The Data Flywheel

```
 CallSaver Voice Agent handles calls well
          │
          ▼
 Customers are satisfied with service
          │
          ▼
 Post-call SMS: "Leave us a review on Google"
          │
          ▼
 Customer leaves 5-star review on Google
          │
          ▼
 AI auto-replies: "Thank you [Name]!"
          │
          ▼
 Higher Google rating + more reviews
          │
          ▼
 Better Google ranking → More visibility
          │
          ▼
 MORE CALLS → back to step 1
```

This flywheel is the most powerful argument for why GBP integration belongs as a core platform feature. It directly ties call quality to business growth, creating measurable ROI that justifies the platform fee.
