# Daily Plan: February 14, 2026

> **Purpose:** Staging validation day — test everything end-to-end before moving to landing page polish, product demo recording, and production deploy.
> **Theme:** "If it doesn't work on staging, it doesn't ship."

---

## Overview

Today is about **final staging validation**. We haven't properly tested the full provisioning flow and voice agent in months. Before we touch the landing page, record a demo with OpenScreen, or deploy production infrastructure, we need confidence that the product actually works.

**Today's sequence:**
1. Configure missing webhook endpoints (Nango, Intercom) on staging
2. Deploy latest code to staging (includes Cal.com pipeline, extraction providers, all recent fixes)
3. Full E2E provisioning test (sign up → onboarding → MSA → Stripe → phone number → voice agent)
4. Test the provisioned voice agent by calling the Twilio number
5. Fix anything broken

---

## Phase 1: Webhook Configuration (30 min)

### 1a. Nango Webhook — Staging

**Cost:** Free plan available (limited to 50,000 API calls/month). Will need to upgrade after first few customers.

**Nango Dashboard:** https://app.nango.dev → Settings → Webhooks

**Staging webhook URL:**
```
https://staging.api.callsaver.ai/webhooks/nango
```

**What it handles:** OAuth connection creation events (`type: auth`, `operation: creation`). When a customer connects Google Calendar, Jobber, or Square Bookings via Nango's OAuth flow, this webhook creates/updates a `NangoConnection` record in the database.

**Auth:** HMAC-SHA256 using `NANGO_SECRET_KEY` (same key used for API calls). Signature sent in `X-Nango-Hmac-Sha256` header.

**Verification steps:**
- [ ] Add staging URL in Nango Dashboard → Webhooks
- [ ] Verify `NANGO_SECRET_KEY` is set in staging Secrets Manager (`callsaver/staging/backend/NANGO_SECRET_KEY`)
- [ ] If not in Secrets Manager, add it (get value from `.env` or Nango Dashboard → API Keys)
- [ ] Test with Nango's "Send test webhook" button if available

### 1b. Intercom Webhook — Staging (DEFERRED)

**Cost:** $39/seat/month (Essential plan). Defer until production infrastructure is deployed and closer to launch to save costs.

**Intercom Developer Hub:** https://app.intercom.com → Settings → Developers → Webhooks

**Staging webhook URL:**
```
https://staging.api.callsaver.ai/webhooks/intercom
```

**Auth:** HMAC-SHA1 using Intercom's Client Secret. Signature sent in `X-Hub-Signature` header (format: `sha1=<hex>`). The secret is `INTERCOM_CLIENT_SECRET` env var.

**Webhook topics to subscribe to:**

The codebase handles two categories of events. Subscribe to ALL of these:

**Ticket events** (trigger customer email notifications):
- [ ] `ticket.created` — sends ticket confirmation email to customer
- [ ] `ticket.admin.replied` — sends reply notification email to customer
- [ ] `ticket.closed` — sends resolution email to customer
- [ ] `ticket.state.updated` — sends status change email to customer

**Conversation events** (logged for monitoring, no emails):
- [ ] `conversation.admin.assigned`
- [ ] `conversation.admin.closed`
- [ ] `conversation.admin.noted`
- [ ] `conversation.admin.opened`
- [ ] `conversation.admin.replied`
- [ ] `conversation.admin.single.created`
- [ ] `conversation.admin.snoozed`
- [ ] `conversation.admin.unsnoozed`
- [ ] `conversation.operator.replied`
- [ ] `conversation.user.created`
- [ ] `conversation.user.replied`
- [ ] `conversation.read`
- [ ] `conversation.deleted`
- [ ] `conversation.priority.updated`
- [ ] `conversation.rating.added`
- [ ] `conversation.contact.attached`
- [ ] `conversation.contact.detached`
- [ ] `conversation_part.redacted`
- [ ] `conversation_part.tag.created`

**Verification steps:**
- [ ] Add staging URL in Intercom Developer Hub → Webhooks
- [ ] Subscribe to all topics listed above
- [ ] Verify `INTERCOM_CLIENT_SECRET` is set in staging Secrets Manager
- [ ] Verify `INTERCOM_ACCESS_TOKEN` is set in staging Secrets Manager
- [ ] Verify Intercom subscription is active (check billing)
- [ ] **DEFERRED:** Skip for now to save $39/mo. Will activate after production deploy.

### 1c. Verify Existing Webhooks

Confirm these are already configured and working:

