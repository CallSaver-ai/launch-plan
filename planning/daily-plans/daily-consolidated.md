# Consolidated Outstanding Tasks

> **Purpose:** Single source of truth for all incomplete tasks from daily plans (Feb 11–17).
> **Generated:** Feb 17, 2026
> **Source files:** `daily-plan.md`, `daily-plan-feb-13.md`, `daily-plan-feb-14.md`, `daily-plan-feb-15.md`, `feb17-tasks.md`

---

## 🔴 Critical Path — Integration Testing & Launch Blockers

### Jobber Voice Agent Testing (from feb17-tasks)
- [ ] Restart API server + LiveKit Python agent to pick up new tools
- [ ] Verify 25 tools in agent-config response
- [ ] Query Jobber service catalog to tailor test prompts
- [ ] **Test 1.1**: Exact service match + autoSchedule OFF → unscheduled assessment
- [ ] **Test 1.2**: Service NOT offered → agent redirects/suggests alternatives
- [ ] **Test 1.3**: Fuzzy service match + autoSchedule OFF → unscheduled assessment
- [ ] **Test 1.4**: Exact match + autoSchedule ON → check availability + scheduled assessment
- [ ] **Test 2**: Returning caller — greet by name, find open request
- [ ] **Test 3**: Has appointment — "When is my appointment?", reschedule, cancel
- [ ] **Test 4**: Has estimate — "Did you send me a quote?"
- [ ] **Test 5**: Billing inquiry — "What do I owe?"
- [ ] Fix any bugs found during live testing

### Housecall Pro Adapter Testing (from feb17-tasks)
- [ ] Get HCP API key (sign up for Max plan $99/mo or sandbox)
- [ ] Create OrganizationIntegration record for test location
- [ ] Run `test-fs-endpoints.sh` against HCP adapter (34 endpoints)
- [ ] Wire HCP into `getLiveKitToolsForLocation`
- [ ] Live voice test (same scenarios as Jobber)
- [ ] Fix any HCP-specific bugs

### Google Calendar Re-Test (from feb17-tasks)
- [ ] Switch test location to google-calendar integration
- [ ] Verify agent config returns only GCal tools + base tools
- [ ] Live voice test: availability, create, cancel, update, list
- [ ] Confirm no regressions from fs-* tool additions

### Square Bookings Integration (from feb17-tasks)
- [ ] Audit existing Square Bookings adapter
- [ ] Create/update Square Bookings tools (check-availability, create, cancel, reschedule, list, get-services)
- [ ] Wire into `getLiveKitToolsForLocation`
- [ ] Create Python tool wrappers
- [ ] Test with Square sandbox + live voice calls

---

## 🟡 Onboarding / Provisioning Bugs (from daily-plan-feb-15)

