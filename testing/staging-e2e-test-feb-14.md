# Staging E2E Test Plan — February 14, 2026

> **Goal:** Validate the complete user journey on staging before production deploy.
> **Environment:** `staging.api.callsaver.ai` / `staging.app.callsaver.ai`

---

## Test 1: Cal.com Booking Pipeline — Existing Attio Company

**Question:** Does the Cal.com booking pipeline still perform website extraction and Google Place Details uploads to S3 if the Company already exists in Attio?

**Context:** Some companies may already exist in Attio with `s3_google_place_details_url` or `s3_business_profile_json_url` attributes pointing to an old/suspended AWS account's S3 bucket, or the attributes may be blank.

**Answer (from code analysis):**

Yes — the pipeline **will** re-run enrichment for existing companies. Here's why:

1. `createAttioCompany()` attempts an upsert with `matchingAttribute: 'google_place_id'`
2. If the company already exists, Attio returns a uniqueness conflict error
3. The pipeline catches this and extracts the **existing record ID** from the error message
4. Since both `googlePlaceId` (from fresh Places search) and `attioCompanyRecordId` (existing record) are set, the enrichment block executes:
   - `enrichAndStoreGooglePlaceDetails()` → uploads fresh `google_place_details.json` to S3
   - Website discovery + extraction → uploads `website_extraction.json` and markdown `.txt` to S3
   - Attio Company record is updated with new S3 URLs pointing to the **current** AWS account's bucket

**Edge case to watch:** If the existing company was created without a `google_place_id` (e.g. manually created), the uniqueness conflict would be on `domains` instead. The pipeline still returns the existing ID, but if the new booking also lacks a business name → `googlePlaceId` could be `null` → enrichment block is skipped. For our test, this shouldn't be an issue since we're booking with a real business name.

**S3 bucket:** `callsaver-business-profiles` (staging, current AWS account)
**S3 paths:**
- `{attioCompanyRecordId}/google_place_details.json`
- `{attioCompanyRecordId}/website_extraction.json`
- `{attioCompanyRecordId}/website_extraction_markdown.txt`

### Steps

- [ ] Identify a test company that already exists in Attio (with or without S3 data)
- [ ] Note the Attio Company record ID: `___________________________`
- [ ] Note current values of `s3_google_place_details_url` and `s3_business_profile_json_url`: `___________________________`
- [ ] Trigger a Cal.com booking for this company (use the business name + location)

### Expected Result

- Pipeline runs, detects existing company, re-enriches with fresh data
- S3 files are written to current AWS account bucket
- Attio attributes updated with new S3 URLs

### Actual Result

- [ ] Pipeline ran successfully: ☐ Yes ☐ No
- [ ] Existing company detected: ☐ Yes ☐ No
- [ ] Notes: `___________________________`

---

## Test 2: Verify S3 Artifacts After Pipeline

After the Cal.com booking pipeline completes, verify that all three S3 artifacts exist.

### Steps

- [ ] Get the Attio Company record ID from Test 1
- [ ] Check S3 for `google_place_details.json`:
  ```bash
  aws s3 ls s3://callsaver-business-profiles/{RECORD_ID}/google_place_details.json --region us-west-1
  ```
- [ ] Check S3 for `website_extraction.json`:
  ```bash
  aws s3 ls s3://callsaver-business-profiles/{RECORD_ID}/website_extraction.json --region us-west-1
  ```
- [ ] Check S3 for `website_extraction_markdown.txt`:
  ```bash
  aws s3 ls s3://callsaver-business-profiles/{RECORD_ID}/website_extraction_markdown.txt --region us-west-1
  ```
- [ ] Optionally download and inspect the JSON:
  ```bash
  aws s3 cp s3://callsaver-business-profiles/{RECORD_ID}/google_place_details.json - --region us-west-1 | jq '.business.name, .business.website, .address.formatted'
  ```

### Expected Result

- All three files exist in S3 under the correct record ID
- `google_place_details.json` contains valid structured data (placeId, business name, address, phone, etc.)
- `website_extraction.json` contains extracted business profile (services, hours, locations, etc.)
- `website_extraction_markdown.txt` contains the raw markdown from the crawled pages

### Actual Result

- [ ] `google_place_details.json` exists: ☐ Yes ☐ No
- [ ] `website_extraction.json` exists: ☐ Yes ☐ No
- [ ] `website_extraction_markdown.txt` exists: ☐ Yes ☐ No
- [ ] Data looks correct: ☐ Yes ☐ No
- [ ] Notes: `___________________________`

---

## Test 3: Trigger /provision Endpoint via Attio Workflow

Alex will manually trigger the `/provision` endpoint from a custom Attio workflow.

### Prerequisites

