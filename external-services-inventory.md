# External Services Inventory

> **Generated:** Feb 8, 2026  
> **Source:** Cross-referenced from `~/callsaver-api`, `~/callsaver-web-ui`, `~/callsaver-landing` (package.json, .env files, source code imports, CDK stacks)  
> **Purpose:** Comprehensive audit of every external service, API, and third-party dependency used across the CallSaver stack. Use this to verify account status, API key validity, and billing before production launch.

---

## 1. Cloud Infrastructure

### 1.1 AWS (New Account Required)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ Old account suspended. New account needed (Phase 1.1) |
| **Account Email** | TBD (mom's email) |
| **Region** | `us-west-1` (all resources) |
| **Services Used** | S3, ECS/Fargate, ECR, Route 53, SES, Secrets Manager, ACM, CloudWatch, IAM, Elastic IP |
| **SDK** | `@aws-sdk/client-s3`, `@aws-sdk/client-ses`, `@aws-sdk/client-secrets-manager`, `@aws-sdk/s3-request-presigner` |
| **Env Vars** | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_SESSION_BUCKET`, `S3_BUCKET_NAME` |
| **Used In** | `callsaver-api` (backend + CDK), `callsaver-web-ui` (GitHub Actions deploy) |
| **Action** | Create new account, set up billing alerts, deploy all CDK stacks |

### 1.2 Supabase (Database + Auth)
| Detail | Value |
|--------|-------|
| **Status** | ✅ Active |
| **Project URL** | `https://arjdfatbdpegoyefdqfo.supabase.co` |
| **Services Used** | Postgres (via PgBouncer), Auth (magic links, user management) |
| **SDK** | `@supabase/supabase-js` (backend + frontend), `@prisma/client` (ORM) |
| **Env Vars (Backend)** | `DATABASE_URL`, `DIRECT_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` |
| **Env Vars (Frontend)** | `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY`, `VITE_AUTH_REDIRECT_URL` |
| **Used In** | `callsaver-api`, `callsaver-web-ui` |
| **Action** | Verify subscription tier. Custom domain `auth.callsaver.ai` requires Pro plan |

### 1.3 Upstash (Redis)
| Detail | Value |
|--------|-------|
| **Status** | ✅ Active (using local Redis sidecar in ECS, Upstash for monitoring/backup) |
| **SDK** | `@upstash/redis`, `ioredis`, `bullmq` |
| **Env Vars** | `REDIS_URL` (set to `redis://localhost:6379` in ECS — sidecar Redis container) |
| **Used In** | `callsaver-api` (BullMQ job queues, caching) |
| **Action** | Verify Upstash account status. In ECS, Redis runs as a sidecar — no external dependency |

### 1.4 Vercel (Landing Page Hosting)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ Bill lapsed — needs payment (Phase 1.5) |
| **SDK** | `@vercel/analytics`, `@vercel/speed-insights` |
| **Used In** | `callsaver-landing` (Next.js hosting) |
| **Action** | Pay bill, verify domain config points to new DNS |

---

## 2. Voice & Telephony

### 2.1 LiveKit Cloud (Voice AI Infrastructure)
| Detail | Value |
|--------|-------|
| **Status** | ✅ Active |
| **Endpoint** | `wss://callsaver-d8dm5v36.livekit.cloud` |
| **SIP Endpoint** | `sip:callsaver-d8dm5v36.pstn.livekit.cloud` |
| **Account** | ⚠️ **Investigate: which email?** May be under `scrumptiouslemur@gmail.com` or `alex@callsaver.ai` |
| **SDK (Node.js)** | `livekit-server-sdk`, `@livekit/agents`, `@livekit/agents-plugin-openai`, `@livekit/protocol` |
| **SDK (Python)** | `livekit-agents`, `livekit-plugins-openai`, `livekit-plugins-silero`, `livekit-plugins-deepgram`, `livekit-plugins-cartesia`, `livekit-plugins-assemblyai` |
| **Env Vars** | `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_SIP_ENDPOINT`, `LIVEKIT_WORKER_NAME`, `LIVEKIT_OUTBOUND_TRUNK_ID` |
| **Used In** | `callsaver-api` (SIP provisioning, server SDK), `livekit-python/` (voice agent) |
| **Google APIs Used Via Agent** | Places API (address validation), Calendar API (via Nango OAuth), Geocoding, Weather |
| **Action** | Verify account email/billing. Confirm SIP trunk + dispatch rule config |

### 2.2 Twilio (Phone Numbers + PSTN)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Delinquent (-$22)**. Currently mocked via `SKIP_TWILIO_PURCHASE=true` |
| **Account** | ⚠️ **Investigate: which email?** |
| **SDK** | `twilio` (Node.js) |
| **Env Vars** | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `SKIP_TWILIO_PURCHASE` |
| **Used In** | `callsaver-api` (phone number search/purchase, SIP trunk creation) |
| **Action** | Pay $22 balance. Verify existing phone numbers. Set `SKIP_TWILIO_PURCHASE=false` for launch |

---

## 3. AI / ML Providers

### 3.1 OpenAI
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Verify billing/account status** |
| **Account** | ⚠️ **Investigate: which email?** |
| **Model** | `gpt-4.1-mini-2025-04-14` (configurable via `OPENAI_MODEL`) |
| **SDK** | `openai` (Node.js), `livekit-plugins-openai` (Python agent) |
| **Env Vars** | `OPENAI_API_KEY`, `OPENAI_MODEL` |
| **Used In** | `callsaver-api` (category classification, LLM fallback), `livekit-python/` (primary LLM for voice agent) |
| **Action** | Verify API key works, check billing, confirm model access |

### 3.2 Google Gemini (via Google AI Studio / Vertex)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Investigate Google Cloud account — may be delinquent under `alex@callsaver.ai`** |
| **Fallback Account** | `scrumptiouslemur@gmail.com` (currently in use) |
| **SDK** | `@google/genai` (Node.js) |
| **Env Vars** | `GOOGLE_API_KEY` (shared key for Gemini + Places + Maps + Geocoding + Weather + PageSpeed) |
| **Used In** | `callsaver-api` (LLM fallback for category classification via `callLLMWithFallback()`) |
| **Action** | ⚠️ **Resolve Google Cloud account situation.** Either (a) pay delinquent `alex@callsaver.ai` account, or (b) document `scrumptiouslemur@gmail.com` as the active account. **Restrict API key** to only the specific APIs needed (see §3.2a) |

#### 3.2a Google Cloud APIs Used (restrict API key to these)
| API | Used For | Source File |
|-----|----------|-------------|
| **Gemini API** (Generative Language) | LLM fallback for category classification | `utils.ts` (callLLMWithFallback) |
| **Places API (New)** | Google Place details, business info | `utils.ts` (fetchGooglePlaceDetails) |
| **Geocoding API** | Address → lat/lng conversion | `utils.ts` (geocodeLocation) |
| **Weather API** | Current conditions for agent context | `utils.ts` (getWeather) |
| **PageSpeed Insights API** | Website performance scoring | `services/pagespeed/PageSpeedClient.ts` |
| **Maps JavaScript API** | Frontend maps UI | `callsaver-web-ui` (via `VITE_GOOGLE_MAPS_API_KEY`) |
| **Google My Business API** | Business profile sync (via Nango OAuth) | `services/google-business-profile/` |
| **Routes API** | Routing/directions (imported but may not be active) | `@googlemaps/routing` in package.json |

### 3.3 Anthropic (Claude)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Verify billing/account status** |
| **Account** | ⚠️ **Investigate: which email?** |
| **SDK** | `livekit-plugins-anthropic` (Python agent — fallback LLM) |
| **Env Vars** | `ANTHROPIC_API_KEY` |
| **Used In** | `livekit-python/` (fallback LLM via FallbackAdapter) |
| **Action** | Verify API key works and billing is current |

### 3.4 Deepgram (Speech-to-Text)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Verify billing/account status** |
| **Account** | ⚠️ **Investigate: which email?** |
| **SDK** | `livekit-plugins-deepgram` (Python agent — primary STT) |
| **Env Vars** | `DEEPGRAM_API_KEY` |
| **Used In** | `livekit-python/` (primary STT provider) |
| **Action** | Verify API key works and billing is current |

### 3.5 Cartesia (Text-to-Speech)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Verify billing/account status** |
| **Account** | ⚠️ **Investigate: which email?** |
| **SDK** | `@cartesia/cartesia-js` (Node.js — voice sample generation), `livekit-plugins-cartesia` (Python agent — primary TTS) |
| **Env Vars** | `CARTESIA_API_KEY` |
| **Used In** | `callsaver-api` (voice sample scripts), `callsaver-web-ui` (voice preview), `livekit-python/` (primary TTS) |
| **Action** | Verify API key works and billing is current |

### 3.6 AssemblyAI (Speech-to-Text — Fallback)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Verify billing/account status** |
| **Account** | ⚠️ **Investigate: which email?** |
| **SDK** | `livekit-plugins-assemblyai` (Python agent — fallback STT) |
| **Env Vars** | `ASSEMBLYAI_API_KEY` |
| **Used In** | `livekit-python/` (fallback STT via FallbackAdapter) |
| **Action** | Verify API key works and billing is current |

### 3.7 Silero (Voice Activity Detection)
| Detail | Value |
|--------|-------|
| **Status** | ✅ Open-source model, no API key needed |
| **SDK** | `livekit-plugins-silero` (Python agent) |
| **Used In** | `livekit-python/` (VAD for turn detection) |
| **Action** | None — bundled with LiveKit agent |

---

## 4. Payments & Billing

### 4.1 Stripe
| Detail | Value |
|--------|-------|
| **Status** | ✅ Active (test mode). Production mode requires DBA + EIN (Phase 3.2) |
| **Account** | ⚠️ **Investigate: which email?** |
| **SDK** | `stripe` (Node.js) |
| **Env Vars** | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_METER_ID`, 7 product IDs, 11 price IDs |
| **Frontend Env** | `VITE_STRIPE_PUBLISHABLE_KEY` (GitHub Actions secret) |
| **Used In** | `callsaver-api` (checkout, subscriptions, webhooks, billing), `callsaver-web-ui` (publishable key) |
| **Action** | Switch to production mode after DBA/EIN. Run `scripts/setup-stripe-catalog.ts` for live catalog IDs |

---

## 5. CRM & Sales

### 5.1 Attio (CRM)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ Azhar is primary account holder — migrate or transfer (Phase 3.8) |
| **SDK** | Custom API client (REST calls via `fetch`) |
| **Env Vars** | `ATTIO_API_KEY`, `FEATURE_ATTIO_SYNC_ENABLED`, `ENABLE_ATTIO_WORKERS` |
| **Used In** | `callsaver-api` (lead sync, company/person records, provisioning data) |
| **Action** | Transfer ownership or create new account. Re-generate API key |

### 5.2 Nango (OAuth Integration Hub)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Verify account status and billing** |
| **Account** | ⚠️ **Investigate: which email?** |
| **SDK** | `@nangohq/node` (backend), `@nangohq/frontend` (web UI) |
| **Env Vars** | `NANGO_SECRET_KEY` |
| **Used In** | `callsaver-api` (Google Business Profile OAuth, Google Calendar OAuth), `callsaver-web-ui` (OAuth connection UI) |
| **Action** | Verify account. Update webhook endpoints for staging/production (Phase 3.6) |

### 5.3 Cal.com (Scheduling)
| Detail | Value |
|--------|-------|
| **Status** | ✅ Active (cloud) |
| **SDK** | `@calcom/embed-react` |
| **Env Vars** | `NEXT_PUBLIC_CAL_LINK` (currently `callsaver/demo`) |
| **Custom Domain** | `book.callsaver.ai` (Phase 3.14) |
| **Used In** | `callsaver-landing` (demo booking embed) |
| **Action** | Configure custom domain. Update Cal.com link from `azharhuda/demo` to your username |

---

## 6. Email

### 6.1 AWS SES (Transactional Email — Primary)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ Requires new account + domain verification + production approval (Phase 3.4–3.5) |
| **SDK** | `@aws-sdk/client-ses` |
| **Env Vars** | `SES_FROM_EMAIL`, `SES_CONFIGURATION_SET` |
| **Sender Addresses** | `support@callsaver.ai`, `billing@callsaver.ai`, `alex@callsaver.ai`, `reports@callsaver.ai` |
| **Used In** | `callsaver-api` (`email-adapter.ts` — production email sending) |
| **Action** | Verify domain, verify senders, request production access. Fallback: Resend |

### 6.2 SendGrid (Legacy — Evaluate)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **May be deprecated — evaluate if still needed** |
| **SDK** | `@sendgrid/mail` |
| **Env Vars** | `SENDGRID_API_KEY`, `SENDGRID_FROM_EMAIL` (currently `azhar@callsaver.ai`), `SENDGRID_FROM_NAME` |
| **Used In** | `callsaver-api` (legacy email path — may be dead code) |
| **Action** | Determine if SendGrid is still used anywhere. If not, remove dependency. If yes, update sender to `alex@callsaver.ai` |

### 6.3 Google Workspace (Primary Email)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ Payment due ~March 5, 2026 (Phase 0.4) |
| **Addresses** | `alex@`, `billing@`, `legal@`, `info@`, `support@` (need to create `reports@`) |
| **Used In** | DKIM/SPF for domain email, admin access, DocuSeal SMTP relay |
| **Action** | Pay bill, export DKIM, remove `azhar@`, create `reports@` |

### 6.4 Instantly.ai (Cold Outbound)
| Detail | Value |
|--------|-------|
| **Status** | ✅ Warming up (day 3 of 14-day warm-up) |
| **Domain** | `alex@trycallsaver.com` (separate domain for cold outbound) |
| **Used In** | Not in codebase — external tool for outbound sales |
| **Action** | Continue warm-up. Monitor deliverability |

---

## 7. Monitoring & Analytics

### 7.1 Sentry (Error Tracking)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ Trial expired — needs reactivation (Phase 4.2) |
| **Account** | ⚠️ **Investigate: which email?** |
| **SDK** | `@sentry/node`, `@sentry/profiling-node` (backend), `@sentry/react`, `@sentry/vite-plugin` (frontend) |
| **Env Vars** | `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `VITE_SENTRY_DSN`, `VITE_SENTRY_ENVIRONMENT` |
| **Used In** | `callsaver-api`, `callsaver-web-ui` |
| **Action** | Reactivate subscription. Update DSN in secrets if it changed |

### 7.2 Google Analytics 4 (GA4)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Verify — may be on delinquent Google Cloud account** |
| **Env Vars** | `NEXT_PUBLIC_GA_ID` (currently `G-XXXXXXXXXX` — placeholder!) |
| **Used In** | `callsaver-landing` (pageview tracking, conversion events) |
| **Action** | Get real GA4 measurement ID. Verify GA4 property is accessible |

### 7.3 ContentSquare (UX Analytics)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Verify account status** |
| **Account** | ⚠️ **Investigate: which email?** |
| **Env Vars** | `NEXT_PUBLIC_CONTENTSQUARE_ID` = `6a46e9a377709` |
| **Used In** | `callsaver-landing` |
| **Action** | Verify account is active and script is loading |

### 7.4 GrowthBook (A/B Testing)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Verify account status** |
| **Account** | ⚠️ **Investigate: which email?** |
| **Client Key** | `sdk-q4QKAqO15Ah7qg` |
| **API Host** | `https://cdn.growthbook.io` |
| **SDK** | `@growthbook/growthbook`, `@flags-sdk/growthbook` |
| **Used In** | `callsaver-landing` (feature flags, A/B tests) |
| **Action** | Verify account access and client key validity |

### 7.5 Hotjar (Heatmaps)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Verify account status** |
| **Account** | ⚠️ **Investigate: which email?** |
| **Env Vars** | `NEXT_PUBLIC_HOTJAR_ID` (currently `XXXXXXXXX` — placeholder!) |
| **SDK** | `@hotjar/browser` |
| **Used In** | `callsaver-landing` |
| **Action** | Get real Hotjar site ID. May be redundant with ContentSquare |

### 7.6 Vercel Analytics + Speed Insights
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ Tied to Vercel account (bill lapsed) |
| **SDK** | `@vercel/analytics`, `@vercel/speed-insights` |
| **Used In** | `callsaver-landing` |
| **Action** | Part of Vercel subscription — resolves when bill is paid |

---

## 8. Customer Support & Communication

### 8.1 Intercom
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **Verify subscription is active** |
| **Account** | ⚠️ **Investigate: which email?** |
| **Custom Domain** | `help.callsaver.ai` (Phase 3.15) |
| **Env Vars** | `INTERCOM_ACCESS_TOKEN`, `INTERCOM_CLIENT_SECRET` |
| **Used In** | `callsaver-api` (webhook-driven ticket emails, lead enrichment) |
| **Action** | Verify subscription. Configure custom domain. Update webhook endpoints |

### 8.2 Web Push Notifications (VAPID)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ **VAPID keys may need regeneration** |
| **SDK** | `web-push` |
| **Env Vars** | VAPID public/private keys (not in current .env — may be missing) |
| **Used In** | `callsaver-api` (`services/push-notifications.ts`) |
| **Action** | Generate VAPID keys if not present. Add to Secrets Manager |

---

## 9. Document Signing

### 9.1 DocuSeal
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ Needs redeployment on new AWS account (Phase 1.10) |
| **Self-Hosted** | `forms.callsaver.ai` (EC2 + Caddy + Docker) |
| **Env Vars** | `DOCUSEAL_API_KEY`, `DOCUSEAL_API_URL`, `DOCUSEAL_WEBHOOK_SECRET` |
| **SMTP** | Uses Google Workspace SMTP relay (`alex@callsaver.ai` + App Password) |
| **Used In** | `callsaver-api` (MSA signing flow in provision-handler.ts) |
| **Action** | Redeploy in us-west-1. Upload MSA template. Update countersigner from azhar → alex |

---

## 10. Domain & DNS

### 10.1 Namecheap (Domain Registrar)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ Domain `callsaver.ai` under Azhar's account — needs transfer (Phase 0.1) |
| **Used In** | Domain registration + nameserver config |
| **Action** | Transfer domain ownership or get credentials from Azhar |

### 10.2 AWS Route 53 (DNS)
| Detail | Value |
|--------|-------|
| **Status** | ⚠️ Old hosted zone is dead. New one needed (Phase 1.3) |
| **Used In** | All DNS records for `callsaver.ai` |
| **Action** | Create new hosted zone, recreate all DNS records (see DNS checklist in plan-a-checklist.md) |

---

## 11. CI/CD & DevOps

### 11.1 GitHub Actions
| Detail | Value |
|--------|-------|
| **Status** | ✅ Active |
| **Repos** | `callsaver-api`, `callsaver-web-ui`, `callsaver-landing` |
| **Secrets Needed** | AWS credentials, Cosign keys, Sentry DSN, Supabase keys, Stripe publishable key, Google Maps key |
| **Used In** | All repos (build, test, deploy) |
| **Action** | Update all secrets after new AWS account creation (Phase 1.19) |

### 11.2 Semantic Release
| Detail | Value |
|--------|-------|
| **Status** | ✅ Active |
| **SDK** | `semantic-release`, `@semantic-release/github`, `@semantic-release/changelog`, `semantic-release-slack-bot` |
| **Used In** | `callsaver-api` (automated versioning/changelog) |
| **Action** | Verify Slack bot webhook if using Slack notifications |

---

## 12. Google Cloud — Account Investigation

> **⚠️ CRITICAL:** The Google Cloud account situation needs immediate investigation.

### Current State
- **Primary account (`alex@callsaver.ai`)** — May be delinquent/suspended. Previously used for Google APIs (Places, Geocoding, Maps, etc.)
- **Fallback account (`scrumptiouslemur@gmail.com`)** — Currently in use to keep APIs working
- **Single API key** (`GOOGLE_API_KEY`) is used across **8 different Google APIs** (see §3.2a)

### Decision Required
| Option | Pros | Cons |
|--------|------|------|
| **A: Restore `alex@callsaver.ai` account** | Professional, scoped to business domain | May require paying delinquent balance |
| **B: Keep `scrumptiouslemur@gmail.com`** | Already working, no payment needed | Unprofessional, not scoped to business |
| **C: Create new Google Cloud project under `alex@callsaver.ai`** | Clean slate, proper scoping | Requires account to be in good standing |

### API Key Restriction Plan
Once the account is resolved, restrict the API key(s):

**Backend API Key** (server-side, `GOOGLE_API_KEY`) — restrict to:
- Gemini API (Generative Language)
- Places API (New)
- Geocoding API
- Weather API
- PageSpeed Insights API
- Google My Business API
- Routes API

**Frontend API Key** (client-side, `VITE_GOOGLE_MAPS_API_KEY`) — restrict to:
- Maps JavaScript API
- Places API (New) — if autocomplete is used in frontend

**Restriction types:**
- Backend key: **IP restriction** (restrict to ECS NAT Gateway IPs once deployed)
- Frontend key: **HTTP referrer restriction** (restrict to `*.callsaver.ai`, `localhost:*`)

---

## Summary: Account Audit Checklist

> For each service, verify: (1) which email owns the account, (2) billing is current, (3) API keys are valid.

| # | Service | Account Email | Billing Status | API Key Valid? | Priority |
|---|---------|--------------|----------------|---------------|----------|
| 1 | **AWS** | TBD (new account) | New account needed | N/A | 🔴 P0 |
| 2 | **Google Cloud** | `alex@callsaver.ai` or `scrumptiouslemur@gmail.com`? | ⚠️ Possibly delinquent | ⚠️ Verify | 🔴 P0 |
| 3 | **Twilio** | ? | ⚠️ Delinquent (-$22) | ⚠️ Verify | 🔴 P0 |
| 4 | **Stripe** | ? | ✅ Active (test mode) | ✅ Working | 🟡 P1 |
| 5 | **OpenAI** | ? | ⚠️ Verify | ⚠️ Verify | 🟡 P1 |
| 6 | **Deepgram** | ? | ⚠️ Verify | ⚠️ Verify | 🟡 P1 |
| 7 | **Cartesia** | ? | ⚠️ Verify | ⚠️ Verify | 🟡 P1 |
| 8 | **Anthropic** | ? | ⚠️ Verify | ⚠️ Verify | 🟡 P1 |
| 9 | **AssemblyAI** | ? | ⚠️ Verify | ⚠️ Verify | 🟡 P1 |
| 10 | **LiveKit** | ? | ⚠️ Verify | ✅ Working | 🟡 P1 |
| 11 | **Sentry** | ? | ⚠️ Trial expired | ⚠️ Verify | 🟡 P1 |
| 12 | **Supabase** | ? | ✅ Active | ✅ Working | 🟢 P2 |
| 13 | **Vercel** | ? | ⚠️ Bill lapsed | N/A | 🟡 P1 |
| 14 | **Attio** | Azhar (primary) | ⚠️ Verify | ✅ Working | 🟡 P1 |
| 15 | **Nango** | ? | ⚠️ Verify | ⚠️ Verify | 🟡 P1 |
| 16 | **Intercom** | ? | ⚠️ Verify | ✅ Working | 🟡 P1 |
| 17 | **ContentSquare** | ? | ⚠️ Verify | ⚠️ Verify | 🟢 P2 |
| 18 | **GrowthBook** | ? | ⚠️ Verify | ⚠️ Verify | 🟢 P2 |
| 19 | **Hotjar** | ? | ⚠️ Verify | ⚠️ Placeholder ID | 🟢 P2 |
| 20 | **Google Workspace** | `alex@callsaver.ai` | ⚠️ Due ~March 5 | ✅ Working | 🔴 P0 |
| 21 | **Namecheap** | Azhar | ✅ Active | N/A | 🔴 P0 |
| 22 | **Instantly.ai** | ? | ✅ Active | N/A | 🟢 P2 |
| 23 | **SendGrid** | ? | ⚠️ May be deprecated | ⚠️ Verify | 🟢 P2 |
