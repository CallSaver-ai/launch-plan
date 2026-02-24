# Integration Platform Comparison: Nango vs Alternatives

**Date:** Feb 20, 2026  
**Context:** Evaluating whether to stick with Nango or switch to alternatives for OAuth/integration management

---

## Executive Summary

**Recommendation: STICK WITH NANGO** ✅

Nango is the right choice for CallSaver because:
- ✅ **Open-source** with self-hosting option (cost control at scale)
- ✅ **OAuth-first** design matches your needs (Jobber, Google Calendar, HouseCall Pro, ServiceTitan)
- ✅ **Automatic token refresh** with built-in concurrency handling
- ✅ **600+ pre-built OAuth flows** including all your target platforms
- ✅ **Webhook notifications** for token refresh failures (you just need to implement the handler)
- ✅ **Developer-friendly** API and TypeScript SDK
- ✅ **No vendor lock-in** - can self-host if needed

The current issue is **not a Nango problem** - it's a missing webhook handler for `operation: "refresh"` events.

---

## Detailed Comparison

### 1. Nango (Current Choice)

**What it is:** Open-source OAuth & API integration infrastructure

**Pricing:**
- Free: 50K API calls/month
- Starter: $250/mo (500K calls)
- Growth: $750/mo (2M calls)
- Self-hosted: Free (you manage infrastructure)

**Pros:**
- ✅ **OAuth expertise** - handles all the edge cases (token rotation, concurrency, refresh failures)
- ✅ **Open-source** - can inspect code, contribute fixes, self-host
- ✅ **Automatic token refresh** - refreshes every 24hrs to prevent revocation
- ✅ **Webhook notifications** for auth failures
- ✅ **600+ pre-built integrations** (Jobber, Google, Salesforce, HouseCall Pro, etc.)
- ✅ **TypeScript SDK** - great DX
- ✅ **No data syncing overhead** - just handles auth, you control API calls
- ✅ **Distributed locking** built-in (prevents race conditions)
- ✅ **Active development** - frequent updates, responsive team

**Cons:**
- ⚠️ **Limited to OAuth/API auth** - doesn't handle data syncing or transformations
- ⚠️ **Requires webhook implementation** - you must handle refresh failure notifications
- ⚠️ **API call limits** on free tier (but reasonable for early stage)

**Best for:** Companies building custom integrations where you want full control over API logic but need OAuth handled correctly.

**CallSaver fit:** ⭐⭐⭐⭐⭐ (5/5) - Perfect match. You need OAuth for 3-4 platforms, want control over API calls, and need cost predictability.

---

### 2. Paragon

**What it is:** Embedded iPaaS (integration platform as a service)

**Pricing:**
- Startup: $500/mo (5 integrations, 10K tasks)
- Growth: $1,500/mo (15 integrations, 50K tasks)
- Enterprise: Custom

**Pros:**
- ✅ **Embedded UI** - pre-built integration marketplace for end users
- ✅ **Workflow builder** - visual workflow editor for non-technical users
- ✅ **Data transformations** - built-in mapping and transformation tools
- ✅ **Pre-built connectors** - 80+ integrations
- ✅ **Managed infrastructure** - no DevOps overhead

**Cons:**
- ❌ **Expensive** - $500/mo minimum, scales quickly
- ❌ **Vendor lock-in** - proprietary platform, can't self-host
- ❌ **Overkill for OAuth** - you're paying for workflow features you don't need
- ❌ **Task-based pricing** - every API call counts as a "task"
- ❌ **Less control** - abstraction layer limits customization

**Best for:** B2B SaaS companies that need to offer 50+ integrations to customers with minimal engineering effort.

**CallSaver fit:** ⭐⭐ (2/5) - Too expensive for your use case. You only need 3-4 integrations and want full control over API logic.

---

### 3. Hotglue

**What it is:** Embedded iPaaS focused on data syncing

**Pricing:**
- Developer: $299/mo (5 integrations, 100K records)
- Growth: $999/mo (20 integrations, 1M records)
- Enterprise: Custom

