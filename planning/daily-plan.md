# Daily Plan: Immediate Next Steps

> **Purpose:** Daily execution plan — current focus and immediate tasks
> **For all outstanding tasks:** See active-plan.md
> **Complete reference:** See master-plan.md
> **Date:** February 10, 2026 (updated 7:20pm)

---

## Current Roadmap

**LiveKit S3 Setup → Landing Page Finalization → Local & Staging Testing → Production Deploy**

Business formation (Prosimian Labs LLC) is **substantially complete** — LLC formed, OA signed, EIN obtained, Mercury submitted, Stripe live. CA foreign LLC registration (LLC-5) submitted, waiting for approval. DBA filing blocked on CA LLC-12 (Statement of Information).

---

## ✅ Completed Today (Feb 10)

- ✅ **S3 bucket audit & code updates** — All old bucket refs fixed across `callsaver-api`, `callsaver-frontend`, `lead-gen-production`, `callsaver-docuseal`
- ✅ **IAM separation** — Created dedicated `callsaver-docuseal-s3` user for DocuSeal S3 access, removed S3 policy from `callsaver-ses-smtp`
- ✅ **Secrets Manager updated** — `SESSION_S3_BUCKET`, `docuseal/aws-access-key-id`, `docuseal/aws-secret-access-key` all corrected
- ✅ **DocuSeal EC2 updated** — New S3 credentials in `/opt/docuseal/.env`, containers restarted
- ✅ **All repos committed & pushed** — `callsaver-api`, `callsaver-frontend`, `lead-gen-production`, `callsaver-docuseal`
- ✅ **GitHub repo renamed** — `CallSaver-ai/DocuFuck` → `CallSaver-ai/docuseal`
- ✅ **GitHub Actions fix (1.19)** — Updated old account ID `086002003598` → `836347236108` in `deploy-staging.yml`
- ✅ **Wyoming LLC Formation (2.1)** — Articles of Organization filed, Operating Agreement signed via DocuSeal, EIN obtained
- ✅ **CA Foreign LLC Registration (2.8)** — Form LLC-5 filed with CA Secretary of State, waiting for approval
- ✅ **Landing Page Stripe Compliance** — Added Cancellation & Refund Policy, updated footer with Prosimian Labs LLC, deployed to Vercel
- ✅ **Fixed Navbar Scrolling** — Used scrollIntoView approach (overflow-x: clip blocked window.scrollTo), added scroll-margin-top for proper offset
- ✅ **Fixed MSA Entity Name** — Updated "CallSaver AI LLC" → "Prosimian Labs LLC, DBA CallSaver" in generate-msa-pdf.ts
- ✅ **Stripe Account Live (3.1)** — Stripe account created for Prosimian Labs LLC, using Sacramento RA address for customer support

---

## 🎯 Next Steps Today (Feb 11)

### Priority 1: Regenerate MSA PDF — ✅ COMPLETED
- ✅ Ran `npx tsx scripts/generate-msa-pdf.ts` in `~/callsaver-api`
- Generated both Inter and Figtree versions: `MSA-2026-02-11-inter.pdf`, `MSA-2026-02-11-figtree.pdf`
- Both committed to git automatically

### Priority 2: Re-upload MSA Template to DocuSeal
- Visit https://forms.callsaver.ai/admin
- Upload the Figtree MSA PDF template (`MSA-2026-02-11-figtree.pdf`)
- Test template creation with a sample submission

### Priority 3: Run Stripe Catalog Setup
- Run `pnpm run setup-stripe-catalog` in `~/callsaver-api` to generate live product/price IDs
- Update Secrets Manager with new live Stripe catalog IDs

### Priority 4: Figtree Font Size Audit
- **Reason:** Figtree renders tighter/smaller than Inter at the same font-size values. All three codebases need a visual review and potential font-size bumps.
- **`~/callsaver-landing`** — Check body text, headings, navbar, buttons, footer. Key files: `_variables.scss` (`$font-size-root`, `$font-size-base`, heading sizes), `style.scss`, component-level overrides.
- **`~/callsaver-frontend`** — Check dashboard text, sidebar, cards, form inputs, location cards. Key files: `theme.css`, `index.css`, Tailwind config, component-level `text-[]` classes.
- MSA PDF sizing confirmed OK — no changes needed.
- Adjust sizes as needed so Figtree looks as readable as Inter did previously.

---

## 🎨 Logo Font Update — ✅ COMPLETED (Feb 11, 2026)

**Simplified to 2 variants × 3 formats = 6 files:**
- `black-logo.{svg,png,webp}` — Black text (light backgrounds)
- `white-logo.{svg,png,webp}` — White text (dark backgrounds)

**All old Sandbox template logos deleted** (logo-dark, logo-light, logo-purple, logo@2x, etc.)

