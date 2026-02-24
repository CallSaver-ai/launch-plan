# Vertical Expansion Playbook — Prioritized Roadmap & Tactical Launch Guidance

> **Date:** 2026-02-24  
> **Status:** Strategic Planning  
> **Scope:** Which verticals to attack after field service, in what order, market analysis, HIPAA considerations, and immediate pre-launch tactical recommendations  
> **Reference:** [Multi-Vertical Architecture Evolution](./multi-vertical-architecture-evolution.md) | [GTM Strategy](./gtm-customer-acquisition-strategy.md)

---

## Table of Contents

1. [Immediate Tactical Recommendations — What to Do Before Launch](#1-immediate-tactical-recommendations)
2. [Vertical Prioritization — Ranked Expansion Order](#2-vertical-prioritization)
3. [Vertical #1 After Field Service: Legal](#3-vertical-1-legal)
4. [Vertical #2: Beauty & Wellness (Non-Medical)](#4-vertical-2-beauty--wellness)
5. [Vertical #3: Automotive Repair](#5-vertical-3-automotive-repair)
6. [Later Verticals: Hospitality, Property Management, Medical](#6-later-verticals)
7. [HIPAA Deep Dive — What Requires Compliance and What Doesn't](#7-hipaa-deep-dive)
8. [Architecture: When and How to Refactor](#8-architecture-when-and-how-to-refactor)

---

## 1. Immediate Tactical Recommendations

### 1.1 DO NOT Refactor Before Launch

The current architecture works. Jobber, HCP, and GCal integrations are battle-tested. The duplication problem (multiple copies of CallerContext, adapter patterns per vertical) is a *scaling* problem, not a *shipping* problem. You have zero customers — scaling problems are a luxury.

**Refactoring takes 37-51 hours minimum.** That's 1-2 weeks of full-time work with zero feature output. Every week you delay launch is a week competitors have to eat your lunch.

### 1.2 Ship Field Service THIS WEEK

- Deploy what you have on `main` to production
- Jobber + HCP + Google Calendar integrations
- Don't touch the adapter code — it works
- Don't create a separate branch for core refactor yet (merge hell risk)

### 1.3 What to Do in Weeks 2-4 Post-Launch

- Fix production bugs and respond to customer feedback on `main`
- Once stable (2-3 weeks post-launch), THEN consider a `feature/core-extraction` branch
- The core extraction is SMALL — see Section 8

### 1.4 Pre-Launch Code Changes (30 Minutes Total)

Only two changes to make before launching:

1. **Trial length: 7 → 10 days** (3 lines of code)
   - `stripe-checkout-v2.ts`: `trial_period_days: 7` → `10`
   - `provision-execution.ts`: two instances of `7 * 24 * 60 * 60 * 1000` → `10 * ...`

2. **Implementation fee: $499 → $699** (Stripe dashboard + 1 line)
   - Update price in Stripe dashboard
   - Update savings calculation in `billing.ts`

Everything else ships AFTER launch.

---

## 2. Vertical Prioritization

### 2.1 Ranking Table

| Rank | Vertical | ARPU Potential | Ease of Build | Ease of Customer Capture | US Market Size | Regulatory Risk | Overall Score |
|---|---|---|---|---|---|---|---|
| **#1** | **Legal** | $$$$ | Easy | Medium-High | $350B | Low | **9.2/10** |
| **#2** | **Beauty/Wellness (non-medical)** | $$$ | Easy-Medium | High | $65B | Low (if non-HIPAA) | **8.5/10** |
| **#3** | **Automotive Repair** | $$$ | Medium | High | $300B | Low | **8.0/10** |
| **#4** | **Restaurants/Hospitality** | $$ | Medium | Very High (volume) | $900B | Low | **7.5/10** |
| **#5** | **Property Management** | $$$ | Medium | Medium | $100B | Low | **7.0/10** |
| **#6** | **Medical/Wellness (HIPAA)** | $$$$ | Hard | Medium | $200B | **HIGH** | **5.5/10** |

### 2.2 Timeline

```
Month 1:      🚀 LAUNCH Field Service (Jobber, HCP, GCal)
Months 2-3:   ⚖️  Legal (Lawmatics, Clio)
Months 3-5:   💇 Beauty/Wellness non-medical (Vagaro, Boulevard)
Months 5-7:   🔧 Automotive (Tekmetric, Shopmonkey)
Months 7+:    🍽️ Restaurant/Hospitality, Property Mgmt
DEFERRED:     🏥 Medical/HIPAA-covered wellness (requires compliance investment)
```

**Throughout all of this:** GBP review management and PageSpeed audits running as cross-vertical features from Month 2 onward.

---

## 3. Vertical #1 Legal

### 3.1 Why Legal Is the Best Second Vertical

- **Cash-rich customers.** Law firms have the highest willingness to pay for software of any SMB segment. Average solo/small firm spends $5,000-15,000/year on software. A $249-449/mo CallSaver subscription is a rounding error.

- **Extremely high call volume.** Law firms live and die by incoming calls. A missed call is a missed $5,000-50,000 case. They NEED an AI receptionist.

- **Simple adapter scope.** The law adapter only needs ~8-11 methods vs. 34 for field service:
  - `findContactByPhone` — look up existing client
  - `createLead` — new potential client intake
  - `createAppointment` — schedule consultation
  - `getLeads` / `getLead` — check lead status
  - `getAppointments` — check schedule
  - `convertLeadToContact` — when lead becomes client

- **Scaffolding already exists.** `LawAdapter`, `LawAdapterRegistry`, `LawAdapterFactory`, `BaseLawAdapter` are all in the codebase. Platform directories for Lawmatics and Clio exist. The full implementation plan is written at `~/production-launch-plan/planning/legal-vertical-full-plan.md`.

- **Low regulatory risk.** Law firm intake is not HIPAA-regulated. Attorney-client privilege exists but doesn't impose technical requirements on a scheduling/intake tool.

### 3.2 Target Platforms

| Platform | Priority | Market Share | API Quality | Notes |
|---|---|---|---|---|
| **Lawmatics** | P1 | Growing fast | Good REST API | CRM + intake focused. Easiest integration. |
| **Clio** | P2 | Market leader | Excellent REST API | Full practice management. Larger customer base. |
| **MyCase** | P3 | Mid-market | Decent API | Similar to Clio. Third priority. |

### 3.3 Target Law Firm Types (by Call Volume)

| Practice Area | Calls/Month | Case Value | Fit |
|---|---|---|---|
| **Personal Injury** | Very High | $5K-500K | ★★★★★ |
| **Family Law** | High | $3K-15K | ★★★★★ |
| **Immigration** | Very High | $2K-10K | ★★★★ |
| **Criminal Defense** | High | $3K-25K | ★★★★ |
| **Real Estate** | Medium | $2K-10K | ★★★ |
| **Estate Planning** | Medium-Low | $1K-5K | ★★ |
| **Corporate/Business** | Low | High but inbound | ★ |

**Focus on personal injury + family law + immigration.** These are the highest-volume inbound call practices.

### 3.4 Go-to-Market for Legal

- Partner with **legal marketing agencies** (they serve the same firms, same channel partner model as field service)
- Get listed in **Clio's App Directory** and **Lawmatics marketplace**
- Target **state bar association advertising** and **CLE event sponsorships**
- Content: "How Law Firms Are Using AI to Never Miss a Client Call Again"

### 3.5 Estimated Build Time

**3-4 weeks to MVP.** The adapter is simple, the scaffolding exists, and the voice agent prompt is a straightforward adaptation of the field service prompt.

---

## 4. Vertical #2: Beauty & Wellness

### 4.1 Why Beauty/Wellness Is #2

- **Massive fragmented market.** 1.2M+ salons, spas, and beauty businesses in the US. Most are small (1-10 employees) and tech-unsavvy.
- **High call volume for bookings.** Despite online booking, 40-60% of salon appointments still come via phone, especially for new clients and complex services.
- **Simple scheduling problem.** The core value prop is the same as field service: answer calls, check availability, book appointments.
- **Scaffolding already exists.** `WellnessAdapter` with Vagaro, MindBody, and Boulevard platform directories are already in the codebase. `VagaroAdapter.ts` has 625 lines of code already.
- **Adapters already partially built.**

### 4.2 Target Platforms

| Platform | Priority | Market Share | API Quality | Notes |
|---|---|---|---|---|
| **Vagaro** | P1 | Largest in salon/spa | Good REST API | 625 lines already written. Easiest win. |
| **Boulevard** | P2 | Upmarket salons | Modern GraphQL API | Higher-end clientele = higher ARPU. |
| **MindBody** | P3 | Fitness + wellness | REST API | More fitness-oriented but huge user base. |
| **Zenoti** | P4 | Enterprise spas/chains | REST API | Larger businesses, more complex. |

### 4.3 Non-HIPAA Target Segments

Explicitly target businesses that are NOT HIPAA-covered entities:
- Hair salons and barbershops
- Nail salons
- Day spas (massage, facials, body treatments)
- Waxing/laser hair removal studios (cosmetic only)
- Tanning salons
- Pure cosmetic Botox/filler clinics (cash-pay only, NOT affiliated with medical practice)
- Fitness studios and gyms
- Yoga/pilates studios
- Makeup artists / beauty bars

### 4.4 Estimated Build Time

**4-5 weeks to MVP.** Adapter for Vagaro or Boulevard + voice agent adaptation + scheduling integration.

---

## 5. Vertical #3: Automotive Repair

### 5.1 Why Automotive Is #3

- **$300B market**, 280,000+ auto repair shops in the US
- **Very high call volume** — customers call to schedule, get estimates, check vehicle status
- **Asset-centric** — the `CrmAsset` model designed in the multi-vertical architecture plan fits perfectly (VIN, mileage, service history)
- **Low tech adoption** — many shops still use paper or basic tools, easy to win
- **Low regulatory risk** — no HIPAA, no special compliance

### 5.2 Target Platforms

| Platform | Priority | Notes |
|---|---|---|
| **Tekmetric** | P1 | Modern, growing fast, good API, popular with independent shops |
| **Shopmonkey** | P2 | Smaller but solid, mid-market |
| **Shop-Ware** | P3 | Established player |

### 5.3 Estimated Build Time

**4-5 weeks to MVP.**

---

## 6. Later Verticals

### 6.1 Restaurants/Hospitality (Month 7+)

- **Enormous market** ($900B) but lower ARPU — restaurants operate on thin margins
- **Very high volume** — reservations, takeout orders, questions about hours/menu
- **Hospitality adapter scaffolding exists** in the codebase
- **Challenge:** restaurants may not value a $249/mo AI receptionist when margins are 5-10%
- **Better for:** upscale restaurants, hotels, event venues (higher ARPU)

### 6.2 Property Management (Month 7+)

- **$100B market** — property managers, apartment complexes, HOAs
- **Medium call volume** — tenant inquiries, maintenance requests, leasing questions
- **Good fit** because calls are often after-hours (tenant emergencies)
- **Platforms:** AppFolio, Buildium, Rent Manager

### 6.3 Medical/HIPAA-Covered Wellness (DEFERRED)

- **Highest ARPU potential** but **highest compliance cost**
- HIPAA requires: BAA agreements, encrypted PHI storage, audit logging, breach notification, etc.
- Estimated HIPAA compliance build: 4-8 weeks + legal review ($5-15K)
- **Defer until revenue justifies the investment** (probably $500K+ ARR)

---

## 7. HIPAA Deep Dive — What Requires Compliance and What Doesn't

### 7.1 When HIPAA Applies

HIPAA applies to **covered entities** and their **business associates**. Covered entities are:
1. Health plans (insurance companies)
2. Healthcare clearinghouses
3. **Healthcare providers who transmit health information electronically** in connection with certain transactions (primarily insurance billing)

The key question is: **Does the business bill health insurance?**

### 7.2 Businesses That Are NOT HIPAA-Covered

| Business Type | HIPAA? | Why |
|---|---|---|
| Hair salons, barbershops | ❌ | Not healthcare |
| Nail salons, waxing studios | ❌ | Not healthcare |
| Day spas (massage, facials) | ❌ | Not healthcare providers |
| Fitness studios, gyms | ❌ | Not healthcare |
| Yoga/pilates studios | ❌ | Not healthcare |
| Tanning salons | ❌ | Not healthcare |
| Makeup artists, beauty bars | ❌ | Not healthcare |
| Auto repair shops | ❌ | Not healthcare |
| Law firms | ❌ | Attorney-client privilege ≠ HIPAA |
| Restaurants/hotels | ❌ | Not healthcare |
| Property management | ❌ | Not healthcare |

### 7.3 The Botox/Med Spa Question

**Not all Botox providers are HIPAA-covered.** The distinction:

| Scenario | HIPAA? | Why |
|---|---|---|
| **Botox at a dermatology clinic** that also treats medical conditions (acne, psoriasis) | **YES** | The clinic bills insurance for medical services → covered entity |
| **Botox at a plastic surgery office** that bills insurance for reconstructive procedures | **YES** | Bills insurance → covered entity |
| **Botox at a pure cosmetic med spa** — cash-pay only, no insurance billing | **Likely NO** | Not a covered entity if they don't bill insurance |
| **Botox at a salon** that offers it as an add-on service | **NO** | Not a healthcare provider |
| **Botox at a stand-alone aesthetics clinic** — fillers, laser, all cash-pay | **Likely NO** | Not transmitting health info in insurance transactions |

**The test:** If the business ONLY does cosmetic procedures and ONLY takes cash/credit (no insurance claims), they are generally NOT a covered entity under HIPAA. The fact that a licensed nurse or PA administers the treatment doesn't automatically trigger HIPAA — it's the insurance billing that matters.

**Our strategy:** Target salons, day spas, and pure-cosmetic cash-pay med spas. Explicitly **exclude** from our initial marketing:
- Medical practices (dermatology, primary care, specialists)
- Chiropractic offices (they bill insurance)
- Physical therapy clinics (they bill insurance)
- Mental health/therapy practices (they bill insurance)
- Dental offices (they bill insurance)

### 7.4 HIPAA Compliance Checklist (For When We Eventually Go There)

When revenue justifies it ($500K+ ARR), HIPAA compliance requires:

- [ ] Business Associate Agreements (BAA) with every HIPAA-covered customer
- [ ] PHI encryption at rest and in transit
- [ ] Audit logging of all PHI access
- [ ] Access controls and authentication for PHI
- [ ] Breach notification procedures (within 60 days)
- [ ] Employee training documentation
- [ ] Risk assessment and management plan
- [ ] BAAs with all subprocessors (LiveKit, OpenAI, Supabase, AWS, etc.)
- [ ] Physical safeguards (server access controls)
- [ ] Disaster recovery and data backup for PHI
- [ ] Privacy officer designation
- [ ] Annual security review

**Estimated cost:** $5-15K legal + 4-8 weeks engineering + $2-5K/year compliance maintenance.

**LiveKit HIPAA readiness:** LiveKit Cloud offers HIPAA-compliant plans with BAA. OpenAI offers BAA for Enterprise tier. AWS offers BAA. The infrastructure CAN be made compliant — it's just work and cost.

---

## 8. Architecture: When and How to Refactor

### 8.1 The 80/20 Extraction (Post-Launch, 3 Hours)

When you're stable in production (2-3 weeks after launch), the ONLY things worth extracting before vertical #2 are:

| Extract | Hours | Why |
|---|---|---|
| `CallerContext` → `src/core/types/` | 0.5 | Used identically by every vertical |
| `BaseAdapter` → `src/core/` | 0.5 | Same |
| `phoneVerification.ts` → `src/core/` | 0.5 | Same |
| `errors.ts` → `src/core/` | 0.5 | Same |
| `Organization.vertical` migration | 1.0 | Needed to route to correct adapter registry |
| **Total** | **3.0** | |

### 8.2 What to SKIP Until You Have 3+ Verticals

- Generic adapter registry (each vertical has its own registry — that's fine)
- Generic tool route builder (copy-paste from field-service-tools.ts → law-tools.ts)
- Generic Python tool generator (copy tools/fs_helpers.py → tools/law_helpers.py)
- Composable prompt builder (each vertical gets its own prompt file)
- Frontend vertical-config system (use simple conditionals)

**The pattern becomes clear after 3 verticals, not after 1.** Premature abstraction is worse than a little copy-paste.

### 8.3 Git Branch Strategy

| Phase | Branch | What |
|---|---|---|
| **Now** | `main` | Ship field service to production |
| **Weeks 2-4** | `main` | Bug fixes, customer feedback |
| **Week 3-4** | `feature/core-extraction` | 3-hour extraction, merge back to main |
| **Month 2** | `feature/legal-vertical` | Legal adapter + routes + prompts |
| **Month 3** | merge to `main` | Legal goes live alongside field service |

Don't maintain long-lived branches. Extract core, merge immediately. Build legal vertical, merge when ready. Keep `main` always deployable.

---

## Appendix: The $100M Equation (Revised)

```
Field Service:    1,000 customers × $750/mo avg = $750K MRR
Legal:              500 customers × $800/mo avg = $400K MRR
Wellness:           800 customers × $600/mo avg = $480K MRR
Automotive:         400 customers × $700/mo avg = $280K MRR
GBP Add-on:       1,500 customers × $49/mo     = $73K MRR
Website Services:   500 customers × $79/mo avg  = $39K MRR
                                                  ─────────
                                          Total:  $2.02M MRR
                                         Annual:  $24.3M ARR

× 4-6x SaaS revenue multiple at growth stage = $97M-$146M valuation
```

You don't need to be in every vertical to reach $100M. You need to be **excellent** in 4 verticals with strong cross-vertical features (GBP, website, analytics).