**Pros:**
- ✅ **ETL focus** - great for data syncing/warehousing
- ✅ **Pre-built transformations** - field mapping, data normalization
- ✅ **Embedded UI** - customer-facing integration catalog
- ✅ **Webhook support** - can trigger on data changes

**Cons:**
- ❌ **Expensive** - $299/mo minimum
- ❌ **Data-sync focused** - not optimized for real-time API calls
- ❌ **Record-based pricing** - not ideal for high-frequency API calls
- ❌ **Smaller integration catalog** (~50 vs Nango's 600+)
- ❌ **Vendor lock-in** - can't self-host

**Best for:** Companies syncing CRM/ERP data to data warehouses or building data-heavy integrations.

**CallSaver fit:** ⭐ (1/5) - Wrong tool. You need real-time API calls during voice calls, not batch data syncing.

---

### 4. Composio

**What it is:** AI agent tool execution platform (integrations for LLMs)

**Pricing:**
- Free: 1K actions/month
- Starter: $29/mo (10K actions)
- Pro: $99/mo (100K actions)
- Enterprise: Custom

**Pros:**
- ✅ **AI-first** - designed for LLM tool calling
- ✅ **Affordable** - cheapest option
- ✅ **150+ tools** - good coverage of common APIs
- ✅ **Function calling format** - outputs OpenAI-compatible tool schemas
- ✅ **Managed auth** - handles OAuth

**Cons:**
- ❌ **New/unproven** - launched 2024, less mature than Nango
- ❌ **AI-focused abstractions** - may not fit traditional API use cases
- ❌ **Limited customization** - tool schemas are pre-defined
- ❌ **Smaller community** - fewer resources, slower support
- ❌ **Unclear production readiness** - mostly used for prototypes/demos

**Best for:** AI agent developers who want pre-built tools for LLMs (e.g., "send email", "create calendar event").

**CallSaver fit:** ⭐⭐ (2/5) - Interesting for AI use case, but too new and unproven for production. Nango is more mature.

---

### 5. Pipedream

**What it is:** Serverless workflow automation platform (Zapier for developers)

**Pricing:**
- Free: 10K credits/month (~3K invocations)
- Basic: $19/mo (100K credits)
- Advanced: $49/mo (500K credits)
- Business: $299/mo (3M credits)

**Pros:**
- ✅ **Affordable** - generous free tier
- ✅ **Serverless** - no infrastructure management
- ✅ **2,000+ integrations** - massive catalog
- ✅ **Code-first workflows** - write Node.js/Python directly
- ✅ **Built-in OAuth** - handles auth for all integrations
- ✅ **Event-driven** - webhooks, cron, HTTP triggers

**Cons:**
- ❌ **Workflow platform** - designed for async workflows, not real-time API calls
- ❌ **Credit-based pricing** - hard to predict costs
- ❌ **Not designed for embedded use** - workflows run on Pipedream's infrastructure
- ❌ **Latency** - cold starts, not optimized for sub-second responses
- ❌ **Limited control** - can't self-host, vendor lock-in

**Best for:** Developers building internal automation workflows (e.g., "when Stripe payment succeeds, create HubSpot deal").

**CallSaver fit:** ⭐⭐ (2/5) - Wrong architecture. You need real-time API calls during voice calls, not async workflows.

---

## Use Case Analysis: CallSaver's Needs

### What you need:
1. **OAuth for 3-4 platforms** (Jobber, Google Calendar, HouseCall Pro, ServiceTitan)
2. **Real-time API calls** during voice calls (sub-second latency)
3. **Full control** over API logic (custom GraphQL queries, error handling)
4. **Token refresh handling** (automatic, with failure notifications)
5. **Cost predictability** (not task/record-based pricing)
6. **Self-hosting option** (for cost control at scale)

### How each platform fits:

| Platform | OAuth | Real-time | Control | Token Mgmt | Cost | Self-host | Score |
|----------|-------|-----------|---------|------------|------|-----------|-------|
| **Nango** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **5/5** |
| Paragon | ✅ | ⚠️ | ❌ | ✅ | ❌ | ❌ | 2/5 |
| Hotglue | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | 1/5 |
| Composio | ✅ | ✅ | ⚠️ | ✅ | ✅ | ❌ | 3/5 |
| Pipedream | ✅ | ❌ | ⚠️ | ✅ | ⚠️ | ❌ | 2/5 |

---

## Cost Projection (Year 1)

Assuming 1,000 active customers, 10 calls/customer/month, 5 API calls/call:

**Total API calls:** 1,000 × 10 × 5 = 50,000/month

| Platform | Year 1 Cost | Notes |
|----------|-------------|-------|
| **Nango** | **$0 - $3,000** | Free tier covers 50K calls. $250/mo if you exceed. Can self-host for $0. |
| Paragon | **$6,000 - $18,000** | $500/mo minimum. Each API call = 1 task. |
| Hotglue | **$3,588 - $11,988** | $299/mo minimum. Record-based pricing. |
| Composio | **$348 - $1,188** | $29/mo for 10K actions. Cheapest but unproven. |
| Pipedream | **$228 - $588** | $19/mo for 100K credits. But not designed for this use case. |

**Winner:** Nango (best value + production-ready + self-hosting option)

---

## Migration Effort (if switching from Nango)

### To Paragon: 🔴 High effort (2-3 weeks)
- Rewrite all OAuth flows
- Adapt to workflow-based architecture
- Migrate connection data
- Test all integrations

### To Hotglue: 🔴 High effort (2-3 weeks)
- Similar to Paragon
- ETL-focused, may not fit real-time use case

### To Composio: 🟡 Medium effort (1 week)
- Similar OAuth model to Nango
- Need to adapt to AI-first abstractions
- Risk: production readiness unclear

### To Pipedream: 🔴 High effort (2-3 weeks)
- Complete architecture change (async workflows vs real-time)
- May not be feasible for voice call latency requirements

---

## Recommendation: Fix Nango Implementation

**Don't switch platforms.** Your issue is a missing webhook handler, not a Nango limitation.

### What to fix:

1. **Add refresh failure webhook handler** (30 min)
   - Handle `operation: "refresh"` with `success: false`
   - Mark connection as `needs_reauth`
   - Notify user via email/dashboard

2. **Add connection health monitoring** (1 hr)
   - Add `lastRefreshAttempt`, `lastRefreshSuccess` fields to `NangoConnection`
   - Track refresh failures
   - Auto-disable integration after 3 consecutive failures

3. **Improve error messages** (30 min)
   - Already done in JobberClient improvements
   - Surface "reconnect required" errors to frontend

4. **Add re-authentication flow** (2 hrs)
   - Frontend: Show "Reconnect" button when connection is unhealthy
   - Backend: Clear old connection, initiate new OAuth flow

**Total effort:** ~4 hours vs 1-3 weeks to migrate platforms.

---

## Long-term Strategy

**Stick with Nango for now.** Re-evaluate in 12-18 months when:
- You have 10+ integrations (Paragon might make sense)
- You need embedded marketplace UI (Paragon/Hotglue)
- You need data syncing/ETL (Hotglue)
- Nango's pricing becomes prohibitive (self-host or negotiate)

**Self-hosting option:** Nango is open-source. If you hit $750/mo (2M calls), you can self-host on AWS for ~$100/mo (ECS Fargate + RDS).

---

## Conclusion

**Nango is the right choice.** The current issue is not a platform limitation - it's a missing webhook handler for token refresh failures. Implement the refresh failure webhook, add connection health monitoring, and you'll have a robust OAuth solution that scales with your business.

**Next steps:**
1. Implement Nango refresh failure webhook handler
2. Add `NangoConnection` health tracking fields
3. Build frontend re-authentication flow
4. Test with Jobber token invalidation scenarios
5. Document runbook for handling OAuth failures

**Estimated time to fix:** 4-6 hours  
**Cost to switch platforms:** 1-3 weeks + $3K-$18K/year

**Decision:** Fix Nango implementation ✅
