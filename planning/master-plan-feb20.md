# CallSaver Production Launch — Master Plan (Feb 20, 2026)

> Consolidated from: `daily-consolidated.md`, `active-plan.md`, `landing-page-tasks.md`, `pipeline-plan.md`, `pre-launch-improvements.md`, `master-plan.md`, `3-day-plan-feb20-22.md`

---

## 🔴 P0 — Launch Blockers

| # | Task | Est. | Status |
|---|------|------|--------|
| 1 | **Deploy staging** — Build + push Docker images (API + Agent) with all recent changes, restart ECS | 1 hr | Not started |
| 2 | **Onboarding bug #3** — `getCurrentEnvironmentUrls()` returns production URLs on staging | 5 min | Not started |
| 3 | **Onboarding bug #5** — `POST /me/complete-onboarding` returns 404 | 20 min | Not started |
| 4 | **Jobber live voice testing** — 8 scenarios (new caller, returning caller, appointments, estimates, billing) | 3-4 hrs | Not started |
| 5 | **Staging E2E provisioning test** — Full sign-up → onboarding → provisioning → call test | 2-3 hrs | Not started |

**Estimated P0 total: ~7-8 hours**

---

## 🟡 P1 — High Priority (Before Launch)

| # | Task | Est. | Source |
|---|------|------|--------|
| 6 | **Default voice Katie → Ray** — 3 API files + 2 frontend files | 30 min | pre-launch §1 |
| 7 | **Transfer number edit modal** — Edit pencil + modal on Call Handling card | 2 hrs | pre-launch §2 |
| 8 | **First-call email → dashboard link** (not call detail page) | 10 min | pre-launch §3 |
| 9 | **AppointmentsPage source filter** — Only show CallSaver-booked events | 1.5 hrs | pre-launch §4 |
| 10 | **Remove "Active" badge** from integration cards | 15 min | pre-launch §5 |
| 11 | **Update callback reason types** — Replace `complex_issue` with `scheduling_issue` + `service_question` | 45 min | pre-launch §8 |
| 12 | **Onboarding bug #1** — Cal.com field split (`businessNameAndLocation` → `businessName` + `businessLocation`) | 30 min | daily-consolidated |
| 13 | **Onboarding bug #6** — Call forwarding placeholder shows `[your CallSaver number]` | 20 min | daily-consolidated |
| 14 | **Onboarding bug #8** — Transfer phone number auto-formatting | 15 min | daily-consolidated |
| 15 | **Google Calendar re-test** — Switch test location, verify tools, live voice test | 1.5 hrs | daily-consolidated |
| 16 | **Landing page cleanup** — Remove non-launch integrations, update grid to GCal/Jobber/HCP/Square + ServiceTitan "Coming Soon" | 1 hr | daily-consolidated |
| 17 | **CDK deferred secrets phases** — Phase 3 (reclassify config), Phase 4 (Upstash Redis), Phase 6 (converge deploy script) | 1.5 hrs | secrets-management-cleanup |
| 18 | **Webhook verification** — Cal.com, Stripe, DocuSeal, Nango configured on staging | 1 hr | daily-consolidated |
| 19 | **Nango webhooks** (staging + production) — currently only points to ngrok | 30 min | active-plan 3.6 |
| 20 | **SES production access request** — takes 24-48 hrs for AWS review | 15 min | active-plan 3.5 |

**Estimated P1 total: ~10-12 hours**

---

## 🟢 P2 — Medium Priority (Nice-to-Have Pre-Launch)

| # | Task | Est. |
|---|------|------|
| 21 | **HCP adapter testing** — Get API key ($99/mo), run 34 endpoints, wire tools, voice test | 4+ hrs |
| 22 | **Square Bookings integration** — Audit adapter, create tools, test | 4+ hrs |
| 23 | **HCP API key frontend modal** — Backend endpoint + masked input UI | 2 hrs |
| 24 | **Landing page video** — Storyblocks hero background | 3 hrs |
| 25 | **Landing page content/branding** — Copy review, FAQ, audio demo, dashboard screenshot | 3 hrs |
| 26 | **Frontend TS strict mode** — Re-enable `noUnusedLocals`/`noUnusedParameters` | 1 hr |
| 27 | **Onboarding bug #2** — Email footer "CallSaver AI LLC" → "Prosimian Labs LLC" | 5 min |
| 28 | **GrowthBook A/B setup** — Wire real event tracking, hero headline test | 1 hr |
| 29 | **SEO competitive analysis** — vs broccoli.com, lace.ai | 2 hrs |
| 30 | **Mobile visual review** of landing page | 1 hr |

---

## 🔵 P3 — Production Deploy Sequence (After Staging Validated)

| # | Task | Est. |
|---|------|------|
| 31 | Create Supabase production instance (1.20) | 1 hr |
| 32 | Deploy production CDK stacks — Network, Storage, Backend, Agent (1.13) | 2 hrs |
| 33 | Create production Secrets Manager entries (1.17) | 1 hr |
| 34 | Run `setup-stripe-catalog.ts --env=production` — live catalog IDs | 30 min |
| 35 | Deploy production web UI (1.14) | 30 min |
| 36 | Configure production webhooks — Stripe, DocuSeal, Nango (3.3) | 1 hr |
| 37 | Update GitHub Actions secrets (1.19) | 30 min |
| 38 | Environment separation verification (4.6) | 30 min |
| 39 | Update login URL in landing page to `app.callsaver.ai` | 5 min |
| 40 | Upgrade Supabase to Pro + custom domain `auth.callsaver.ai` (4.20) — right before launch | 30 min |

**Estimated P3 total: ~6-7 hours**

---

## ⚪ P4 — Deferred / Post-Launch

- **HCP full testing** (blocked on $99/mo API key decision)
- **Square Bookings** full integration
- **Demo voice agent** — dynamic demo line + Attio CRM lookup
- **LiveKit interactive voice agent** in frontend (4.12b)
- **Help center / docs** (Intercom Articles, 4.8)
- **Status page** (BetterUptime/Instatus, 4.9)
- **CloudWatch alarms** (4.13)
- **CI/CD pipeline review** (4.4 — GitHub Actions deploys, Cosign keys)
- **Sentry reactivation** (4.2 — trial expired)
- **API key rotation** (4.3)
- **Google API key restriction** (0.7)
- **External service account audit** (0.8)
- **Business cards** (Moo.com order, 1.9)
- **Crawl4AI stack teardown**
- **Attio CRM workflows** (3.9, 3.10 — Operator/Scale provisioning)
- **Pricing review** (3.12)
- **A2P 10DLC** registration for SMS
- **Marketing** — SEO, social media, local outreach, print
- **Business formation** — DBA filing (blocked on CA LLC-12), expense receipts
- **Google Workspace bill** — due ~March 5, 2026
- **AWS Activate credits** — reapply after landing page polished

---

## Summary

**Estimated work to launch-ready:**
- **P0 blockers**: ~7-8 hours (deploy staging, fix 2 onboarding bugs, Jobber voice testing, staging E2E)
- **P1 high priority**: ~10-12 hours (pre-launch improvements, remaining onboarding bugs, GCal re-test, landing page cleanup, webhooks, CDK secrets, SES request)
- **P3 production deploy**: ~6-7 hours (after staging validated)

**Total: ~25 hours of work**, targeting production-ready by Feb 24-25.

**Critical path:** fix onboarding bugs → deploy staging → voice test Jobber + GCal → staging E2E → production deploy.
