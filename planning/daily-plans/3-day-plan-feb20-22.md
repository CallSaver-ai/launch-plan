# 3-Day Sprint Plan: Feb 20–22, 2026

> **Generated:** Feb 20, 2026
> **Sources analyzed:** daily-consolidated.md, active-plan.md, master-plan.md, pipeline-plan.md, pre-launch-improvements.md, feb20-frontend-work.md, feb17-tasks.md, plus work completed in current coding sessions.

---

## What's Been Completed (Since Feb 17)

### Feb 17–19 (Previous Sessions)
- ✅ Jobber adapter recovered from git + compile errors fixed (34 methods)
- ✅ 20 fs-* tools wired into LiveKit agent (agent config returns 23+ tools)
- ✅ Timezone bug fixed in JobberAdapter.checkAvailability()
- ✅ "Team will get back with quote" bug fixed (3 contradictory instructions)
- ✅ Integrations page refresh bug fixed (useRef hasFetchedOnce)
- ✅ Migration 030: moved config JSONB from livekit_agents to agents
- ✅ Migration 031: removed multilingual + smart denoising fields
- ✅ Noise cancellation made always-on (BVCTelephony for SIP)
- ✅ Cal.com → Attio pipeline Phase 1 code-complete (enrichment in single pass)
- ✅ Secrets management cleanup (phases 1.1-1.4, 2.1, 7 done)
- ✅ FieldServiceAdapter expanded to 34 methods
- ✅ HCP OpenAPI spec extracted (83 endpoints)

### Feb 20 (Today's Session)
- ✅ T30-T32: Caller sync (name, address, externalCustomerId/externalPlatform)
- ✅ T37: PATCH /me/locations/:locationId accepts agentConfig
- ✅ T38-T39: get-services strips pricing conditionally; system prompt excludes prices
- ✅ T43-T44: DELETE /me/integrations/:integrationType + cleanupAfterDisconnect()
- ✅ T33-T36: Onboarding reordered (Integrations=3, Services=4 conditional, Voice=5)
- ✅ T40: Field Service Settings section with toggles in LocationsPage
- ✅ T45: Disconnect button + DisconnectIntegrationDialog
- ✅ T46: API client regenerated, frontend already in sync

---

## Outstanding Work — Categorized by Priority

### 🔴 P0 — Launch Blockers (Must Do)

| # | Task | Est. | Source |
|---|------|------|--------|
| 1 | **Jobber live voice testing** — Scenarios 1.1-1.4, 2-5 (new caller, returning caller, appointments, estimates, billing) | 3-4 hrs | daily-consolidated |
| 2 | **Onboarding bugs #3/#5** — `getCurrentEnvironmentUrls()` returns prod URLs on staging; `POST /me/complete-onboarding` 404 | 30 min | daily-consolidated |
| 3 | **Staging E2E provisioning test** — Full sign-up → onboarding → provisioning → call test | 2-3 hrs | daily-consolidated |
| 4 | **Deploy staging** — Build + push Docker images with all recent changes, restart ECS | 1 hr | implied |

### 🟡 P1 — High Priority (Should Do Before Launch)

| # | Task | Est. | Source |
|---|------|------|--------|
| 5 | **Pre-launch improvements** — Default voice → Ray, first-call email → dashboard link, remove Active badge, callback reason types update | 2 hrs | pre-launch-improvements §1,3,5,8 |
| 6 | **Transfer number edit modal** — Add edit pencil + modal to Call Handling card | 2 hrs | pre-launch-improvements §2 |
| 7 | **AppointmentsPage filter** — Only show CallSaver-booked events (sharedExtendedProperty filter) | 1.5 hrs | pre-launch-improvements §4 |
| 8 | **Onboarding bugs #1/#6** — Cal.com field split (businessName+Location); call forwarding placeholder shows `[your CallSaver number]` | 45 min | daily-consolidated |
| 9 | **Google Calendar re-test** — Switch test location, verify agent config returns only GCal tools, live voice test | 1.5 hrs | daily-consolidated |
| 10 | **Landing page cleanup** — Remove non-launch integrations, update grid (GCal, Jobber, HCP, Square + ServiceTitan "Coming Soon") | 1 hr | daily-consolidated |
| 11 | **Onboarding bug #8** — Transfer phone number auto-formatting (as-you-type) | 15 min | daily-consolidated |
| 12 | **CDK deploy (deferred secrets phases)** — Phase 3 (reclassify config vs secrets), Phase 4 (Upstash Redis), Phase 6 (converge deploy script) | 1.5 hrs | secrets-management-cleanup |