### Completed Steps
1. ✅ Recreated logo in Inkscape with **Figtree** font (OFL licensed)
2. ✅ Exported PNG (988×152) + WebP via CLI tools
3. ✅ Replaced in `~/callsaver-landing/public/img/` (6 files)
4. ✅ Replaced in `~/callsaver-frontend/public/` (7 files)
5. ✅ Replaced in `~/callsaver-api/email-previews/` + `public/` (3 files)
6. ✅ Updated `generate-msa-pdf.ts` — Avenir Next → configurable Inter/Figtree
7. ✅ Removed Avenir Next from frontend, added Figtree font
8. ✅ Added floating font comparison widget (Inter ↔ Figtree) to both repos

### Still Pending
- Upload new logo to Stripe Dashboard → Settings → Branding
- Upload MSA template to DocuSeal
- ✅ Font decision made: **Figtree** everywhere. Font toggle widgets removed from both repos.
- ✅ MSA PDFs regenerated with Figtree font (Feb 11)

---

## Step 1: Configure LiveKit Cloud S3 Credentials (1.21)

**Goal:** Enable LiveKit Egress to write call recordings to our S3 bucket.

**Detailed Instructions:**
1. **Create dedicated IAM user** for LiveKit:
   ```bash
   aws iam create-user --user-name callsaver-livekit-egress
   ```
2. **Attach S3 policy** scoped to session buckets:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
       "Resource": [
         "arn:aws:s3:::callsaver-sessions-staging",
         "arn:aws:s3:::callsaver-sessions-staging/*"
       ]
     }]
   }
   ```
3. **Create access key** for the new user
4. **Log in to LiveKit Cloud dashboard** at https://cloud.livekit.io
5. **Navigate to** Settings → Egress → S3
6. **Enter credentials:**
   - Access Key ID: (from step 3)
   - Secret Access Key: (from step 3)
   - Region: `us-west-1`
   - Bucket: `callsaver-sessions-staging`
7. **Test** by triggering a test recording

**⚠️ WAITING FOR USER APPROVAL before proceeding with this step.**

---

## Step 2: Finalize Landing Page (`~/callsaver-landing`)

**Remaining tasks from Step 8 of previous plan:**

### Content & Copy
- [ ] Review and update website copy (Hormozi-style conversion optimization)
- [ ] Review features section for accuracy
- [ ] Review FAQ section answers
- [ ] Replace audio demo with better LiveKit-recorded sample
- [ ] Replace dashboard screenshot with screen recording video (evaluate Focusee / Cap.so / Poindeo)

### Branding
- [ ] Update company logo font: Avenir Next → Inter (GIMP)
- [ ] Update business card templates font: Avenir Next → Inter

### Minor Fixes
- [ ] Review scroll position offsets for anchor links
- [ ] Replace static thinking emoji with animated GIF/WebP
- [ ] Full review pass — fix any remaining issues

### Code Cleanup
- [ ] Delete dead code, unused images, and template leftovers

### Deferred
- SEO, GrowthBook A/B testing, blog articles — do last

---

## Step 3: DocuSeal API Keys & Webhook Setup

**Goal:** Get test mode and production mode API keys from DocuSeal admin portal and configure webhooks.

### 3a. DocuSeal API Keys
1. **Log in** to https://forms.callsaver.ai as admin
2. **Navigate to** Settings → API
3. **Copy the test mode API key** → update:
   - `~/callsaver-api/.env` (`DOCUSEAL_API_KEY=`)
   - `~/callsaver-api/.env.local` (`DOCUSEAL_API_KEY=`)
4. **Copy the production mode API key** → update:
   - `~/callsaver-api/.env.staging` (`DOCUSEAL_API_KEY=`)
   - `~/callsaver-api/.env.production` (`DOCUSEAL_API_KEY=`)
   - Secrets Manager: `callsaver/staging/backend/DOCUSEAL_API_KEY`
5. **Verify** `DOCUSEAL_WEBHOOK_SECRET` is set correctly in DocuSeal admin

### 3b. DocuSeal Webhook Configuration
- **Local (ngrok):** `https://<ngrok-url>/webhooks/docuseal`
- **Staging:** `https://staging.api.callsaver.ai/webhooks/docuseal`
- Event: `submission.completed` (triggers MSA countersign flow)

---

## Step 4: Webhook Setup (Stripe, Nango, Intercom)

### 4a. Stripe Webhooks
1. **Stripe Dashboard** → Developers → Webhooks
2. **Add endpoint for local testing:**
   - URL: `https://<ngrok-url>/webhooks/stripe`
   - Events: `checkout.session.completed`, `customer.subscription.*`, `invoice.*`
   - Copy webhook signing secret → update `STRIPE_WEBHOOK_SECRET` in `.env` / `.env.local`
3. **Add endpoint for staging:**
   - URL: `https://staging.api.callsaver.ai/webhooks/stripe`
   - Copy webhook signing secret → update in Secrets Manager: `callsaver/staging/backend/STRIPE_WEBHOOK_SECRET`

### 4b. Nango Webhooks
1. **Nango Dashboard** → Settings → Webhooks
2. **Add local:** `https://<ngrok-url>/webhooks/nango`
3. **Add staging:** `https://staging.api.callsaver.ai/webhooks/nango`
4. **Verify** `NANGO_SECRET_KEY` is correct in `.env` files

