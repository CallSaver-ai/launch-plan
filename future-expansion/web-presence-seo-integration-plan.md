# Web Presence, SEO & AI Website Management — The "Own Their Website" Strategy

> **Date:** 2026-02-24  
> **Status:** Strategic Planning  
> **Scope:** Integrate PageSpeed Insights, Google Search Console, Google Analytics, and AI-powered website rebuilds as a core platform capability across all verticals  
> **Reference:** [Multi-Vertical Architecture Evolution](./multi-vertical-architecture-evolution.md) | [Google Business Profile Integration](./google-business-profile-integration-plan.md)

---

## 1. Strategic Vision — The AI Operating System for Businesses

### The Three Pillars of Business Digital Presence

```
┌─────────────────────────────────────────────────────────────────┐
│                 CALLSAVER: AI OPERATING SYSTEM                   │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   PILLAR 1   │  │   PILLAR 2   │  │      PILLAR 3        │  │
│  │    PHONE     │  │    GOOGLE    │  │      WEBSITE         │  │
│  │              │  │   PRESENCE   │  │                      │  │
│  │ Voice Agent  │  │ GBP Reviews  │  │ PageSpeed/SEO        │  │
│  │ Call Routing │  │ Posts        │  │ Search Console       │  │
│  │ CRM Sync    │  │ Insights     │  │ Analytics            │  │
│  │ Scheduling  │  │ Services     │  │ AI Website Builder   │  │
│  │ Follow-ups  │  │ Verification │  │ Auto-Optimization    │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              VERTICAL ADAPTERS (Field Service,            │   │
│  │              Legal, Wellness, Automotive, etc.)            │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

Today, a local business needs **5-8 separate tools** to manage their digital presence:
1. Phone answering service or receptionist
2. CRM / field service management (Jobber, HCP, etc.)
3. Google Business Profile (manual management)
4. Website hosting (Wix, Squarespace, WordPress)
5. SEO tool (SEMrush, Ahrefs, Moz)
6. Google Analytics dashboard
7. Google Search Console
8. PageSpeed / Core Web Vitals monitoring

**CallSaver replaces ALL of them.** The phone was the entry point. Google Business Profile is the expansion. Website ownership is the endgame.

### The Revenue Opportunity

| Tier | What They Get | Price | TAM |
|---|---|---|---|
| **Starter** | Voice Agent + CRM | $49-99/mo | All businesses |
| **Growth** | + GBP Management + Reviews | $149-199/mo | ~70% of businesses |
| **Pro** | + Website + SEO + Analytics | $249-349/mo | ~40% of businesses |
| **Enterprise** | + AI Website Rebuild + Ads | $499-999/mo | ~15% of businesses |

At 10,000 customers with blended $200/mo ARPU = **$24M ARR**. With website tier upsell pushing average to $275/mo = **$33M ARR**. Add data products = **$50M+**.

---

## 2. Google APIs for Web Presence

### 2.1 PageSpeed Insights API

**Purpose:** Analyze website performance, Core Web Vitals, accessibility, SEO, best practices  
**Base URL:** `https://www.googleapis.com/pagespeedonline/v5/runPagespeed`  
**Auth:** API key only (no OAuth required!)  
**Rate limit:** 25,000 queries/day (free), or 240 requests/minute with billing enabled  
**Cost:** Free for standard usage

**Key parameters:**
```
GET https://www.googleapis.com/pagespeedonline/v5/runPagespeed
  ?url={websiteUrl}
  &key={API_KEY}
  &category=PERFORMANCE
  &category=ACCESSIBILITY  
  &category=BEST_PRACTICES
  &category=SEO
  &strategy=MOBILE          // or DESKTOP
```

**Response includes:**
- **Lighthouse scores** (0-100): Performance, Accessibility, Best Practices, SEO
- **Core Web Vitals**: LCP (Largest Contentful Paint), FID/INP (Interaction to Next Paint), CLS (Cumulative Layout Shift)
- **Field data** (CrUX): Real-user metrics from Chrome users (if available)
- **Lab data**: Simulated metrics (always available)
- **Audit details**: Specific issues with recommendations
  - Render-blocking resources
  - Unused CSS/JS
  - Image optimization opportunities
  - Missing meta tags
  - Missing alt text
  - HTTP/2 usage
  - etc.