- [ ] **Cal.com** → `https://staging.api.callsaver.ai/webhooks/cal/booking-created` (secret: `CAL_WEBHOOK_SECRET`)
- [ ] **Stripe** → `https://staging.api.callsaver.ai/webhooks/stripe` (secret: `whsec_srkDMchTTYvObB8twn2j4jIfKLS4AGbL`)
- [ ] **DocuSeal** → `https://staging.api.callsaver.ai/webhooks/docuseal` (secret: `DOCUSEAL_WEBHOOK_SECRET`)
- [ ] **Crawl4AI** → `https://staging.api.callsaver.ai/webhooks/crawl4ai` (secret: `CRAWL4AI_WEBHOOK_SECRET`)
- [ ] **Firecrawl** → `https://staging.api.callsaver.ai/webhooks/firecrawl` (secret: `FIRECRAWL_WEBHOOK_SECRET`)

---

## Phase 2: Deploy Latest Code to Staging (30 min)

### 2a. Pre-Deploy Checklist

- [ ] Ensure all recent changes are committed in `~/callsaver-api`
- [ ] Review uncommitted changes: `git status` + `git diff --stat`
- [ ] Commit and push if needed

### 2b. Deploy

```bash
echo "y" | bash ./scripts/deploy-staging-local.sh
```

### 2c. Post-Deploy Verification

- [ ] ECS service is running (check AWS Console or `aws ecs describe-services`)
- [ ] Health check passes: `curl https://staging.api.callsaver.ai/health`
- [ ] Check ECS logs for startup errors

---

## Phase 3: Re-enable Twilio & LiveKit (15 min)

### 3a. Twilio Verification

- [ ] Verify Twilio account is active (balance paid Feb 11)
- [ ] Verify existing provisioned numbers are still active: check Twilio Console → Phone Numbers
- [ ] Verify `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN` are set in staging Secrets Manager

### 3b. LiveKit Verification

- [ ] Verify LiveKit Cloud connection: `wss://callsaver-d8dm5v36.livekit.cloud`
- [ ] Verify `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL` are set in staging Secrets Manager
- [ ] Check LiveKit Cloud dashboard for agent status

### 3c. Set SKIP_TWILIO_PURCHASE=false

- [ ] Update staging env var: `SKIP_TWILIO_PURCHASE=false`
- [ ] Redeploy if this requires a task definition update

---

## Phase 4: Full E2E Provisioning Test (2-3 hours)

> This is the main event. Test the complete user journey from sign-up to making a phone call to the AI voice agent.

### 4a. Sign Up + Onboarding

- [ ] Go to `https://staging.app.callsaver.ai`
- [ ] Sign up with a test email via magic link (Supabase auth)
- [ ] Verify magic link email arrives (check SES or Mailtrap)
- [ ] Complete onboarding wizard — fill out business details
- [ ] Verify no console errors in browser DevTools

### 4b. DocuSeal MSA Flow

- [ ] Verify MSA email is sent via DocuSeal (`forms.callsaver.ai`)
- [ ] Open and sign the MSA as the customer
- [ ] Verify `submission.completed` webhook fires → check staging API logs
- [ ] Verify signed document is written to `callsaver-ai-forms` S3 bucket
- [ ] Countersign as CallSaver (alex@callsaver.ai)

### 4c. Stripe Checkout

- [ ] Verify Stripe checkout session is created after MSA signing
- [ ] Complete payment with Stripe test card: `4242 4242 4242 4242` (any future date, any CVC)
- [ ] Verify `checkout.session.completed` webhook fires
- [ ] Verify subscription is created in Stripe Dashboard (sandbox)

### 4d. Provisioning Execution

After Stripe checkout completes, the provisioning system should automatically:

- [ ] Create Organization, User, Location records in database
- [ ] Fetch business profile from `callsaver-business-profiles` S3 bucket
- [ ] Classify business categories via LLM
- [ ] Set service areas from Google Place data
- [ ] Generate system prompt and store on Agent model
- [ ] Purchase Twilio phone number (real number, not mock!)
- [ ] Create LiveKit SIP trunk for the number
- [ ] Send welcome email

**Check staging API logs for each step.** Look for errors or timeouts.

### 4e. Dashboard Verification

- [ ] Dashboard loads with provisioned data
- [ ] Location card shows correct business info
- [ ] Phone number is displayed
- [ ] Agent configuration is visible
- [ ] No 5xx errors in API logs
- [ ] No console errors in frontend

### 4f. Voice Agent Test — THE REAL TEST

- [ ] **Call the provisioned Twilio number from your phone**
- [ ] Verify the call connects to LiveKit
- [ ] Verify the AI voice agent answers
- [ ] Verify the agent uses the correct system prompt (business name, services, etc.)
- [ ] Test basic conversation flow:
  - Agent greeting
  - Ask about services
  - Ask about pricing/estimates
  - Ask to schedule an appointment (if calendar integration is connected)
  - Ask to transfer to a human
- [ ] Verify call recording is saved to `callsaver-sessions-staging` S3 bucket
- [ ] Verify CallRecord is created in database
- [ ] Check call quality — latency, voice clarity, interruption handling

### 4g. Integration Test (Optional, if time permits)

