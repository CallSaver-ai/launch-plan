# Daily Plan: February 13, 2026

> **Purpose:** Starbucks Sprint Plan
> **Date:** February 13, 2026

---

## ✅ Completed (Late Night Session — 2am–3:40am)

- [x] Write daily plan document + updates
- [x] Capital One: Update address to 2101 Vine Hill Road — ✅ DONE
- [x] Bank of America: Update address to 2101 Vine Hill Road — ✅ DONE
- [x] Bank of America: Set up Advantage SafeBalance second checking account — ✅ DONE
- [x] Bank of America: Deposit cash to new SafeBalance checking account — ✅ DONE
- [x] Capital One 360 Performance Savings: Opened account (~4.2% APY) — ✅ DONE
- [x] Apliiq: Purchased founder's hoodie ($51) — ✅ DONE
- [x] Kikoff: Signed up for $20/mo credit building plan — ✅ DONE
- [x] Self: Signed up for $25/mo Credit Builder Account, first installment paid — ✅ DONE
- [x] Rocket Money: Started 7-day premium free trial — ✅ DONE

---

## 🔴 Phase 1: Do First (High Priority)

### 1. Pay Off Capital One Balance — ⏸️ DEFERRED (~3 days, next unemployment check)
- [ ] Pay off $150 Capital One balance when unemployment check arrives
- [ ] Set up autopay for minimum payment to prevent future delinquency
- [ ] Call Capital One and request goodwill adjustment to remove late payment marks

### 2. Staging Stack Debug — ✅ COMPLETED
**2a. Frontend Sign-In Page Not Loading — ✅ FIXED**
- [x] **Root cause:** Frontend was built with `VITE_API_URL=http://localhost:3000` instead of staging API URL
- [x] **Fix:** Rebuilt frontend with correct staging env vars and deployed
- [x] **Font issue:** Fixed Figtree font not displaying (was referencing undefined `--font-avenir`)
- [x] **Deploy scripts:** Updated to auto-load env vars from `.env.staging` (no more manual CLI passing)
- [x] **Repo:** `~/callsaver-frontend`

**2b. API Health Endpoint — ✅ ACKNOWLEDGED**
- [x] **Issue:** `gitSha: "unknown"` and `buildDate: "unknown"` in `/health` response
- [x] **Root cause:** GitHub Actions workflow not passing `GIT_SHA`/`BUILD_DATE` as build args to Docker
- [x] **Status:** Cosmetic only — will self-correct on next full API deploy via GitHub Actions
- [x] **Repo:** `~/callsaver-api`

### 3. Laundry
- [ ] Get laundry done

### 4. Call Dad (afternoon)
- [ ] Discuss response to the District Attorney

---

## 🟡 Phase 2: Phone Tasks (Between Coding Blocks)

Quick tasks you can knock out on your phone in 5 min each:

### Credit Building & Monitoring
- [ ] **CreditKarma** — Create account for free credit monitoring
- [ ] **Experian Boost** — Sign up, link bank account (free, +10-20 points on Experian FICO)
- [ ] **Grow Credit (free tier)** — Link existing subscription (Spotify/Netflix/etc.), reports to all 3 bureaus
- [ ] **Discover it Secured card** — ⏸️ DEFERRED (no funds right now). Apply + $200 deposit when ready.
- [ ] **Chime Credit Builder** — Open Chime checking account + credit builder card (free, no deposit, Visa)