### 🟢 P2 — Medium Priority (Nice to Have Pre-Launch)

| # | Task | Est. | Source |
|---|------|------|--------|
| 13 | **HCP adapter testing** — Get API key, run 34 endpoints, wire into tools, voice test | 4+ hrs | daily-consolidated (blocked on $99/mo) |
| 14 | **Square Bookings integration** — Audit adapter, create tools, wire, test | 4+ hrs | daily-consolidated (blocked on sandbox) |
| 15 | **HCP API key frontend modal** — Backend endpoint + masked input UI | 2 hrs | daily-consolidated |
| 16 | **Landing page video** — Storyblocks purchase + hero background video | 3 hrs | daily-consolidated |
| 17 | **Landing page content/branding** — Copy review, features accuracy, FAQ, audio demo, dashboard screenshot, dead code cleanup | 3 hrs | daily-consolidated |
| 18 | **Frontend TS config audit** — Re-enable noUnusedLocals/Parameters, fix errors | 1 hr | daily-consolidated |
| 19 | **Onboarding bugs #2/#7** — Email footer entity name; org-specific voice samples | 20 min | daily-consolidated |

### 🔵 P3 — Production Deploy Sequence (After Staging Validated)

| # | Task | Est. | Source |
|---|------|------|--------|
| 20 | Create Supabase production instance (1.20) | 1 hr | active-plan |
| 21 | Deploy production CDK stacks (Network, Storage, Backend, Agent) (1.13) | 2 hrs | active-plan |
| 22 | Create production Secrets Manager entries (1.17) | 1 hr | active-plan |
| 23 | Deploy production web UI (1.14) | 30 min | active-plan |
| 24 | Configure production webhooks (Stripe, DocuSeal, Nango) | 1 hr | active-plan |
| 25 | Stripe production catalog (setup-stripe-catalog.ts --env=production) | 30 min | active-plan |
| 26 | Update GitHub Actions secrets (1.19) | 30 min | active-plan |
| 27 | Environment separation verification (4.6) | 30 min | active-plan |
| 28 | SES production access request (3.5) | 15 min | active-plan |

### ⚪ P4 — Deferred / Post-Launch

- Housecall Pro full testing (blocked on $99/mo API key)
- Square Bookings full integration
- Demo voice agent (dynamic demo line + Attio CRM lookup)
- OpenScreen product demo recording
- Business formation (DBA filing blocked on CA LLC-12)
- Financial housekeeping / expense collection
- Marketing (SEO, social media, local outreach, print)
- Twilio A2P 10DLC registration
- LiveKit interactive voice agent in frontend (4.12b)
- Help center / documentation (4.8)
- Status page (4.9)
- CloudWatch alarms (4.13)
- Crawl4AI stack teardown

---

## 3-Day Execution Plan

### Day 1 — Thursday Feb 20 (Remaining Today)

**Theme: Finish Frontend + Deploy Staging**

| Time | Task | Priority |
|------|------|----------|
| Now | Fix onboarding bug #3: `getCurrentEnvironmentUrls()` prod URLs on staging (5 min) | P0 |
| +10m | Fix onboarding bug #5: `POST /me/complete-onboarding` 404 (20 min) | P0 |
| +30m | Fix onboarding bug #6: Call forwarding placeholder `[your CallSaver number]` (20 min) | P1 |
| +50m | Fix onboarding bug #8: Transfer phone number auto-formatting (15 min) | P1 |
| +1h | Pre-launch: Default voice Katie → Ray (30 min) — 3 API files + 2 frontend files | P1 |
| +1.5h | Pre-launch: First-call email → dashboard link (10 min) | P1 |
| +1.5h | Pre-launch: Remove Active badge from integration cards (15 min) | P1 |
| +2h | Pre-launch: Update callback reason types (scheduling_issue, service_question) (45 min) | P1 |
| +3h | Build + push Docker images (API + Agent) to staging ECR | P0 |
| +3.5h | Restart staging ECS services, verify health | P0 |