- [ ] Connect Google Calendar via Nango OAuth flow
- [ ] Verify Nango webhook fires and creates NangoConnection record
- [ ] Call the agent again and test appointment scheduling with calendar integration
- [ ] Verify appointment appears in Google Calendar

---

## Phase 5: Fix What's Broken (remainder of day)

Based on Phase 4 results, fix any issues found. Common things to watch for:

- **Auth issues** — magic link redirect loops, session problems
- **Provisioning failures** — missing env vars, API key issues, Twilio/LiveKit errors
- **Agent issues** — system prompt generation failures, missing business profile, tool call errors
- **Webhook failures** — signature verification errors, missing secrets, timeout issues
- **Email delivery** — SES sandbox limitations (can only send to verified addresses)

---

## Checklist Summary

| # | Task | Status |
|---|------|--------|
| 1a | Configure Nango staging webhook (FREE plan) | ✅ |
| 1b | Configure Intercom staging webhook + topics (DEFERRED - $39/mo) | ☐ |
| 1c | Verify existing webhooks (Cal, Stripe, DocuSeal, Crawl4AI, Firecrawl) | ☐ |
| 2 | Deploy latest code to staging | ✅ |
| 3 | Re-enable Twilio (SKIP_TWILIO_PURCHASE=false) + verify LiveKit | ✅ |
| 4a | Sign up + onboarding | ☐ |
| 4b | DocuSeal MSA flow | ☐ |
| 4c | Stripe checkout | ☐ |
| 4d | Provisioning execution | ☐ |
| 4e | Dashboard verification | ☐ |
| 4f | **Voice agent phone call test** | ☐ |
| 4g | Integration test (Google Calendar via Nango) | ☐ |
| 5 | Fix issues found | ☐ |

---

## What Comes After Today

Once staging is validated:

1. **Landing page finalization** — copy review, hero video (Storyblocks), audio demo update
2. **Product demo recording** — OpenScreen (https://openscreen.vercel.app/) screen recording of the dashboard + voice agent
3. **Production infrastructure deploy** — CDK stacks, secrets, Stripe catalog, Supabase production
4. **Production E2E test** — repeat Phase 4 on production
5. **Spin down Crawl4AI EC2 infrastructure** — switched to Firecrawl as primary website extraction provider. Tear down the Crawl4AI-Shared CDK stack (Auto Scaling Group, NLB, EC2 instances) to save on monthly AWS costs. Stack: `Crawl4AI-Shared`, endpoint: `Crawl4-Crawl-AreWIiHvB4Ad-489efb8b36b2bf13.elb.us-west-1.amazonaws.com:11235`. Command: `cd ~/callsaver-api/infra/cdk && npx cdk destroy Crawl4AI-Shared -c deploy_crawl4ai=true -c staging.certificateArn=arn:aws:acm:us-west-1:836347236108:certificate/dcc541e3-d8d4-4d88-a16c-4036b9a45952 -c openai_secret_arn=arn:aws:secretsmanager:us-west-1:836347236108:secret:callsaver/staging/backend/OPENAI_API_KEY-vEANrl`
6. **Launch** 🚀

---

## Quick Reference

| Service | Staging Webhook URL | Cost |
|---------|-------------------|------|
| Cal.com | `https://staging.api.callsaver.ai/webhooks/cal/booking-created` | Included |
| Stripe | `https://staging.api.callsaver.ai/webhooks/stripe` | Included |
| DocuSeal | `https://staging.api.callsaver.ai/webhooks/docuseal` | Included |
| Nango | `https://staging.api.callsaver.ai/webhooks/nango` | FREE (50K calls/mo) |
| Intercom | `https://staging.api.callsaver.ai/webhooks/intercom` | $39/mo (DEFERRED) |
| Crawl4AI | `https://staging.api.callsaver.ai/webhooks/crawl4ai` | Self-hosted |
| Firecrawl | `https://staging.api.callsaver.ai/webhooks/firecrawl` | Pay-as-you-go |

| Service | Auth Method | Secret Env Var |
|---------|-------------|---------------|
| Cal.com | Header: `CAL_WEBHOOK_SECRET` | `CAL_WEBHOOK_SECRET` |
| Stripe | Stripe signature | `STRIPE_WEBHOOK_SECRET` |
| DocuSeal | Header: `DOCUSEAL_WEBHOOK_SECRET` | `DOCUSEAL_WEBHOOK_SECRET` |
| Nango | HMAC-SHA256 (`X-Nango-Hmac-Sha256`) | `NANGO_SECRET_KEY` |
| Intercom | HMAC-SHA1 (`X-Hub-Signature`) | `INTERCOM_CLIENT_SECRET` |
| Crawl4AI | Header: `X-Webhook-Secret` | `CRAWL4AI_WEBHOOK_SECRET` |
| Firecrawl | HMAC-SHA256 (`X-Firecrawl-Signature`) | `FIRECRAWL_WEBHOOK_SECRET` |