### 4c. Intercom Webhooks
1. **Intercom Developer Hub** → Your App → Webhooks
2. **Add local:** `https://<ngrok-url>/webhooks/intercom`
3. **Add staging:** `https://staging.api.callsaver.ai/webhooks/intercom`
4. **Verify** `INTERCOM_ACCESS_TOKEN` is correct

---

## Step 5: Re-enable Twilio & LiveKit in Provisioning

**Goal:** Remove the `SKIP_TWILIO_PURCHASE=true` flag and re-enable full provisioning flow.

### Prerequisites
- [ ] **Pay Twilio delinquent balance** ($22) — https://console.twilio.com/billing
- [ ] Verify existing provisioned numbers are still active
- [ ] Verify LiveKit Cloud connection: `wss://callsaver-d8dm5v36.livekit.cloud`

### Code Changes
1. Set `SKIP_TWILIO_PURCHASE=false` in `.env` / `.env.local` / `.env.staging`
2. Verify `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` are valid in env files
3. Verify `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL` are set

---

## Step 6: Full Provisioning & Onboarding Flow Test

**Goal:** Test the complete user journey end-to-end, locally and on staging.

### Test Flow (local first, then staging)
1. **Sign up** via magic link (Supabase auth)
2. **Onboarding wizard** — fill out business details
3. **Provision handler** triggers:
   - [ ] DocuSeal MSA sent → verify email arrives
   - [ ] MSA signed → `submission.completed` webhook fires
   - [ ] Verify signed document written to `callsaver-ai-forms` S3 bucket
   - [ ] Stripe checkout session created → payment completes
   - [ ] Twilio number purchased (if `SKIP_TWILIO_PURCHASE=false`)
   - [ ] LiveKit SIP trunk configured
   - [ ] Business profile created in `callsaver-business-profiles` S3
4. **Dashboard loads** with provisioned data
5. **Guided tour** (react-joyride) — test and finish implementation
6. **Test all provisioning emails:**
   - Welcome email
   - MSA email (via DocuSeal)
   - Invoice/receipt (via Stripe)
   - Any nurture sequence emails

### Verification Checklist
- [ ] All webhook endpoints responding (DocuSeal, Stripe, Nango, Intercom)
- [ ] S3 documents written correctly
- [ ] Database records created (User, Organization, OrganizationMember, etc.)
- [ ] No console errors in frontend
- [ ] No 5xx errors in API logs

---

## Step 7: Production Infrastructure Deploy

**Only after local + staging testing is confirmed working.**

1. Deploy `Callsaver-Network-production`
2. Deploy `Callsaver-Storage-production`
3. Deploy `Callsaver-Backend-production`
4. Deploy `Callsaver-Agent-production`
5. Create production Secrets Manager entries (`callsaver/production/backend/*`)
6. Create Supabase production instance (task 1.20)
7. Deploy production web UI (task 1.14)
8. Update Route 53 production DNS records
9. Configure production webhooks (Stripe, DocuSeal, Nango, Intercom)
10. Final environment separation verification (task 4.6)

---

## Business Formation (Running in Parallel)

| Task | Status |
|------|--------|
| 2.1 Form Prosimian Labs LLC (Wyoming) | ✅ COMPLETED - Articles filed, OA signed, EIN obtained |
| 2.2 File DBA "CallSaver" (Santa Cruz County, $58) | ⏳ Waiting for CA LLC-12 approval |
| 2.3 Execute Solo Founder OA | ✅ COMPLETED - Signed via DocuSeal |
| 2.4 Get EIN | ✅ COMPLETED |
| ~~2.5 E-File 83(b) Election~~ | N/A — Not needed for single-member LLC |
| 2.6 CA Virtual Office (Northwest) | ⏳ Waiting for CA LLC-5 approval |
| 2.8 CA Foreign LLC Registration | ⏳ SUBMITTED - Form LLC-5 filed, waiting 1-2 days |
| 2.7 WY Certificate of Good Standing | ✅ COMPLETED |
| 2.9 CA Statement of Information | ⏳ Will file after LLC-5 approval (Form LLC-12, $20) |
| 3.1 Mercury & Stripe Setup | ✅ Mercury submitted + Stripe LIVE |

---

## Previously Completed (Feb 8-9)

<details>
<summary>Click to expand completed items</summary>

- ✅ Fix redirect loop (supabase-auth.ts)
- ✅ Revert 6 debug hacks in callsaver-frontend
- ✅ Update DocuSeal SMTP credentials
- ✅ Complete staging validation (1.22)
- ✅ Commit & push all repos (Feb 9)
- ✅ QR Code API testing (1.8)
- ✅ Health Check: Analytics (1.6) — GA4 + ContentSquare working
- ✅ Cal.com GA4 Integration (1.7)
- ✅ Landing page legal compliance — LLC disclosure, governing law, consent banner research
- ✅ Landing page navigation fixes — anchor links, Cal.com embed
- ✅ DBA name availability check — "CallSaver" clear in CA
- ✅ Recreate all S3 buckets (1.15) — 7 buckets, all data uploaded
- ✅ GitHub Actions secrets fix (1.19) — old account ID updated

</details>