**Already partially built:** We have `website/pagespeed-local.js` and `website/pagespeed-test.js` in the launch-plan repo.

### 2.2 Google Search Console API

**Purpose:** Monitor search performance, indexing status, crawl errors, sitemaps  
**Base URL:** `https://www.googleapis.com/webmasters/v3` (or `https://searchconsole.googleapis.com`)  
**Auth:** OAuth 2.0 (site owner must grant access)  
**Scope:** `https://www.googleapis.com/auth/webmasters.readonly` (read) or `https://www.googleapis.com/auth/webmasters` (read/write)

**Key endpoints:**
```
POST /webmasters/v3/sites/{siteUrl}/searchAnalytics/query
  → Search performance: queries, clicks, impressions, CTR, position
  → Filter by date, query, page, country, device, search type

GET  /webmasters/v3/sites/{siteUrl}/sitemaps
  → Sitemap status and errors

GET  /webmasters/v3/sites/{siteUrl}/urlInspection/index:inspect
  → URL indexing status, mobile usability, rich results

POST /webmasters/v3/sites/{siteUrl}/sitemaps
  → Submit new sitemap
```

**What we can show businesses:**
- Top search queries that drive traffic
- Which pages rank and for what
- Click-through rates by query
- Mobile usability issues
- Indexing coverage (pages indexed vs. errors)
- Core Web Vitals pass/fail from Google's perspective

### 2.3 Google Analytics 4 (GA4) Data API

**Purpose:** Website traffic analytics, user behavior, conversions  
**Base URL:** `https://analyticsdata.googleapis.com/v1beta`  
**Auth:** OAuth 2.0  
**Scope:** `https://www.googleapis.com/auth/analytics.readonly`

**Key endpoints:**
```
POST /v1beta/properties/{propertyId}:runReport
  → Metrics: sessions, users, pageviews, bounce rate, avg session duration
  → Dimensions: date, source/medium, page path, city, device category
  → Date ranges: any custom range

POST /v1beta/properties/{propertyId}:runRealtimeReport
  → Active users right now, current pages being viewed
```

**What we can show businesses:**
- Total visitors (daily/weekly/monthly trends)
- Traffic sources (Google Search, Direct, Social, Referral)
- Top landing pages
- Device breakdown (mobile vs. desktop)
- Geographic distribution
- Goal/conversion tracking (if configured)
- Call tracking correlation: "Calls from Google increased 34% this month, website visits up 22%"

### 2.4 Google Ads API (Future)

Already covered in the GBP integration plan. Location extensions + ad performance data.

---

## 3. What We Already Have

### 3.1 Crawl4AI Infrastructure

We already have a **production Crawl4AI deployment** (shared stack on AWS) that crawls business websites during provisioning:
- Extracts structured business data
- Stores in S3: `s3://callsaver-company-website-extractions/{companyId}/`
- Used to generate the voice agent's knowledge base

**This is the foundation for AI website analysis.** Crawl4AI already parses HTML, extracts text, and understands page structure. We can extend it to identify SEO issues, missing structured data, and performance bottlenecks.

### 3.2 Google Places Data

Every location already has `googlePlaceDetails` with:
- Business hours, address, phone, website URL
- Rating, review count, review summary
- Business category and types
- Service area business flag

### 3.3 Existing PageSpeed Scripts

```
production-launch-plan/website/
  pagespeed-local.js      ← Local PageSpeed testing
  pagespeed-test.js       ← Automated PageSpeed testing
```

These can be evolved into the platform-integrated version.

---

## 4. Architecture — Web Presence as Core Module

Like GBP, web presence management belongs in `src/core/` because it's vertical-agnostic:

```
src/core/
  gbp/                          ← Google Business Profile (already planned)
  web-presence/                  ← NEW: Website & SEO module
    PageSpeedService.ts          ← PageSpeed Insights API client + analysis
    SearchConsoleService.ts      ← Search Console API client
    AnalyticsService.ts          ← GA4 API client
    SeoAnalyzer.ts               ← Comprehensive SEO audit engine
    WebsiteHealthService.ts      ← Orchestrates all checks, stores results
    ai/
      WebsiteRewriteService.ts   ← AI-powered website generation
      SeoFixService.ts           ← Auto-fix SEO issues
      ContentGenerator.ts        ← AI content for pages, meta tags, schema
    sync/
      PeriodicAuditService.ts    ← Scheduled re-audits (weekly/monthly)
      AlertService.ts            ← Alert on score drops, indexing issues
    routes/
      web-presence-routes.ts     ← REST API endpoints
      web-presence-tools.ts      ← Voice agent tool endpoints
```

