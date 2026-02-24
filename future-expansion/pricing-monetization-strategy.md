# Pricing & Monetization Strategy — Maximizing Year 1 Revenue

> **Date:** 2026-02-24  
> **Status:** Strategic Analysis  
> **Scope:** Pricing model optimization, trial length, usage vs. resolution billing, Year 1 revenue maximization  
> **Reference:** Current Stripe implementation in `callsaver-api/scripts/seed-plans.ts`, `stripe-checkout-v2.ts`, `usage-reporting.ts`, `billing.ts`

---

## Table of Contents

1. [Current Pricing Model — What We Have](#1-current-pricing-model--what-we-have)
2. [Trial Length Analysis — 7 vs. 10 vs. 14 Days](#2-trial-length-analysis--7-vs-10-vs-14-days)
3. [Pricing Model Analysis — Usage vs. Resolution vs. Hybrid](#3-pricing-model-analysis--usage-vs-resolution-vs-hybrid)
4. [Revenue Maximization Playbook — Year 1](#4-revenue-maximization-playbook--year-1)
5. [Recommended Pricing Changes](#5-recommended-pricing-changes)
6. [Implementation Plan](#6-implementation-plan)
7. [Revised 4-Tier Pricing — Segment-Based Structure](#7-revised-4-tier-pricing--segment-based-structure)
8. [Pricing Transparency Strategy — What to Show vs. Hide](#8-pricing-transparency-strategy--what-to-show-vs-hide)
9. [Sales Call Pricing Tactics](#9-sales-call-pricing-tactics)

---

## 1. Current Pricing Model — What We Have

### 1.1 Plan Tiers

| | Operator | Growth | Enterprise |
|---|---|---|---|
| **Monthly** | $149/mo | $299/mo | $499/mo |
| **Annual** | $1,490/yr ($124/mo) | $2,990/yr ($249/mo) | $4,990/yr ($416/mo) |
| **Annual savings** | 2 months free | 2 months free | 2 months free |
| **Included minutes** | 0 | 100 | 100 |
| **Usage rate** | $1.15/min | $1.15/min | $1.00/min |
| **Locations** | 1 | Unlimited | Unlimited |
| **Review management** | ❌ | ❌ | ✅ |

### 1.2 Billing Mechanics (Already Built)

- **7-day free trial** on all plans (`trial_period_days: 7`)
- **$499 implementation fee** — charged as a pending invoice item at Day 7 (when trial ends)
- **"Gym Trick"** — implementation fee is **waived** if customer switches to annual during the trial
- **Usage-based billing** via Stripe Billing Meters (`callsaver_voice_minutes`)
- **Daily usage reporting** via BullMQ job at 11:59 PM UTC
- **Included minutes deduction** — Growth/Enterprise get 100 mins/mo free, Operator gets 0
- **Billable minutes** — rounded UP to nearest minute per call (`Math.ceil(seconds/60)`)

### 1.3 Current Revenue Per Customer (Estimated)

Assuming a typical field service business gets ~150 calls/month, averaging ~3 minutes each = ~450 minutes/month:

| Plan | Base | Usage (450 min - included) | Monthly Total | Annual Total |
|---|---|---|---|---|
| **Operator** | $149 | 450 × $1.15 = $517.50 | **$666.50** | **$7,998** |
| **Growth** | $299 | 350 × $1.15 = $402.50 | **$701.50** | **$8,418** |
| **Enterprise** | $499 | 350 × $1.00 = $350.00 | **$849.00** | **$10,188** |

**Key insight:** Usage revenue is 50-78% of total revenue at the Operator/Growth level. The base subscription is really just the floor — usage is where the real money is.

---

## 2. Trial Length Analysis — 7 vs. 10 vs. 14 Days

### 2.1 The Tradeoffs

| | 7 Days | 10 Days | 14 Days | 30 Days |
|---|---|---|---|---|
| **Urgency** | ★★★★★ | ★★★★ | ★★★ | ★ |
| **Time to see value** | ★★ | ★★★ | ★★★★ | ★★★★★ |
| **Conversion rate (industry avg)** | 15-20% | 18-25% | 20-30% | 10-15% |
| **Cash flow speed** | Fastest | Fast | Medium | Slow |
| **Churn risk post-trial** | Higher | Medium | Lower | Lowest |
| **Annual upsell window** | Tight | Good | Generous | Too loose |

### 2.2 The Voice Agent Problem

Your product is different from a SaaS tool people use daily. With a voice agent:
- **Day 1-2:** Customer sets up, connects Jobber/HCP, customizes agent
- **Day 3-5:** First real calls come in. Customer sees transcripts, maybe 5-15 calls.
- **Day 6-7:** Customer is JUST starting to trust the system. Maybe 20-30 total calls.

**7 days is too short for a voice agent.** The customer hasn't seen enough call volume to trust it. They've handled maybe 20-30 calls. They don't have enough data to feel the ROI.

**30 days is too long.** They'll set it up, forget about it, and cancel because they never engaged.

### 2.3 Recommendation: 10-Day Trial

**10 days is the sweet spot for voice AI.** Here's why:

1. **Two full business weeks** (Mon-Fri × 2). A field service business gets most calls Mon-Fri. 10 days guarantees they see TWO full weeks of call handling.

2. **~50-80 calls** at typical volume. Enough to build trust and see patterns ("wow, the agent booked 12 appointments this week").

3. **Still creates urgency.** 10 days feels imminent. 14 days feels like "I have time." 10 days is psychologically closer to a week than to two weeks.

4. **Better annual upsell window.** With 7 days, the "switch to annual to save $499" message comes too early — they haven't bought in yet. At day 7-8 of a 10-day trial, they've seen enough value and the urgency of the trial ending pushes them to commit.

5. **Data supports it.** B2B SaaS companies with complex products (that need integration/setup time) see highest conversion with 10-14 day trials. Voice AI is a "complex product that needs trust," putting it in the 10-day camp.

### 2.4 Trial Communication Cadence (10 Days)

```
Day 0:   Welcome email + setup guide
Day 1:   "Your agent handled its first call!" (triggered by first call)
Day 3:   Weekly summary: calls handled, appointments booked, time saved
Day 5:   Mid-trial check-in: "Here's what your agent has done so far"
Day 7:   "3 days left! Switch to annual and save $499 + 2 months free"
Day 8:   Social proof: "Businesses like yours save X hours/week with CallSaver"
Day 9:   Urgency: "Your trial ends tomorrow. Don't lose your AI receptionist."
Day 10:  Trial ends → first charge
```

### 2.5 Code Change Required

In `stripe-checkout-v2.ts`:

```typescript
// Change from:
trial_period_days: 7,
// To:
trial_period_days: 10,
```

And in `provision-execution.ts`:

```typescript
// Change from:
trialEndsAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
// To:
trialEndsAt = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000);
```

And the implementation fee scheduling in `stripe-checkout-v2.ts`:

```typescript
// Change from:
const implementationFeeDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
// To:
const implementationFeeDate = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000);
```

**Total code change: 3 lines.** Can do it in 5 minutes.

---

## 3. Pricing Model Analysis — Usage vs. Resolution vs. Hybrid

### 3.1 Current Model: Base + Usage (Per-Minute)

**How it works:** Monthly subscription + $1.00-1.15 per billable minute of call time.

**Pros:**
- Simple to explain: "You pay for what you use"
- Predictable revenue per minute of call time
- Aligns cost with our actual costs (LiveKit + LLM tokens scale with minutes)
- No gaming or attribution disputes
- Already fully implemented and working

**Cons:**
- Customers can't predict their bill (usage anxiety)
- High-volume businesses might feel penalized
- Doesn't directly tie to VALUE delivered (a 5-minute call that books a $5,000 job pays the same as a 5-minute spam call)

### 3.2 Resolution-Based Model (Intercom Fin Style)

**How it would work:** Charge per "resolution" — e.g., per appointment booked, per lead created, or per qualified call handled.

**Intercom charges $0.99 per resolution.** Their definition: "A resolution is when Fin successfully handles a customer conversation without human intervention."

**For CallSaver, resolutions could be:**
- Appointment/assessment booked → $5-15
- Lead/service request created → $3-8
- Customer inquiry answered → $1-3
- Call successfully handled (any outcome) → $2-5

**Pros:**
- Directly ties cost to value delivered
- Sounds compelling in sales: "You only pay when we book you an appointment"
- Higher perceived value per unit

**Cons — and this is where it gets DANGEROUS:**

1. **Attribution gaming (your concern is valid).** A business could:
   - Change the lead source in Jobber/HCP after CallSaver creates it
   - Mark appointments as "walk-in" instead of "phone booking"
   - Dispute which calls were "real" resolutions
   - Cancel appointments we booked and rebook them manually

2. **Definition disputes.** "That wasn't a REAL resolution — the customer called back the next day." Every edge case becomes a billing argument.

3. **Perverse incentives for US.** If we charge per booking, our agent is incentivized to book aggressively even when it shouldn't. This degrades call quality.

4. **Revenue volatility.** A slow month = low revenue for us, even though our infrastructure costs are fixed. Per-minute billing is more stable.

5. **Technical complexity.** We'd need bulletproof attribution tracking, dispute resolution workflows, and reconciliation systems. That's 2-4 weeks of engineering that doesn't ship features.

6. **Doesn't work for all call types.** Many valuable calls don't result in a "resolution":
   - Customer calling to check appointment status → no booking, but still valuable
   - Customer asking about services/pricing → no booking yet, but top-of-funnel
   - Existing customer calling with a question → retention value, not a "resolution"

### 3.3 Revenue Share Model

**How it would work:** Take a % of the revenue from jobs booked through CallSaver.

**Pros:**
- Maximum alignment with customer value
- Sounds amazing: "We make money when YOU make money"
- Potentially enormous upside (a $5,000 HVAC job at 5% = $250 per booking)

**Cons — this is a minefield:**

1. **Your exact concern: gaming.** They can change lead sources, attribute jobs to other channels, modify job values, split invoices, or simply not report accurate revenue.

2. **You'd need access to their invoice/revenue data** — most CRM APIs don't expose this, or businesses won't grant it.

3. **Revenue timing.** Jobs can take weeks/months to complete and invoice. You'd be waiting months to get paid.

4. **Legal complexity.** Revenue share arrangements need contracts, auditing rights, and dispute resolution. Not something you want with 10,000 SMBs.

5. **Customer resistance.** Business owners HATE sharing revenue. They'd rather pay a predictable fee than give you a cut of their income.

### 3.4 Recommendation: KEEP Usage-Based, But Evolve It

**Stick with Base + Usage (per-minute) for now. Here's why:**

1. **It's already built and working.** Don't change what works pre-launch.
2. **It's ungameable.** Call minutes are measured by LiveKit, not by the customer.
3. **It scales with our costs.** More minutes = more LiveKit/LLM cost, and we're charging for it.
4. **It's simple to explain.** No attribution disputes.

**BUT — evolve it over time with these tweaks:**

### 3.5 Phase 2 Enhancement: "Success Metrics" Dashboard (Not Billing)

Instead of CHARGING per resolution, **SHOW** resolutions as proof of value:

```
┌─────────────────────────────────────────────────┐
│ This Month's ROI                                 │
│                                                  │
│ 📞 142 calls handled                            │
│ 📅 34 appointments booked (estimated value: $17K)│
│ 📋 18 service requests created                   │
│ ⏱️  47 hours saved (vs. manual answering)        │
│                                                  │
│ Your CallSaver cost: $701                        │
│ Estimated revenue generated: $17,000             │
│ ROI: 24:1                                        │
└─────────────────────────────────────────────────┘
```

This is WAY more powerful than charging per resolution. You're showing them a 24:1 ROI on their $701 bill. They'll NEVER cancel.

### 3.6 Phase 3 Enhancement: Volume Tiers (Reduce Per-Minute Rate at Scale)

For high-volume businesses that feel penalized:

```
Minutes 1-200:     $1.15/min (standard)
Minutes 201-500:   $0.95/min
Minutes 501-1000:  $0.75/min
Minutes 1001+:     $0.60/min
```

This keeps usage-based pricing but rewards growth. The customer's effective rate decreases as they scale, making them feel good about growing with you.

---

## 4. Revenue Maximization Playbook — Year 1

### 4.1 How to Make the MOST Money in Year 1

The formula is simple:

```
Year 1 Revenue = Customers × ARPU × Months Active
```

The levers:
1. **Get customers faster** (shorter sales cycle, better onboarding)
2. **Higher ARPU** (upsell annual, increase usage, add-on features)
3. **Retain longer** (reduce churn, prove ROI)

### 4.2 Lever 1: Maximize Annual Conversions

**Annual billing is your #1 revenue lever.** Here's the math:

| Scenario | Monthly Revenue | Annual Revenue |
|---|---|---|
| 100 customers, all monthly Growth ($299) | $29,900/mo | $358,800 |
| 100 customers, 40% annual Growth ($2,990) | $17,940 + $9,967 = $27,907/mo equivalent | **$334,880** upfront cash better |
| 100 customers, all monthly Growth + usage ($701) | $70,100/mo | $841,200 |
| 100 customers, 40% annual + usage | Higher retention → ~$900K+ | **Best scenario** |

Wait — monthly actually generates more revenue if they stay. So why push annual?

**Because of churn.** Monthly customers churn at 5-8% per month in SMB SaaS. Annual customers churn at 1-3% per YEAR. Over 12 months:

```
100 monthly customers at 6% monthly churn:
  Month 1:  100  Month 4:  79  Month 7:  63  Month 10: 50  Month 12: 44
  Total customer-months: ~850

100 annual customers at 0% churn (locked in):
  All 12 months: 100 customers
  Total customer-months: 1,200
```

**Annual customers generate 41% more customer-months.** Plus you get cash upfront.

**Action items for annual maximization:**
- Keep the "Gym Trick" (waive $499 fee for annual) — it's brilliant
- Add in-app banner during trial: "Switch to annual and save $797" (2 months + $499)
- Send targeted emails at Day 5 and Day 8 of trial with savings calculator
- Consider sweetening: add 1 month free on top of the 2 months (so annual = 10 months price for 12 months)

### 4.3 Lever 2: Push Customers to Growth/Enterprise

Most customers will start on Operator ($149). But Operator has:
- No included minutes (so the bill shock is WORSE)
- 1 location limit
- No review management

**Strategy: Make Operator painful, Growth irresistible.**

Consider adjusting Operator:
- Increase usage rate to $1.25/min (make Growth's $1.15 look like a deal)
- Add a "CallSaver branding" watermark on the voice agent greeting for Operator only ("This call is powered by CallSaver" before the business greeting)
- Limit call transcripts to last 7 days on Operator (full history on Growth+)

These create natural upgrade pressure without being punitive.

### 4.4 Lever 3: Implementation Fee as Revenue, Not Just Deterrent

The $499 implementation fee serves two purposes:
1. Revenue from monthly customers
2. Incentive to switch to annual

**Consider raising it to $699 or $799.** The higher the fee, the more powerful the annual incentive. At $799:
- Monthly customer: pays $799 + $299/mo = $4,387 year 1
- Annual customer: pays $0 + $2,990/yr = $2,990 year 1
- **Savings of $1,397 for going annual** — that's a STRONG incentive

The fee should feel real but not ridiculous. $799 is the sweet spot for B2B — it's "worth paying for done-for-you setup" but expensive enough to push annual.

### 4.5 Lever 4: Upsell Add-Ons (Post-Launch)

Once customers are active, upsell:

| Add-On | Price | Effort to Build | Revenue Impact |
|---|---|---|---|
| **GBP Review Management** | $49-99/mo | Already in Enterprise, sell separately | HIGH |
| **Website Health Audit** | $29/mo or $199 one-time | Phase 1 is 12-16 hours | MEDIUM |
| **AI Review Replies** | $29-49/mo | Part of GBP integration | MEDIUM |
| **Additional locations** | $99/mo per location | Already supported | HIGH (multi-location) |
| **AI Website Rebuild** | $499-999 one-time + $49/mo hosting | Phase 5 build | VERY HIGH |
| **Priority support** | $49/mo | Just SLA commitment | LOW effort, HIGH margin |

### 4.6 Lever 5: Reduce Churn

Every customer who doesn't churn is $8,000-10,000/year in revenue.

**Churn prevention tactics:**
1. **ROI dashboard** (Section 3.5 above) — show them the money
2. **Weekly email digest** — "Your agent handled 37 calls and booked 8 appointments this week"
3. **Proactive alerts** — "Your Google rating went from 4.2 to 4.5 since joining CallSaver"
4. **Annual lock-in** — already doing this with the Gym Trick
5. **Feature expansion** — GBP, PageSpeed, Search Console keep adding value over time
6. **Switching costs** — the more data they have in our system (calls, reviews, analytics), the harder it is to leave

### 4.7 Year 1 Revenue Projections

**Conservative scenario (50 customers by month 12):**

```
Month 1:   5 customers  × $700 avg = $3,500
Month 2:  10 customers  × $700 avg = $7,000
Month 3:  15 customers  × $700 avg = $10,500
Month 4:  20 customers  × $700 avg = $14,000
Month 5:  25 customers  × $700 avg = $17,500
Month 6:  30 customers  × $700 avg = $21,000
Month 7:  33 customers  × $700 avg = $23,100
Month 8:  36 customers  × $700 avg = $25,200
Month 9:  39 customers  × $700 avg = $27,300
Month 10: 42 customers  × $700 avg = $29,400
Month 11: 46 customers  × $700 avg = $32,200
Month 12: 50 customers  × $700 avg = $35,000

Year 1 Total: ~$245,700
```

**Aggressive scenario (150 customers by month 12):**

```
Month 1:  10 customers  × $750 avg = $7,500
Month 2:  25 customers  × $750 avg = $18,750
Month 3:  40 customers  × $750 avg = $30,000
Month 4:  55 customers  × $750 avg = $41,250
Month 5:  70 customers  × $750 avg = $52,500
Month 6:  85 customers  × $750 avg = $63,750
Month 7:  95 customers  × $750 avg = $71,250
Month 8: 105 customers  × $750 avg = $78,750
Month 9: 115 customers  × $750 avg = $86,250
Month 10: 125 customers × $750 avg = $93,750
Month 11: 138 customers × $750 avg = $103,500
Month 12: 150 customers × $750 avg = $112,500

Year 1 Total: ~$760,000
```

**Key insight:** The difference between $245K and $760K is entirely customer acquisition speed. The pricing is fine — you need DISTRIBUTION.

---

## 5. Recommended Pricing Changes

### 5.1 Changes to Make BEFORE Launch (This Week)

| Change | Current | Recommended | Effort | Why |
|---|---|---|---|---|
| **Trial length** | 7 days | **10 days** | 3 lines of code | More calls seen, higher conversion |
| **Implementation fee** | $499 | **$699** | 1 Stripe price update | Stronger annual incentive |

That's it. **Two changes. Ship everything else as-is.**

### 5.2 Changes to Make in Month 2-3

| Change | Details | Effort |
|---|---|---|
| **ROI dashboard** | Show appointments booked, estimated revenue, hours saved | 8-12 hours |
| **In-app annual upsell banner** | "Save $997 by switching to annual" during trial | 2-3 hours |
| **Trial email sequence** | 6-email drip over 10 days (Day 0, 1, 3, 5, 7, 9) | 4-6 hours |
| **Weekly digest email** | Auto-send call summary + ROI metrics every Monday | 4-6 hours |

### 5.3 Changes to Make in Month 4-6

| Change | Details | Effort |
|---|---|---|
| **GBP as add-on** | $49/mo for Growth, included in Enterprise | Part of GBP build |
| **Volume tiers** | Graduated per-minute pricing at 200/500/1000 thresholds | 8-10 hours |
| **Website audit add-on** | $29/mo or $199 one-time | Part of web presence build |
| **Multi-vertical pricing** | Same tiers work for Legal/Wellness (minutes are minutes) | 0 hours |

### 5.4 What NOT to Change

- **Don't switch to resolution-based billing.** Usage (per-minute) is simpler, ungameable, and already built.
- **Don't add a free tier.** Free users never convert in B2B. They just consume support.
- **Don't lower prices.** $149-499/mo is cheap for a business that makes $500K-5M/year. If anything, prices are too LOW.
- **Don't add a "per-seat" charge.** You're B2B selling to SMBs with 1-10 employees. Per-seat doesn't make sense.
- **Don't charge per phone number.** Include 1 number, charge $29/mo for additional numbers. Simple.

---

## 6. Implementation Plan

### 6.1 Before Launch (This Week) — 30 minutes

1. Change `trial_period_days: 7` → `10` in `stripe-checkout-v2.ts`
2. Change `7 * 24 * 60 * 60 * 1000` → `10 * 24 * 60 * 60 * 1000` in `provision-execution.ts` (2 places)
3. Update implementation fee price in Stripe dashboard from $499 → $699
4. Update savings calculation in `billing.ts` from `499` → `699`

### 6.2 Month 1-2 Post-Launch — 20-30 hours

1. Build ROI dashboard widget (appointments booked count, estimated revenue)
2. Build trial email drip sequence (6 emails over 10 days)
3. Build weekly digest email (auto Monday morning)
4. Build in-app "Switch to annual" banner with savings calculator

### 6.3 Month 3-4 — With Vertical Expansion

1. Verify pricing works for Legal vertical (it does — minutes are minutes)
2. Add GBP Review Management as $49/mo add-on
3. Consider volume tier pricing if high-volume customers complain

---

## Appendix A: Competitive Pricing Comparison

| Competitor | What They Do | Pricing |
|---|---|---|
| **Smith.ai** | Human + AI receptionist | $292.50/mo for 30 calls ($9.75/call) |
| **Ruby** | Human receptionist | $235/mo for 50 mins, $1.75/min overage |
| **Dialzara** | AI receptionist | $29/mo + $0.50-1.50/min |
| **Goodcall** | AI phone agent | $59/mo starter, custom enterprise |
| **Rosie AI** | AI answering service | $49/mo + usage |
| **Intercom Fin** | AI chat agent | $0.99/resolution |
| **CallSaver** | AI voice agent + CRM | $149-499/mo + $1.00-1.15/min |

**Your pricing is in the premium tier** — which is correct. You're not competing with $29/mo chatbots. You're competing with $300-500/mo human answering services and replacing them entirely with better AI that also integrates with their CRM.

**The value argument:** A human receptionist costs $3,000-4,000/month full-time. Even a part-time answering service is $300-500/month and misses calls. CallSaver at $700/month (with usage) handles EVERY call, 24/7, never sick, never late, and books directly into their CRM. That's a 4-5x savings vs. a human.

## Appendix B: The "Resolution Pricing" Kill Shot

If you ever reconsider resolution pricing, here's the only way to do it safely:

**Hybrid: Base + Capped Resolution Fee**
- $149/mo base (keeps floor revenue)
- $3 per appointment/lead booked by the agent (capped at $200/mo)
- Uncapped per-minute on top

This gives the "pay for results" marketing angle while the cap prevents gaming from being worth it (max exposure is $200/mo) and the per-minute ensures you always cover costs.

But honestly — just stick with per-minute. It's working. Don't fix what isn't broken, especially before you have customers to validate assumptions.

## Appendix C: Multi-Vertical Pricing

**Good news: your pricing model works across ALL verticals without changes.**

Minutes are minutes. A 3-minute law firm intake call costs the same to process as a 3-minute HVAC scheduling call. The LLM tokens and LiveKit minutes don't care about the vertical.

The only per-vertical pricing consideration is **add-on features**:
- GBP Review Management: $49/mo (all verticals)
- Website Audit: $29/mo (all verticals)
- HIPAA Compliance Package: $99/mo (future, wellness/medical only)
- AI Website Rebuild: $499-999 one-time (all verticals)

The core plans (Operator/Growth/Enterprise) stay identical across verticals. This is operationally beautiful — one pricing page, one billing system, one set of Stripe products.

---

## 7. Revised 4-Tier Pricing — Segment-Based Structure

> **Context:** The original 3-tier model (Operator/Growth/Enterprise) has tiers that are too close together and doesn't properly segment the market. The revised structure targets four distinct customer segments.

### 7.1 Problem With Original 3 Tiers

| Tier | Price | Issue |
|---|---|---|
| Operator $149 | Solo operator | Slightly too high for $80-120K/yr businesses |
| Growth $299 | Small teams | Only $150 gap from Operator — too close |
| Enterprise $499 | Mid-market | Way too cheap for businesses doing $1-10M/yr. "Enterprise" name is wrong for this segment. |

A termite company doing $1.2M/year pays $499/month = 0.5% of revenue. He wouldn't blink at $749 or $999. Meanwhile, a solo handyman at $80K/year sees $149 as 2.2% of revenue — that's his ceiling.

### 7.2 Recommended 4-Tier Structure

| | **Starter** | **Professional** | **Business** | **Business Plus** |
|---|---|---|---|---|
| **Target segment** | Solo operators, $50-150K rev | Small teams (1-3 people), $150-500K rev | Mid-market (4-15 people), $500K-3M rev | Bigger mid-market, $3-10M rev |
| **Monthly** | **$99/mo** | **$249/mo** | **$449/mo** | **$749/mo** |
| **Annual** | $990/yr ($82/mo) | $2,490/yr ($207/mo) | $4,490/yr ($374/mo) | $7,490/yr ($624/mo) |
| **Included min** | 0 | 50 | 150 | 300 |
| **Usage rate** | $1.25/min | $1.15/min | $1.05/min | $0.90/min |
| **Locations** | 1 | 2 | 5 | Unlimited |
| **Review mgmt** | ❌ | ❌ | ✅ | ✅ |
| **Priority support** | ❌ | ❌ | ❌ | ✅ |
| **Setup fee** | $0 | $499 (waived annual) | $699 (waived annual) | $699 (waived annual) |

### 7.3 Strategic Logic of Each Tier

```
$99 Starter      → LAND    — Acquire cheaply, prove product, build case studies
$249 Professional → GROW   — Natural upgrade path, workhorse tier for small teams
$449 Business     → MONEY  — Primary revenue target, highest volume of profit
$749 Business Plus → PRESTIGE — Biggest businesses, priority service, max extraction
```

- **Starter ($99)** has no setup fee to remove all friction. $99 is the psychological "under a hundred" threshold. Deliberately limited (0 included min, highest per-minute rate, 1 location) to create natural upgrade pressure within 3-6 months.

- **Professional ($249)** is the sweet spot for a 1-3 person team. 50 included minutes means ~15-20 calls/month feel "free." Less than a part-time employee.

- **Business ($449)** is the money tier. For a business doing $500K-3M, $449/month is a rounding error. 150 included minutes, review management, and 5 locations make it the obvious choice.

- **Business Plus ($749)** exists for prestige and extraction. The $1.2M termite guy wants the "best" tier. Priority support and 300 included minutes at $0.90/min justify the premium.

### 7.4 Revenue Comparison: Old vs. New

| Customer Segment | Old Pricing (3-tier) | New Pricing (4-tier) | Delta |
|---|---|---|---|
| Solo operator (200 min/mo) | $149 + $230 = **$379** | $99 + $250 = **$349** | -$30 (land strategy) |
| Small team (350 min/mo) | $299 + $288 = **$587** | $249 + $345 = **$594** | +$7 |
| Mid-market (500 min/mo) | $499 + $350 = **$849** | $449 + $368 = **$817** | -$32 (but more conversions) |
| Bigger mid-market (700 min/mo) | $499 + $550 = **$1,049** | $749 + $360 = **$1,109** | +$60 |

Revenue per customer is roughly comparable, but you capture MORE customers at the low end and extract MORE from the high end.

### 7.5 Built-In Upgrade Pressure

The tiers are designed so that the math naturally pushes customers upward:

```
Professional at 350 min: $249 + (300 × $1.15) = $594/mo — no reviews, 2 locations
Business at 350 min:     $449 + (200 × $1.05) = $659/mo — reviews, 5 locations

Difference: only $65/mo for reviews + 3 more locations + lower per-minute rate
```

When a Professional customer hits 300+ minutes consistently, the upgrade to Business becomes the rational choice. The included minutes and lower per-minute rate make the higher tier cost nearly the same but deliver more.

### 7.6 Timing

**Don't change the code now.** Launch with the current 3 tiers this week. The 4-tier restructure is a Month 2-3 activity after real customer data reveals actual usage patterns. You might learn things that change the tier design.

---

## 8. Pricing Transparency Strategy — What to Show vs. Hide

### 8.1 The Hybrid Model: Transparent Low-End, Opaque High-End

**Landing page pricing section:**

```
Starter        → "Starting at $99/mo"     → [Start Free Trial]     ← Self-serve
Professional   → "Starting at $249/mo"    → [Start Free Trial]     ← Self-serve
Business       → "Custom"                 → [Talk to Us]           ← Sales-led
Business Plus  → "Custom"                 → [Talk to Us]           ← Sales-led
```

### 8.2 Why This Works

- **Starter and Professional are self-serve.** Anyone can sign up, pick a plan, enter a credit card. Solo guys at 2 AM don't want to "talk to sales." Low friction = high volume.

- **Business and Business Plus require a sales conversation.** The "Talk to Us" button books a Cal.com call with you. This naturally gates the mid-market.

- **Mid-market customers PREFER talking to a human.** A guy doing $1.2M/year wants to feel like he's getting a tailored solution, not picking from a menu. The sales conversation makes them feel important and builds trust.

- **The mid-market guy never sees $99.** He clicks "Talk to Us" and you control the conversation. He's not going to say "but can I get the $99 plan?" because he never saw the full price breakdown.

### 8.3 Industry Standard

This is exactly how every successful B2B SaaS does it:
- **Stripe:** Shows all prices publicly (self-serve product)
- **Salesforce:** "Contact Us" for Enterprise
- **HubSpot:** Shows Starter/Pro prices, "Talk to Sales" for Enterprise
- **Intercom:** Shows some tiers, hides enterprise pricing

You're doing the same thing. It's not sketchy — it's segment-appropriate pricing.

---

## 9. Sales Call Pricing Tactics

### 9.1 How to Present Pricing on the Call

When the mid-market customer is on the call:

> "Based on your call volume, number of locations, and what you're looking for,
> I'd recommend our Business plan at $449/month. That includes 150 minutes,
> review management, and up to 5 locations. Most businesses your size are on this tier."

Key elements:
1. **Frame it as a recommendation**, not a menu
2. **"Most businesses your size"** — social proof kills price objections
3. **Lead with what's included**, not the price
4. **Don't offer alternatives** unless they push back

### 9.2 Handling "Can I Get the Cheaper Plan?"

If a mid-market customer asks for a lower tier, don't cave — show them the math:

> "The Professional plan at $249 doesn't include review management or priority support,
> and it's capped at 2 locations. Most businesses at your volume end up going over the
> included minutes on Professional, and the per-minute rate is higher, so the total cost
> ends up similar or higher. I'd actually be doing you a disservice putting you on
> Professional. Let me show you the math."

Then show:

```
Professional: $249 + (300 overage min × $1.15) = $594/mo  — no reviews, 2 locations
Business:     $449 + (200 overage min × $1.05) = $659/mo  — reviews, 5 locations, lower rate
```

Same price, more features. The included minutes and lower per-minute rate make the higher tier the rational choice.

### 9.3 The Golden Rule: Never Discount the Base, Discount the Setup Fee

If the customer pushes back on price, **never lower the monthly**. Instead:

> "I can't adjust the monthly — the infrastructure costs are fixed. But I CAN waive
> the $699 setup fee completely if you commit today. That saves you $699 right off the bat."

This maintains price integrity while giving the customer a "win." The setup fee exists partly as a negotiation chip — it's a concession that costs you nothing but feels like a $699 savings to the customer.

### 9.4 Price Anchoring for Annual

When discussing pricing, always anchor to the monthly rate first, then present annual as the obvious choice:

> "The Business plan is $449 per month. But most of our customers go with annual
> at $4,490 — that's like getting 2 months completely free, PLUS I waive the entire
> $699 setup fee. Total savings of over $1,000 in the first year."

The $1,000+ savings number makes the decision feel urgent and rational.

### 9.5 For Your First 10-20 Customers: The "Free Until Value" Offer

For early customers ONLY (to build case studies and testimonials):

> "Free for 30 days. Not a trial — actually free. We eat the cost.
> After 30 days, if you've booked at least 10 appointments through our AI,
> you pick a plan. If not, walk away."

This is different from a standard trial because:
- No credit card required upfront (removes ALL friction)
- 30 days instead of 10 (enough to build deep trust)
- Conditional on THEM seeing results, not a calendar date

**Only do this for your first 10-20 customers.** The goal is case studies and testimonials, not revenue. Once you have 5 customers saying "this thing booked me $20K in jobs last month," you never need to give away free months again.