### Banking & Cards
- [ ] **Capital One** — Order new card with updated address
- [ ] **Capital One** — Pick up physical authorized user credit card from Emik (mom's card, IC Manage office address)
- [ ] **Bank of America** — Call BofA to order new debit card (app says ineligible)
- [ ] **Apliiq** — Confirm refund for previous erroneous $51 purchase

### Subscription Audit (Rocket Money trial already active)
- [ ] Use Rocket Money to identify all recurring subscriptions
- [ ] Use cancellation concierge to kill unnecessary subscriptions
- [ ] Document what was kept vs cancelled
- [ ] **⏰ Set phone reminder for day 6 to cancel Rocket Money premium before trial ends**

---

## 🟢 Phase 3: Coding Sprint — 🎯 MAIN FOCUS TODAY

### 4. Cal.com → Google Places → Website Scraping Pipeline — ⏳ IN PROGRESS

> **Full plan:** See `planning/pipeline-plan.md`
> **Target:** Staging first → production migration before launch (task 1.13a in active-plan.md)

**4a. Cal.com Booking Field — ✅ IDENTIFIED**
- [x] Field slug is `businessNameAndLocation` (Required, Short Text)
- [x] Other slugs: `attendeePhoneNumber`, `schedulingSoftware`, `notes`
- [ ] Configure Cal.com webhook to point at `https://staging.api.callsaver.ai/webhooks/cal/booking-created` (USER action)
- [ ] Trigger test booking to verify `payload.responses` field structure in DB

**4b. Google Places Search**
- [ ] Use the `businessNameAndCity` field value to search Google Places API
- [ ] Fetch the Google Place ID from search results
- [ ] Fetch place details (including `websiteUri`) from Google Places Details API

**4c. Website Scraping**
- [ ] Use `websiteUri` from Google Places details to scrape the business website
- [ ] Connect to existing scraping code in `~/callsaver-crawl4ai`
- [ ] Leverage existing work in `~/lead-gen-production` and `~/callsaver-attio-crm-schema`

**4d. Pipeline Organization**
- [ ] Consolidate `~/lead-gen-production`, `~/callsaver-attio-crm-schema`, and `~/callsaver-crawl4ai` into a cleaner, more tightly organized pipeline
- [ ] Define clear data flow: Cal.com booking → Google Places lookup → website scrape → CRM/profile enrichment

**4e. Manual Google Place ID Fallback**
- [ ] Add ability to manually enter a Google Place ID and pass it directly into the pipeline
- [ ] Useful when automatic search has issues or for manual corrections

**4f. Crawl4ai Server (if needed)**
- [ ] Evaluate whether an EC2 instance is needed to run crawl4ai for the automatic process
- [ ] Set up if required — flesh out when we get to this step

### 5. Demo Voice Agent (Single Twilio Number → Dynamic LiveKit Demo)

> **Note:** There should be existing documentation files in `~/callsaver-api` related to this demo approach from a prior Windsurf Cascade session. Review those first before building.

One Twilio phone number serves as the demo line. When someone calls, the system dynamically determines what demo to give them based on caller identification.

**5a. Caller Identification via Attio CRM**
- [ ] On inbound call, cross-reference the caller's phone number against Attio CRM
- [ ] Search both Organization phone numbers and associated People record phone numbers
- [ ] If match found: dynamically configure the LiveKit demo agent for that specific business

**5b. Voice-Based Fallback — Business Name Search**
- [ ] If caller not found in Attio, have the agent ask them to speak the name of their business
- [ ] Use a tool call to search Attio CRM by business name
- [ ] If match found: proceed with a personalized demo for that business

**5c. General Field Service Fallback — Category Selection**
- [ ] If Attio search also fails, fall back to a general field service demo
- [ ] Have the caller indicate their business category (e.g., electrician, plumbing, HVAC, etc.)
- [ ] Use the 47 custom CallSaver categories defined in `~/callsaver-api` to match and configure the demo dynamically

**5d. Call Length Limiting**
- [ ] Implement a max call duration for demo calls (e.g., 5–10 minutes)

**5e. Review Existing Documentation**
- [ ] Check `~/callsaver-api` for existing demo approach docs from prior Cascade session

### 6. OpenScreen Demo Recording (after staging is fixed)
- [ ] Use https://openscreen.vercel.app/ to record a demo of the application
- [ ] Iterate on a script / flow for what to show users
- [ ] May require multiple takes and revisions

---

## 📱 Phase 4: Also Do Today

### Storyblocks Video Background — 🎯 DO TODAY
- [ ] Purchase 1-month Storyblocks subscription
- [ ] Find and download a new video background
- [ ] Integrate into `~/callsaver-landing` hero section

### Phone Organization — 🎯 DO TODAY
- [ ] Create "Finance" app folder: Rocket Money, Kikoff, Self, Capital One, Chime, Discover, CreditKarma
- [ ] Reorganize apps for productivity, remove distractions
- [ ] Set up home screen with essential tools (comms, dev, banking, etc.)

### Email Organization — ⏸️ DEFERRED
- [ ] Try [InboxZero](https://www.getinboxzero.com/) or similar tool for personal Gmail
- [ ] Evaluate doing the same for `alex@callsaver.ai`

### Security Freezes & Locks — ⏸️ DEFERRED (waiting on Discover card)
- [ ] **The Work Number** — myworkforce.theworknumber.com — Freeze employment data (critical for OE)
- [ ] **Equifax** — equifax.com/personal/credit-report-services/credit-freeze/
- [ ] **Experian** — experian.com/freeze/center.html
- [ ] **TransUnion** — transunion.com/credit-freeze
- [ ] **LexisNexis** — consumer.risk.lexisnexis.com — Freeze (background check / insurance data)
- [ ] **Innovis** — innovis.com/personal/securityFreeze
- [ ] **SageStream** — sagestream.com
- [ ] **SSA account** — my.ssa.gov — Lock down Social Security account
- [ ] **IRS Identity Protection PIN** — irs.gov/identity-theft-fraud-scams/get-an-identity-protection-pin
- **NOT freezing:** ChexSystems (need to open bank accounts), NCTUE (need phone/utility signups)

### Financial Housekeeping
- [ ] Collect all business expenses incurred so far (formation fees, SaaS, infra, etc.)
- [ ] Document each expense with date, amount, paid-by, and category
- [ ] Create accounting / reimbursement plan (reference mom's card member loan protocol in `business-formation-checklist.md`)
- [ ] Plan for IRS §195 startup expense deduction (up to $5,000 first year)

---

## 📋 Phase 5: Marketing & Growth (When Time Permits)

### SEMrush Account & SEO/Marketing Tools
- [ ] Create a SEMrush account (free tier or trial to start)
- [ ] Useful SEMrush tools to explore:
  - **Keyword Research** — Find what terms field service businesses search for (e.g., "AI answering service", "virtual receptionist for plumbers")
  - **Competitor Analysis** — Analyze competitors like broccoli.com, lace.ai (organic keywords, traffic estimates, backlink profiles)
  - **Site Audit** — Crawl callsaver.ai for technical SEO issues (broken links, missing meta tags, crawl errors)
  - **Position Tracking** — Track callsaver.ai rankings for target keywords over time
  - **Backlink Analytics** — See who links to competitors and find link-building opportunities
  - **On-Page SEO Checker** — Get specific recommendations per page for improving rankings
  - **Content Marketing Toolkit** — Topic research for blog posts that could drive organic traffic
  - **Advertising Research** — See what Google Ads competitors are running
  - **Brand Monitoring** — Track mentions of "CallSaver" across the web
  - **Social Media Toolkit** — Schedule and analyze social posts
  - **Listing Management** — Distribute business info to directories
- [ ] **Trial strategy:** Free tier gives 10 searches/day. Pro trial is 7 days free, then $140/mo — do a focused sprint during the trial to extract max value, then decide if ongoing cost is justified

### Social Media Accounts & Ad Strategy

**Create Social Accounts for CallSaver**
- [ ] **Instagram** — Create @callsaver or similar handle
- [ ] **LinkedIn** — Create CallSaver company page
- [ ] **Facebook** — Appeal the ban (banned within 1 hour of signing up); get a Meta Pixel ID once resolved
- [ ] **Reddit** — Create a CallSaver account for community engagement

**Advertising Strategy**
- [ ] Decide on initial ad spend budget
- [ ] Evaluate ad platforms:
  - **Thumbtack** — Direct access to field service businesses looking for tools
  - **Angi (Angie's List)** — Same target market
  - **LinkedIn Ads** — B2B targeting by job title / industry (e.g., plumbing company owners)
  - **Facebook/Instagram Ads** — Broad reach, lookalike audiences (pending ban appeal)
  - **Google Ads** — Search intent targeting (e.g., "AI answering service for contractors")
  - **Reddit Ads** — Niche subreddits (r/smallbusiness, r/HVAC, r/electricians, r/plumbing)
- [ ] Prioritize platforms by cost-per-lead and relevance to field service businesses

### Flyer & Door Hanger Designs
- [ ] Design cheap, print-ready flyers for mass distribution
- [ ] Design door hangers for mass distribution
- [ ] Target areas: **San Diego** and **SF Bay Area**
- [ ] Include: QR code (`https://api.callsaver.ai/q/ac-1` or variant), value prop, CTA, phone number
- [ ] Find bulk printing service (e.g., VistaPrint, GotPrint, 4over) for en masse printing
- [ ] Plan distribution strategy for blanketing both metro areas

### San Diego Networking & Channel Partnerships

**Entrepreneurial Meetup Groups**
- [ ] Research and compile a list of all good entrepreneurial meetup groups in San Diego
- [ ] Check Meetup.com, Eventbrite, LinkedIn Events, local coworking spaces (e.g., WeWork, CommonGrounds, DeskHub)
- [ ] Look for: startup founder meetups, SaaS meetups, tech entrepreneur groups, small business owner groups
- [ ] Identify recurring events with dates/frequency and start attending

**Local Small Business Development & Marketing Agencies**
- [ ] Enumerate all local small business development agencies in San Diego
- [ ] Enumerate local marketing agencies that serve field service / home services businesses
- [ ] Evaluate partnership opportunities: referral fees, white-label, reseller incentives
- [ ] Goal: piggyback off their existing client base by offering them an incentive to push CallSaver to their clients

**Chambers of Commerce**
- [ ] Locate all San Diego area chambers of commerce:
  - San Diego Regional Chamber of Commerce
  - North San Diego Business Chamber
  - East County Chamber of Commerce
  - South County chambers (Chula Vista, National City, etc.)
  - Neighborhood/community chambers (La Jolla, Pacific Beach, etc.)
- [ ] Research membership costs and benefits
- [ ] Identify which ones have the most field service / contractor members
- [ ] Evaluate joining 1-2 for networking access and credibility

### Twilio A2P 10DLC Registration

**CallSaver's Own SMS Marketing**
- [ ] Register Prosimian Labs LLC as a Twilio Brand
- [ ] Submit A2P 10DLC Campaign registration for CallSaver marketing use case (cold outreach to leads)
- [ ] Select campaign use case type (likely "Marketing" or "Mixed")
- [ ] Ensure compliance: opt-in/opt-out mechanisms, TCPA compliance, message content guidelines

**Programmatic SMS for Platform Customers**
- [ ] Register a separate A2P campaign for platform SMS on behalf of SMB customers
- [ ] Evaluate whether to use a single shared campaign or per-customer campaigns (ISV model)
- [ ] Twilio ISV considerations: if sending on behalf of multiple businesses, may need Twilio's ISV A2P program (higher throughput, per-sub-account brand registration)
- [ ] Integrate SMS send capability into the CallSaver API and voice agent platform
- [ ] Use cases: appointment confirmations, follow-up texts after missed calls, review request SMS, marketing blasts on behalf of customers

---

## 💰 Budget Check

- **Cash remaining:** ~$404 (from $500, after Apliiq $51 + Kikoff $20 + Self $25)
- **Discover deposit needed:** $200
- **After Discover:** ~$204 buffer
- **Monthly recurring:** Kikoff $20 + Self $25 = $45/mo
- **Unemployment check incoming:** $450