### Relationship to Other Core Modules

```
┌────────────────────────────────────────────────────┐
│ src/core/                                           │
│                                                     │
│   gbp/            ←→  web-presence/                 │
│   (Reviews,           (PageSpeed, SEO,              │
│    Posts,              Search Console,               │
│    Insights,           Analytics,                    │
│    Services)           AI Website)                   │
│         │                    │                       │
│         └──── SHARED DATA ───┘                       │
│         Business URL, hours, services,               │
│         address, category, phone                     │
│                                                     │
│   Both feed into the voice agent's                   │
│   knowledge base and business context               │
└────────────────────────────────────────────────────┘
```

---

## 5. Feature Modules

### 5.1 Website Health Dashboard (HIGH PRIORITY)

**One-click website audit** that runs on every business onboarding and periodically after.

**What it analyzes:**
```
┌─────────────────────────────────────────────────────┐
│ Website Health Score: 72/100            ⚠️ Needs Work │
│                                                      │
│ Performance  ████████░░  78/100                      │
│   LCP: 3.2s (Poor — should be <2.5s)                │
│   INP: 180ms (Good)                                  │
│   CLS: 0.15 (Needs improvement — should be <0.1)    │
│                                                      │
│ SEO          ██████░░░░  62/100                      │
│   ⚠️ Missing meta descriptions on 4 pages            │
│   ⚠️ No structured data (LocalBusiness schema)       │
│   ⚠️ Missing alt text on 12 images                   │
│   ✅ Valid sitemap.xml                                │
│   ❌ No robots.txt                                    │
│                                                      │
│ Accessibility ████████░░  81/100                     │
│   ⚠️ Low contrast text on 3 elements                 │
│   ⚠️ Missing form labels                             │
│                                                      │
│ Best Practices ██████████  95/100                    │
│   ✅ HTTPS enabled                                    │
│   ✅ No mixed content                                 │
│                                                      │
│ [Run New Audit]  [View Full Report]  [Auto-Fix SEO] │
└─────────────────────────────────────────────────────┘
```

**Data sources:**
- PageSpeed Insights API (performance, accessibility, SEO, best practices)
- Crawl4AI (content analysis, link structure, page inventory)
- Search Console (indexing, crawl errors, mobile usability) — if connected
- Google Analytics (traffic patterns) — if connected

### 5.2 SEO Analyzer (HIGH PRIORITY)

Goes beyond PageSpeed to provide actionable SEO recommendations:

**Technical SEO:**
- Missing/duplicate title tags
- Missing/duplicate meta descriptions
- Missing canonical URLs
- Broken internal/external links
- Missing XML sitemap
- Missing/misconfigured robots.txt
- HTTP vs. HTTPS issues
- Redirect chains
- Page load time optimization

**On-Page SEO:**
- Missing H1 tags
- Missing alt text on images
- Thin content pages (< 300 words)
- Keyword density analysis
- Internal linking structure
- Missing structured data (LocalBusiness, Service, FAQ schema)

**Local SEO (tied to GBP):**
- NAP consistency (Name, Address, Phone across web)
- Local schema markup
- Google Business Profile completeness
- Citation consistency
- Review signals

**Per-Vertical SEO Templates:**

| Vertical | Key Schema Types | Priority Pages | Local Keywords |
|---|---|---|---|
| **Field Service** | LocalBusiness, Service, FAQPage | Service pages, Service area pages | "plumber near me", "HVAC repair [city]" |
| **Legal** | LegalService, Attorney, FAQPage | Practice area pages, Attorney bios | "personal injury lawyer [city]" |
| **Wellness** | HealthAndBeautyBusiness, Service | Service menu, Staff bios, Booking | "hair salon near me", "med spa [city]" |
| **Automotive** | AutoRepair, Service | Service pages, Coupons | "oil change near me", "auto repair [city]" |
| **Hospitality** | Hotel, Restaurant, Menu | Room types, Menu, Events | "hotel [city]", "restaurant near me" |
| **Property Mgmt** | RealEstateAgent, ApartmentComplex | Available units, Amenities | "apartments in [city]" |