**Day 1 Deliverable:** All frontend bugs fixed, pre-launch improvements done, staging deployed with all recent backend + frontend changes.

---

### Day 2 — Friday Feb 21

**Theme: Live Voice Testing + Staging E2E Validation**

| Time | Task | Priority |
|------|------|----------|
| Morning | **Jobber voice test 1.1**: Exact service match + autoSchedule OFF | P0 |
| +30m | **Jobber voice test 1.2**: Service NOT offered → agent redirects | P0 |
| +1h | **Jobber voice test 1.3**: Fuzzy match + autoSchedule OFF | P0 |
| +1.5h | **Jobber voice test 1.4**: Exact match + autoSchedule ON → scheduled assessment | P0 |
| +2h | **Jobber voice test 2**: Returning caller — greet by name | P0 |
| +2.5h | **Jobber voice test 3**: Appointment queries — reschedule, cancel | P0 |
| +3h | **Jobber voice test 4**: Estimate inquiry | P0 |
| +3.5h | **Jobber voice test 5**: Billing inquiry | P0 |
| +4h | Fix any bugs found during live testing | P0 |
| +5h | **Google Calendar re-test** — Switch integration, verify tools, live voice test | P1 |
| +6.5h | **Transfer number edit modal** (pre-launch §2) | P1 |
| Evening | **AppointmentsPage filter** — sharedExtendedProperty filter (pre-launch §4) | P1 |

**Day 2 Deliverable:** All 4 launch integrations voice-tested (Jobber + GCal). Critical bugs fixed. Transfer number modal + appointments filter done.

---

### Day 3 — Saturday Feb 22

**Theme: Staging E2E + Landing Page + Production Prep**

| Time | Task | Priority |
|------|------|----------|
| Morning | **Full staging E2E test**: Sign up → magic link → onboarding → provisioning → call test | P0 |
| +2h | Verify: Call recording saved to S3, CallRecord created in DB | P0 |
| +2.5h | Fix any E2E bugs found | P0 |
| +3h | **Landing page cleanup**: Remove non-launch integrations, update grid | P1 |
| +4h | **Cal.com field split fix** (onboarding bug #1) | P1 |
| +4.5h | **CDK deferred phases**: Phase 3 (reclassify secrets), Phase 4 (Upstash), Phase 6 (converge deploy) | P1 |
| +6h | **Webhook verification**: Cal.com, Stripe, DocuSeal, Nango on staging | P1 |
| +7h | **SES production access request** (takes 24-48 hrs for review) | P1 |
| Evening | **Production deploy prep**: Create Supabase production instance (1.20), begin CDK production stacks | P3 |

**Day 3 Deliverable:** Staging fully validated end-to-end. Landing page cleaned up. CDK secrets consolidated. SES request submitted. Production deploy started.

---

## Post-Sprint Status (End of Feb 22)

### ✅ Done after 3 days:
- All onboarding bugs fixed
- All pre-launch improvements implemented
- Jobber + Google Calendar voice-tested and validated
- Staging E2E fully validated
- Landing page cleaned up for launch
- CDK secrets management cleaned up
- SES production request submitted
- Production deploy started

### ⏳ Still remaining for launch:
- Production CDK deploy (Network, Storage, Backend, Agent) — ~3 hrs
- Production secrets + webhooks — ~2 hrs
- Production web UI deploy — ~30 min
- Stripe production catalog — ~30 min
- HCP testing (blocked on API key — $99/mo decision)
- Square Bookings testing (blocked on sandbox)
- Landing page video + content polish (~6 hrs)
- Final environment separation verification

### 📅 Estimated days to production-ready: 2 more days (Feb 24-25) after this sprint