| # | Issue | Priority | Est. |
|---|-------|----------|------|
| 1 | Cal.com booking fields split (`businessNameAndLocation` → `businessName` + `businessLocation`) | HIGH | 30 min |
| 2 | Email footer: "CallSaver AI LLC" → "Prosimian Labs LLC" + new address | MEDIUM | 5 min |
| 3 | `getCurrentEnvironmentUrls()` returns production URLs on staging (NODE_ENV check order) | HIGH | 5 min |
| 4 | Welcome email magic link uses production URL on staging (same root cause as #3) | HIGH | 0 min |
| 5 | `POST /me/complete-onboarding` returns 404 — route handler missing or unregistered | HIGH | 20 min |
| 6 | Call forwarding step shows `[your CallSaver number]` placeholder — phone number not on Agent record | MEDIUM | 20 min |
| 7 | Organization-specific Cartesia voice samples not generated during provisioning (defaults work) | LOW | 15-45 min |
| 8 | Transfer phone number input lacks auto-formatting (as-you-type) | MEDIUM | 10 min |

---

## 🟡 Staging E2E Validation (from daily-plan-feb-14)

### Webhook Verification
- [ ] Verify Cal.com webhook is configured: `staging.api.callsaver.ai/webhooks/cal/booking-created`
- [ ] Verify Stripe webhook is configured and receiving events
- [ ] Verify DocuSeal webhook is configured
- [ ] Verify Crawl4AI webhook is configured
- [ ] Verify Firecrawl webhook is configured
- [ ] Configure Intercom webhook (**deferred** — $39/mo, activate closer to launch)

### Twilio & LiveKit Verification
- [ ] Verify existing provisioned Twilio numbers are still active
- [ ] Verify LiveKit Cloud connection: `wss://callsaver-d8dm5v36.livekit.cloud`
- [ ] Confirm `SKIP_TWILIO_PURCHASE=false` in staging env

### Full E2E Provisioning Test
- [ ] Sign up on staging → magic link → onboarding wizard
- [ ] DocuSeal MSA flow: send → sign → webhook → S3 → countersign
- [ ] Stripe checkout: session created → test card → webhook fires
- [ ] Provisioning: Org + User + Location + categories + services + system prompt + Twilio + LiveKit SIP
- [ ] Dashboard loads with provisioned data
- [ ] **Call the provisioned Twilio number** → verify voice agent answers with correct prompt
- [ ] Verify call recording saved to `callsaver-sessions-staging` S3
- [ ] Verify CallRecord created in database
- [ ] Optional: Connect Google Calendar via Nango → test appointment scheduling

---

## 🟢 Frontend & UI (from feb17-tasks + daily-plan-feb-13)

### HCP API Key Frontend Modal
- [ ] Backend: `POST /me/integrations/housecall-pro/api-key` — validate + save encrypted
- [ ] Frontend: Modal with masked input, "Test & Save" button, link to HCP docs
- [ ] Disconnect flow: remove API key
- [ ] Security: encrypted storage, never return key to frontend after save

### Landing Page Cleanup
- [ ] Remove/hide non-launch integrations (Acuity, Calendly, etc.)
- [ ] Update integration grid to show: Google Calendar, Jobber, HCP, Square Bookings
- [ ] Add "Coming Soon" badge for ServiceTitan
- [ ] Update any "X+ integrations" copy
- [ ] Test responsive layout

### Landing Page Background Video
- [ ] Purchase 1-month Storyblocks subscription
- [ ] Find and download stock footage (home services / AI / phone calls)
- [ ] Edit into looping background video for hero section
- [ ] Optimize for web (compress, short loop)
- [ ] Replace current hero background

### Landing Page Content & Branding (from daily-plan)
- [ ] Review and update website copy (conversion optimization)
- [ ] Review features section for accuracy
- [ ] Review FAQ section answers
- [ ] Replace audio demo with better LiveKit-recorded sample
- [ ] Replace dashboard screenshot with screen recording video
- [ ] Update company logo font: Avenir Next → Inter
- [ ] Review scroll position offsets for anchor links
- [ ] Delete dead code, unused images, template leftovers

### Frontend TS Config Audit (from feb17-tasks)
- [ ] Re-enable `noUnusedLocals` and `noUnusedParameters` in tsconfig
- [ ] Fix all resulting compile errors
- [ ] Verify build passes

---

## 🔵 Infrastructure & Production Deploy (from daily-plan)

### Known Issue: Business Hours Hardcoded (from feb17-tasks)
`JobberAdapter.checkAvailability()` hardcodes 8 AM–5 PM instead of pulling from `Location.googlePlaceDetails.hours.regularOpeningHours`. Fix before launch.

### Production Deploy Sequence
1. [ ] Deploy `Callsaver-Network-production`
2. [ ] Deploy `Callsaver-Storage-production`
3. [ ] Deploy `Callsaver-Backend-production`
4. [ ] Deploy `Callsaver-Agent-production`
5. [ ] Create production Secrets Manager entries
6. [ ] Create Supabase production instance
7. [ ] Deploy production web UI
8. [ ] Update Route 53 production DNS records
9. [ ] Configure production webhooks (Stripe, DocuSeal, Nango, Intercom)
10. [ ] Final environment separation verification
11. [ ] Create production Stripe catalog (products, prices, meter, portal)
12. [ ] Set production Stripe webhook secret + 5 deferred secrets

### Crawl4AI Infrastructure Teardown
- [ ] Destroy `Crawl4AI-Shared` CDK stack (switched to Firecrawl)
- Command: `cd ~/callsaver-api/infra/cdk && npx cdk destroy Crawl4AI-Shared ...`

---

## 🟣 Pipeline & Data (from daily-plan-feb-13)

### Cal.com → Google Places Pipeline
- [ ] Configure Cal.com webhook on staging (user action in Cal.com dashboard)
- [ ] Trigger test booking to verify payload structure
- [ ] Test Google Places search with split `businessName` + `businessLocation` fields

### Demo Voice Agent (from daily-plan-feb-13)
- [ ] Build single Twilio demo line with dynamic agent configuration
- [ ] Caller ID via Attio CRM → personalized demo
- [ ] Voice-based fallback → ask for business name → Attio search
- [ ] General fallback → category selection from 47 CallSaver categories
- [ ] Implement max call duration for demo calls (5-10 min)
- [ ] Review existing demo approach docs in `~/callsaver-api`

### OpenScreen Demo Recording (from daily-plan-feb-13)
- [ ] Record product demo using https://openscreen.vercel.app/
- [ ] Iterate on script / flow for what to show users

---

## ⚪ Business & Finance (from daily-plan + daily-plan-feb-13)

### Business Formation (in progress)
- [ ] DBA "CallSaver" filing — blocked on CA LLC-12 (Statement of Information)
- [ ] CA Virtual Office (Northwest) — waiting for CA LLC-5 approval
- [ ] CA Statement of Information — file after LLC-5 approval (Form LLC-12, $20)

### Financial Housekeeping
- [ ] Collect all business expenses incurred so far
- [ ] Document each expense (date, amount, paid-by, category)
- [ ] Create accounting / reimbursement plan
- [ ] Plan for IRS §195 startup expense deduction (up to $5,000 first year)

### Personal Finance (from daily-plan-feb-13)
- [ ] Pay off $150 Capital One balance (deferred to next check)
- [ ] Set up Capital One autopay
- [ ] Request Capital One goodwill adjustment for late payment marks
- [ ] CreditKarma account for free monitoring
- [ ] Experian Boost — link bank account
- [ ] Chime Credit Builder card
- [ ] Use Rocket Money for subscription audit

---

## 📋 Marketing & Growth (from daily-plan-feb-13, low priority)

### SEO & Tools
- [ ] Create SEMrush account (free tier / trial sprint)
- [ ] Keyword research, competitor analysis, site audit

### Social Media
- [ ] Create Instagram @callsaver
- [ ] Create LinkedIn company page
- [ ] Appeal Facebook ban
- [ ] Create Reddit account for community engagement

### Local Outreach (San Diego)
- [ ] Research entrepreneurial meetup groups
- [ ] Enumerate local small business dev agencies + marketing agencies
- [ ] Research chambers of commerce membership

### Print Marketing
- [ ] Design flyers + door hangers with QR code
- [ ] Find bulk printing service
- [ ] Plan distribution strategy (San Diego + SF Bay Area)

### Twilio A2P 10DLC
- [ ] Register Prosimian Labs LLC as Twilio Brand
- [ ] Submit A2P campaign registration for CallSaver marketing
- [ ] Evaluate ISV A2P program for platform SMS on behalf of customers

---

## Suggested Execution Order

| Priority | Category | Tasks | Blocked By |
|----------|----------|-------|------------|
| **P0** | Jobber voice testing | Test scenarios 1.1–1.4, 2–5 | Restart API + agent |
| **P0** | Onboarding bugs #3/#5 | Environment URLs + complete-onboarding 404 | — |
| **P1** | HCP adapter testing | 34 endpoints + voice tests | API key ($99/mo) |
| **P1** | Onboarding bugs #1/#6 | Cal.com fields split + call forwarding placeholder | — |
| **P1** | Google Calendar re-test | Regression pass | — |
| **P2** | Square Bookings | Adapter + tools + tests | Square sandbox |
| **P2** | HCP frontend modal | API key input UI | — |
| **P2** | Landing page cleanup | Remove non-launch integrations | — |
| **P2** | Onboarding bugs #2/#8 | Email footer + phone formatting | — |
| **P3** | Landing page video | Storyblocks + hero replacement | Purchase |
| **P3** | Frontend TS audit | Strict mode + fix errors | — |
| **P3** | Staging E2E test | Full provisioning flow | Bug fixes |
| **P4** | Production deploy | CDK + secrets + DNS + webhooks | Staging validated |
| **P5** | Demo voice agent | Dynamic demo line | Post-launch |
| **P5** | Marketing & growth | SEO, social, outreach | Post-launch |