### 5.3 AI Website Rebuild (PREMIUM — HIGH IMPACT)

This is the moonshot feature. For businesses with terrible websites (and there are MANY), we offer:

**Option A: AI Website Audit + Fix List**
- Run full audit
- Generate prioritized fix list
- Provide copy-paste code snippets for each fix
- Estimate impact of each fix on scores

**Option B: AI Full Website Rebuild**
- Crawl existing site to understand content, services, branding
- Generate a modern, fast, SEO-optimized replacement
- Built on Next.js/Astro (SSG for speed) hosted on our infra
- Auto-include:
  - LocalBusiness structured data
  - All services from our CRM/adapter
  - Business hours from GBP
  - Reviews from GBP
  - Booking/call CTAs
  - Mobile-first responsive design
  - Perfect PageSpeed scores
  - Sitemap.xml + robots.txt
  - GA4 + Search Console auto-configured

**Option C: Continuous AI Optimization**
- Monthly re-audit
- Auto-fix emerging SEO issues
- Auto-update content (new services, seasonal offers)
- Auto-publish blog posts for SEO (AI-generated, business-approved)
- Monitor competitor rankings

**Technical approach for AI rebuilds:**

```
1. Crawl4AI → extract all content, images, branding, colors
2. LLM → generate site structure, copy, meta tags, schema
3. Template engine → render into SSG framework (Astro/Next.js)
4. Deploy → our CDN (CloudFront) or Netlify/Vercel
5. DNS → business points their domain to our hosting
6. Monitor → weekly PageSpeed + Search Console checks
```

**Revenue model:** AI website rebuilds at $499-999 one-time + $49-99/mo hosting & optimization = extremely high-margin revenue.

### 5.4 Google Search Console Integration (MEDIUM PRIORITY)

**Auth:** OAuth 2.0 via Pipedream (same pattern as GBP and GCal)  
**Scope:** `webmasters.readonly` (MVP), `webmasters` (for sitemap submission)

**Dashboard data:**
- Top 20 search queries (clicks, impressions, CTR, avg position)
- Top 10 landing pages by clicks
- Search performance trend (30/90/365 day)
- Index coverage: pages indexed, errors, warnings
- Mobile usability score
- Core Web Vitals pass rate

**Actionable insights:**
```
"Your top search query is 'plumber near me' — you rank #7 on average.
 Improving your page speed from 78 to 90+ could move you to #4-5.
 Here's what to fix..."
```

### 5.5 Google Analytics Integration (MEDIUM PRIORITY)

**Auth:** OAuth 2.0 via Pipedream  
**Scope:** `analytics.readonly`

**Dashboard data:**
- Visitors this week/month (with trend)
- Traffic sources breakdown
- Top pages
- Device split (mobile vs. desktop)
- Geographic distribution
- Bounce rate and avg session duration

**Correlation with call data:**
```
"This month:
 - 1,247 website visitors (+15%)
 - 89 calls from Google (+22%)
 - 34 calls converted to appointments (38% conversion)
 - Your cost per appointment from Google: ~$0 (organic)"
```

### 5.6 Voice Agent Integration

Business owners calling their own number get web presence insights:

```
Owner: "How's my website doing?"
Agent: → web_get_health_score
       "Your website health score is 72 out of 100. 
        Performance is good at 78, but your SEO score is 62. 
        The main issues are missing meta descriptions on 4 pages 
        and no structured data. Would you like me to schedule 
        an auto-fix for the SEO issues?"

Owner: "What are people searching for to find me?"
Agent: → web_get_top_queries
       "Your top search queries this month are: 'plumber near me' 
        at position 7 with 340 impressions, and 'emergency plumber 
        [city]' at position 12 with 180 impressions."
```

---

## 6. Database Schema

### 6.1 New Tables