- Test 1 and Test 2 completed successfully (company has S3 data)
- Attio Company has: `google_place_id`, `s3_google_place_details_url`, `s3_business_profile_json_url`
- Attio Person exists and is linked to the Company

### Steps

- [ ] Trigger the Attio workflow that calls `/provision` on `staging.api.callsaver.ai`
- [ ] Monitor staging API logs for provisioning output

### Expected Result

- `/provision` endpoint receives the request and begins provisioning
- No immediate errors in the API response

### Actual Result

- [ ] Provision endpoint triggered: ☐ Yes ☐ No
- [ ] API responded successfully: ☐ Yes ☐ No
- [ ] Notes: `___________________________`

---

## Test 4: DocuSeal MSA Signature Request Email

After provisioning is triggered, a DocuSeal MSA signature request should be sent.

### Steps

- [ ] Check email inbox for DocuSeal MSA signature request (from `forms.callsaver.ai`)
- [ ] Verify the email contains the correct business name and recipient info
- [ ] Verify the MSA document loads when clicking the signing link

### Expected Result

- Email received with DocuSeal signing link
- Document loads correctly with pre-filled business information

### Actual Result

- [ ] Email received: ☐ Yes ☐ No
- [ ] Document loads: ☐ Yes ☐ No
- [ ] Notes: `___________________________`

---

## Test 5: Sign MSA → Stripe Checkout Email

After signing the MSA document, a Stripe checkout session should be created and emailed.

### Steps

- [ ] Sign the MSA document in DocuSeal as the customer
- [ ] Verify `submission.completed` webhook fires (check staging API logs)
- [ ] Verify signed document is stored in `callsaver-ai-forms` S3 bucket
- [ ] Countersign as CallSaver (alex@callsaver.ai) if required
- [ ] Check email inbox for Stripe checkout link

### Expected Result

- DocuSeal webhook fires successfully
- Signed PDF stored in S3
- Stripe checkout email received with payment link

### Actual Result

- [ ] MSA signed successfully: ☐ Yes ☐ No
- [ ] DocuSeal webhook fired: ☐ Yes ☐ No
- [ ] Signed PDF in S3: ☐ Yes ☐ No
- [ ] Stripe checkout email received: ☐ Yes ☐ No
- [ ] Notes: `___________________________`

---

## Test 6: Complete Stripe Checkout → Verify Provisioning

After completing the Stripe checkout, the full provisioning flow should execute automatically.

### Steps

- [ ] Complete Stripe checkout with test card: `4242 4242 4242 4242` (any future date, any CVC)
- [ ] Verify `checkout.session.completed` webhook fires (check staging API logs)
- [ ] Monitor staging API logs for the full provisioning sequence

### Verify in staging API logs

- [ ] Organization record created in database
- [ ] User record created in database
- [ ] Location record created in database
- [ ] Business profile fetched from S3 (`callsaver-business-profiles` bucket)
- [ ] Business categories classified via LLM
- [ ] Service areas set from Google Place data
- [ ] System prompt generated and stored on Agent model
- [ ] **Twilio phone number purchased** (real number, NOT mock — `SKIP_TWILIO_PURCHASE=false`)
- [ ] LiveKit SIP trunk created for the Twilio number
- [ ] Welcome email sent with magic link
- [ ] Subscription record created in database
- [ ] No errors or exceptions in logs

### Verify in external services

- [ ] Stripe Dashboard (sandbox): subscription active, payment succeeded
- [ ] Twilio Console: new phone number purchased and visible
- [ ] LiveKit Cloud: SIP trunk created

### Actual Result

- [ ] Stripe checkout completed: ☐ Yes ☐ No
- [ ] Provisioning ran to completion: ☐ Yes ☐ No
- [ ] Twilio number purchased: ☐ Yes ☐ No — Number: `___________________________`
- [ ] LiveKit SIP trunk created: ☐ Yes ☐ No
- [ ] All DB records created: ☐ Yes ☐ No
- [ ] Welcome email sent: ☐ Yes ☐ No
- [ ] Errors found: ☐ Yes ☐ No — Details: `___________________________`

---

## Test 7: Sign In via Magic Link

Verify the customer can sign into the app using the magic link from the welcome email.

### Steps

- [ ] Open the welcome email
- [ ] Click the magic link
- [ ] Verify redirect to `staging.app.callsaver.ai`
- [ ] Verify successful authentication (no redirect loops, no errors)

### Expected Result

- Magic link works, user is authenticated and redirected to the app
- No console errors in browser DevTools

### Actual Result

- [ ] Magic link received: ☐ Yes ☐ No
- [ ] Sign-in successful: ☐ Yes ☐ No
- [ ] Notes: `___________________________`

---