```prisma
// Website audit results per location
model WebsiteAudit {
  id                String   @id @default(cuid())
  locationId        String   @map("location_id")
  organizationId    String   @map("organization_id")
  
  // Target
  url               String                              // The URL that was audited
  strategy          String   @default("MOBILE")         // MOBILE or DESKTOP
  
  // Lighthouse scores (0-100)
  performanceScore  Int?     @map("performance_score")
  seoScore          Int?     @map("seo_score")
  accessibilityScore Int?   @map("accessibility_score")
  bestPracticesScore Int?   @map("best_practices_score")
  overallScore      Int?     @map("overall_score")       // Weighted composite
  
  // Core Web Vitals
  lcp               Float?                               // Largest Contentful Paint (seconds)
  inp               Float?                               // Interaction to Next Paint (ms)
  cls               Float?                               // Cumulative Layout Shift
  fcp               Float?                               // First Contentful Paint (seconds)
  ttfb              Float?                               // Time to First Byte (seconds)
  
  // Issue counts
  criticalIssues    Int      @default(0) @map("critical_issues")
  warningIssues     Int      @default(0) @map("warning_issues")
  passedAudits      Int      @default(0) @map("passed_audits")
  
  // Full audit data
  lighthouseReport  Json?    @map("lighthouse_report")   // Full PageSpeed API response
  seoAudit          Json?    @map("seo_audit")           // Our custom SEO analysis
  issues            Json?                                 // Structured issue list with fix recommendations
  
  createdAt         DateTime @default(now()) @map("created_at")
  
  location          Location     @relation(fields: [locationId], references: [id], onDelete: Cascade)
  organization      Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  
  @@index([locationId, createdAt])
  @@index([organizationId])
  @@map("website_audits")
}

// Search Console connection + snapshots
model SearchConsoleConnection {
  id                String   @id @default(cuid())
  locationId        String   @unique @map("location_id")
  organizationId    String   @map("organization_id")
  
  siteUrl           String   @map("site_url")            // "https://example.com" or "sc-domain:example.com"
  
  lastSync          DateTime? @map("last_sync")
  
  createdAt         DateTime @default(now()) @map("created_at")
  updatedAt         DateTime @updatedAt @map("updated_at")
  
  location          Location     @relation(fields: [locationId], references: [id], onDelete: Cascade)
  organization      Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  snapshots         SearchConsoleSnapshot[]
  
  @@index([organizationId])
  @@map("search_console_connections")
}

model SearchConsoleSnapshot {
  id                String   @id @default(cuid())
  connectionId      String   @map("connection_id")
  
  periodStart       DateTime @map("period_start")
  periodEnd         DateTime @map("period_end")
  
  // Aggregate metrics
  totalClicks       Int?     @map("total_clicks")
  totalImpressions  Int?     @map("total_impressions")
  avgCtr            Float?   @map("avg_ctr")
  avgPosition       Float?   @map("avg_position")
  
  // Top queries and pages
  topQueries        Json?    @map("top_queries")          // [{query, clicks, impressions, ctr, position}]
  topPages          Json?    @map("top_pages")            // [{page, clicks, impressions, ctr, position}]
  
  // Index coverage
  indexedPages      Int?     @map("indexed_pages")
  indexErrors       Int?     @map("index_errors")
  
  createdAt         DateTime @default(now()) @map("created_at")
  
  connection        SearchConsoleConnection @relation(fields: [connectionId], references: [id], onDelete: Cascade)
  
  @@unique([connectionId, periodStart, periodEnd])
  @@index([connectionId, periodStart])
  @@map("search_console_snapshots")
}

// Analytics connection + snapshots
model AnalyticsConnection {
  id                String   @id @default(cuid())
  locationId        String   @unique @map("location_id")
  organizationId    String   @map("organization_id")
  
  propertyId        String   @map("property_id")          // GA4 property ID
  
  lastSync          DateTime? @map("last_sync")
  
  createdAt         DateTime @default(now()) @map("created_at")
  updatedAt         DateTime @updatedAt @map("updated_at")
  
  location          Location     @relation(fields: [locationId], references: [id], onDelete: Cascade)
  organization      Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  snapshots         AnalyticsSnapshot[]
  
  @@index([organizationId])
  @@map("analytics_connections")
}

model AnalyticsSnapshot {
  id                String   @id @default(cuid())
  connectionId      String   @map("connection_id")
  
  periodStart       DateTime @map("period_start")
  periodEnd         DateTime @map("period_end")
  
  // Core metrics
  sessions          Int?
  users             Int?
  newUsers          Int?     @map("new_users")
  pageviews         Int?
  bounceRate        Float?   @map("bounce_rate")
  avgSessionDuration Float? @map("avg_session_duration")
  
  // Traffic sources
  trafficSources    Json?    @map("traffic_sources")      // [{source, medium, sessions}]
  
  // Top pages
  topPages          Json?    @map("top_pages")            // [{path, pageviews, avgTime}]
  
  // Device breakdown
  deviceBreakdown   Json?    @map("device_breakdown")     // {mobile: N, desktop: N, tablet: N}
  
  // Geographic
  topCities         Json?    @map("top_cities")           // [{city, sessions}]
  
  createdAt         DateTime @default(now()) @map("created_at")
  
  connection        AnalyticsConnection @relation(fields: [connectionId], references: [id], onDelete: Cascade)
  
  @@unique([connectionId, periodStart, periodEnd])
  @@index([connectionId, periodStart])
  @@map("analytics_snapshots")
}

// AI-managed websites
model ManagedWebsite {
  id                String   @id @default(cuid())
  locationId        String   @unique @map("location_id")
  organizationId    String   @map("organization_id")
  
  // Domain
  domain            String                                // "example.com"
  subdomain         String?                               // For our-hosted: "example.callsaver.ai"
  
  // Hosting
  hostingProvider   String   @map("hosting_provider")     // "callsaver", "external"
  deployUrl         String?  @map("deploy_url")           // CloudFront/Netlify URL
  
  // Template/framework
  framework         String   @default("astro")            // "astro", "nextjs"
  templateId        String?  @map("template_id")
  
  // Status
  status            String   @default("draft")            // draft, building, deployed, active, paused
  lastDeployed      DateTime? @map("last_deployed")
  lastOptimized     DateTime? @map("last_optimized")
  
  // Auto-optimization settings
  autoOptimize      Boolean  @default(true) @map("auto_optimize")
  autoPublishBlog   Boolean  @default(false) @map("auto_publish_blog")
  
  // Latest scores
  latestPerfScore   Int?     @map("latest_perf_score")
  latestSeoScore    Int?     @map("latest_seo_score")
  
  createdAt         DateTime @default(now()) @map("created_at")
  updatedAt         DateTime @updatedAt @map("updated_at")
  
  location          Location     @relation(fields: [locationId], references: [id], onDelete: Cascade)
  organization      Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  
  @@index([organizationId])
  @@map("managed_websites")
}
```

---

## 7. Implementation Phases

### Phase 1: PageSpeed Audit Engine — 12-16 hours

| Task | Hours | Notes |
|---|---|---|
| `PageSpeedService.ts` — API client | 2-3 | Call PSI API, parse Lighthouse response |
| `SeoAnalyzer.ts` — extended SEO checks | 3-4 | Crawl4AI + PageSpeed + custom rules |
| `WebsiteAudit` migration + model | 1-2 | New table |
| Auto-audit on location creation | 1-2 | Hook into provisioning flow |
| REST endpoints for audits | 2-3 | Run audit, get results, get history |
| Frontend: Website Health page | 3-4 | Score cards, issue list, recommendations |
| **Subtotal** | **12-18** | |

### Phase 2: Search Console Integration — 10-14 hours

| Task | Hours | Notes |
|---|---|---|
| Pipedream OAuth app for Search Console | 1-2 | Scope: webmasters.readonly |
| `SearchConsoleService.ts` — API client | 3-4 | Query analytics, index status |
| Connect flow + site verification | 2-3 | Match site URL to location |
| Periodic sync (weekly snapshots) | 2-3 | Cron job or scheduled task |
| Frontend: Search performance dashboard | 2-3 | Top queries, pages, trends |
| **Subtotal** | **10-15** | |

### Phase 3: Google Analytics Integration — 10-14 hours

| Task | Hours | Notes |
|---|---|---|
| Pipedream OAuth app for GA4 | 1-2 | Scope: analytics.readonly |
| `AnalyticsService.ts` — API client | 3-4 | Run reports, real-time data |
| Connect flow + property selection | 2-3 | List properties, user selects |
| Periodic sync (weekly snapshots) | 2-3 | Cron job |
| Frontend: Analytics dashboard | 2-3 | Visitors, sources, trends |
| **Subtotal** | **10-15** | |

### Phase 4: AI SEO Auto-Fix — 14-18 hours