## Test 8: Onboarding Flow — Business Information Pre-populated

After signing in, the user should be routed to `/onboarding` with business information pre-populated from the pipeline data.

### Steps

- [ ] Verify redirect to `/onboarding` route after first sign-in
- [ ] Step through each onboarding step
- [ ] Verify business name is pre-populated
- [ ] Verify address is pre-populated
- [ ] Verify phone number is pre-populated
- [ ] Verify business category/type is pre-populated
- [ ] Verify service areas are pre-populated (if applicable)
- [ ] Complete the onboarding flow
- [ ] Check browser DevTools for console errors

### Expected Result

- All business information from the pipeline is pre-populated in the onboarding steps
- User can complete onboarding without re-entering data
- No frontend errors

### Actual Result

- [ ] Onboarding loads: ☐ Yes ☐ No
- [ ] Business info pre-populated: ☐ Yes ☐ No
- [ ] Onboarding completed: ☐ Yes ☐ No
- [ ] Fields missing/incorrect: `___________________________`
- [ ] Notes: `___________________________`

---

## Test 9: Google Calendar Integration + Dashboard

Connect Google Calendar via Nango and verify the dashboard and all frontend pages load.

### Steps

- [ ] Navigate to integrations page
- [ ] Click "Connect Google Calendar"
- [ ] Complete OAuth flow via Nango
- [ ] Verify Nango webhook fires (check staging API logs for `NangoConnection` creation)
- [ ] Navigate to `/dashboard` — verify it loads with provisioned data
- [ ] Verify location card shows correct business info
- [ ] Verify phone number is displayed
- [ ] Verify agent configuration is visible
- [ ] Navigate through all other frontend pages (settings, call history, etc.)
- [ ] Check browser DevTools for console errors
- [ ] Check staging API logs for any 5xx errors

### Expected Result

- Google Calendar connects successfully via Nango OAuth
- Nango webhook creates `NangoConnection` record
- Dashboard loads with all provisioned data
- All frontend pages load without errors

### Actual Result

- [ ] Google Calendar connected: ☐ Yes ☐ No
- [ ] Nango webhook fired: ☐ Yes ☐ No
- [ ] Dashboard loads: ☐ Yes ☐ No
- [ ] All pages load: ☐ Yes ☐ No
- [ ] Errors found: ☐ Yes ☐ No — Details: `___________________________`

---

## Test 10: Call the Voice Agent

The ultimate test — call the provisioned Twilio number and talk to the AI voice agent.

### Steps

- [ ] Get the provisioned Twilio phone number from Test 6
- [ ] Call the number from a personal phone
- [ ] Verify the call connects to LiveKit
- [ ] Verify the AI voice agent answers with the correct greeting
- [ ] Verify the agent knows the business name and services
- [ ] Test basic conversation:
  - Ask about services offered
  - Ask about pricing/estimates
  - Ask about hours of operation
  - Ask to schedule an appointment
  - Ask to speak to a human / transfer
- [ ] End the call
- [ ] Verify call recording saved to `callsaver-sessions-staging` S3 bucket
- [ ] Verify `CallRecord` created in database
- [ ] Assess call quality: latency, voice clarity, interruption handling

### Expected Result

- Call connects, agent answers with correct business context
- Agent can handle basic conversation about the business
- Call recording is saved
- CallRecord is created in the database

### Actual Result

- [ ] Call connected: ☐ Yes ☐ No
- [ ] Agent answered: ☐ Yes ☐ No
- [ ] Correct business context: ☐ Yes ☐ No
- [ ] Call recording saved: ☐ Yes ☐ No
- [ ] CallRecord in DB: ☐ Yes ☐ No
- [ ] Call quality notes: `___________________________`
- [ ] Issues found: `___________________________`

> **Next step:** After this test, create a separate detailed voice agent testing plan covering edge cases, error handling, tool calls, transfer logic, and conversation quality.

---

## Test Summary

| # | Test | Status | Blocker? |
|---|------|--------|----------|
| 1 | Cal.com pipeline — existing Attio company | ☐ | |
| 2 | Verify S3 artifacts (JSON + markdown) | ☐ | |
| 3 | Trigger /provision via Attio workflow | ☐ | |
| 4 | DocuSeal MSA email received | ☐ | |
| 5 | Sign MSA → Stripe checkout email | ☐ | |
| 6 | Stripe checkout → full provisioning | ☐ | |
| 7 | Sign in via magic link | ☐ | |
| 8 | Onboarding — business info pre-populated | ☐ | |
| 9 | Google Calendar + dashboard | ☐ | |
| 10 | Call the voice agent | ☐ | |

---

## Issues Log

| # | Test | Issue | Severity | Fix Status |
|---|------|-------|----------|------------|
| | | | | |