| Task | Hours | Notes |
|---|---|---|
| `SeoFixService.ts` — auto-fix engine | 4-6 | Generate fixes for common issues |
| Meta tag generation (LLM) | 2-3 | Title, description, OG tags per page |
| Structured data generation | 3-4 | LocalBusiness, Service, FAQ schema |
| Content recommendations | 2-3 | Thin content detection + suggestions |
| Frontend: Fix review + apply flow | 3-4 | Preview fixes, approve, apply |
| **Subtotal** | **14-20** | |

### Phase 5: AI Website Builder — 30-40 hours

| Task | Hours | Notes |
|---|---|---|
| Website template system (Astro/Next.js) | 8-10 | Per-vertical templates |
| Content extraction from existing site | 4-6 | Crawl4AI → structured content |
| AI page generation (LLM) | 6-8 | Home, About, Services, Contact |
| Auto-structured data injection | 3-4 | Schema.org markup |
| Deployment pipeline (CloudFront/Netlify) | 4-6 | Build + deploy + DNS |
| Frontend: Website builder wizard | 4-6 | Preview, customize, launch |
| `ManagedWebsite` model + migration | 1-2 | New table |
| **Subtotal** | **30-42** | |

### Phase 6: Continuous Optimization — 8-12 hours

| Task | Hours | Notes |
|---|---|---|
| Weekly re-audit scheduler | 2-3 | Cron: run PageSpeed + SEO checks |
| Score drop alerts | 2-3 | Email/SMS when scores decrease |
| Auto-fix pipeline | 2-3 | For managed websites only |
| Voice agent web presence tools | 2-3 | Python tool definitions |
| **Subtotal** | **8-12** | |

### Total Effort

| Phase | Hours | Priority |
|---|---|---|
| **Phase 1:** PageSpeed Audit | 12-18 | HIGH — Do with or shortly after launch |
| **Phase 2:** Search Console | 10-15 | MEDIUM — After initial traction |
| **Phase 3:** Analytics | 10-15 | MEDIUM — After initial traction |
| **Phase 4:** AI SEO Auto-Fix | 14-20 | HIGH — Major upsell feature |
| **Phase 5:** AI Website Builder | 30-42 | PREMIUM — After product-market fit |
| **Phase 6:** Continuous Optimization | 8-12 | After Phase 5 |
| **Total** | **84-122** | |

**Phase 1 can launch within 2 weeks of production launch.** It only needs an API key (no OAuth). Phases 2-3 can follow in parallel. Phase 5 (AI website builder) is a Q3-Q4 2026 play.

---

## 8. The Complete Platform Vision

```
YEAR 1 (2026): Voice Agent + CRM + Vertical Adapters
   └── Launch field service, then legal, wellness
   └── PageSpeed audits running from day 1

YEAR 2 (2027): + GBP Management + Web Presence
   └── Review management, posts, insights
   └── Search Console + Analytics dashboards
   └── AI SEO auto-fix

YEAR 3 (2027-28): + AI Website Builder + Ads
   └── Full website replacement for SMBs
   └── Google Ads management
   └── Cross-vertical marketplace

RESULT: THE AI OPERATING SYSTEM FOR LOCAL BUSINESSES
   ├── Handles their phones (Voice Agent)
   ├── Manages their customers (CRM + Vertical Adapters)
   ├── Controls their Google presence (GBP)
   ├── Optimizes their website (SEO + AI Builder)
   ├── Tracks their marketing (Analytics + Search Console)
   └── Grows their reputation (Reviews + Posts)
```

Every piece feeds the others. Calls inform the CRM. The CRM feeds the voice agent. Reviews drive Google ranking. Google ranking drives calls. Website optimization drives organic traffic. Analytics prove ROI. **This is not a collection of features — it's a flywheel.**

---

## Appendix: API Key vs. OAuth Requirements

| API | Auth Type | User Action Needed | Can Run Day 1? |
|---|---|---|---|
| **PageSpeed Insights** | API key | None (we call it) | **YES** |
| **Google Search Console** | OAuth 2.0 | User must connect + verify site ownership | After onboarding |
| **Google Analytics (GA4)** | OAuth 2.0 | User must connect + select property | After onboarding |
| **Google Business Profile** | OAuth 2.0 + API approval | User must connect + Google must approve us | After 1-3 week approval |

**PageSpeed Insights is the easiest win** — no user action required, free API, immediate value. Start here.
