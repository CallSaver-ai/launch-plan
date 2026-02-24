# Legal Integration Plan — Law Adapter MVP

**Date:** February 22, 2026  
**Status:** Planning  
**Vertical:** Legal (Law Firms)

---

## 1. Supported Actions (MVP Scope)

The law adapter will support exactly **5 actions** for voice agent use:

| # | Action | Adapter Method | Description |
|---|--------|----------------|-------------|
| 1 | **Look up caller** | `findContactByPhone(context)` | Search contacts/clients by phone number to identify the caller |
| 2 | **Create contact/lead** | `createLead(context, data)` | Create a new lead or contact for unknown callers |
| 3 | **Create appointment** | `createAppointment(context, data)` | Schedule a consultation or appointment |
| 4 | **Cancel appointment** | `cancelAppointment(context, appointmentId, reason?)` | Cancel an existing appointment |
| 5 | **Reschedule appointment** | `updateAppointment(context, appointmentId, data)` | Change the date/time of an existing appointment |

Supporting methods required internally (not direct voice tools, but needed to support the 5 actions):

| Method | Purpose |
|--------|---------|
| `getAppointments(context, contactId)` | Required to list upcoming appointments before cancel/reschedule |
| `getAppointment(context, appointmentId)` | Required to verify appointment ownership before cancel/reschedule |

---

## 2. Caller Intents NOT Covered → Transfer / Callback

The following caller intents **cannot** be handled by the 5 MVP actions. When the voice agent detects these intents, it should either **create a callback request in our system** or **transfer the call via SIP REFER**.

### 2.1 Case / Matter Status Inquiries

| Intent | Example Phrases | Recommended Action |
|--------|----------------|-------------------|
| Case status check | "What's the status of my case?" "Any updates on my matter?" | **Transfer** — requires attorney knowledge |
| Case timeline | "When will my case be resolved?" "What are the next steps?" | **Transfer** — requires attorney judgment |
| Discovery/filings status | "Has the motion been filed?" "Did we get the documents?" | **Transfer** — requires case-specific knowledge |
| Court date inquiry | "When is my court date?" "When is the next hearing?" | **Transfer** — sensitive information, needs attorney |
| Settlement status | "Have they made an offer?" "Where are we on settlement?" | **Transfer** — highly sensitive, attorney only |

### 2.2 Billing & Payment

| Intent | Example Phrases | Recommended Action |
|--------|----------------|-------------------|
| Invoice inquiry | "How much do I owe?" "Can I get my latest invoice?" | **Callback** — billing department |
| Payment arrangements | "Can I set up a payment plan?" | **Transfer** — billing department |
| Fee dispute | "I don't agree with this charge" | **Transfer** — billing department or attorney |
| Retainer balance | "How much is left on my retainer?" | **Callback** — billing department |

### 2.3 Document & Legal Work

| Intent | Example Phrases | Recommended Action |
|--------|----------------|-------------------|
| Document request | "I need a copy of my contract" "Can you send me the agreement?" | **Callback** — paralegal/admin |
| Document signing | "I need to sign the documents" "Where do I sign?" | **Callback** — paralegal with e-sign link |
| Evidence/discovery | "I have new evidence" "I got the documents you asked for" | **Transfer** — paralegal or attorney |
| Intake form status | "I submitted my intake form, what's next?" | **Callback** — intake coordinator |

### 2.4 Attorney Communication

| Intent | Example Phrases | Recommended Action |
|--------|----------------|-------------------|
| Speak to attorney | "I need to talk to my lawyer" "Can I speak with [name]?" | **Transfer** — route to specific attorney |
| Speak to paralegal | "Can I talk to the paralegal on my case?" | **Transfer** — route to paralegal |
| Urgent/emergency | "This is an emergency" "I've been arrested" | **Transfer** — immediate routing |
| Leave message | "Can you have them call me back?" | **Callback** — create task for attorney |
| Complaint | "I'm not happy with the service" "I want to talk to a manager" | **Transfer** — managing partner/admin |

### 2.5 New Matter / Referral

| Intent | Example Phrases | Recommended Action |
|--------|----------------|-------------------|
| Second matter inquiry | "I have another legal issue" "I need help with something else" | **Transfer** — intake, may need conflict check |
| Referral | "I was referred by [person]" (complex intake) | **Callback** — intake coordinator |
| Insurance claim | "My insurance company said to call" | **Transfer** — intake or attorney |

### 2.6 Administrative

| Intent | Example Phrases | Recommended Action |
|--------|----------------|-------------------|
| Address/contact update | "I moved, here's my new address" | **Callback** — admin can update; _could_ be added to MVP later |
| Office hours/location | "What are your hours?" "Where is your office?" | Voice agent can answer from firm config (no API needed) |
| Fax number | "What's your fax number?" | Voice agent can answer from firm config |

### 2.7 Summary: Transfer Tool Instructions

When building the voice agent transfer tool, configure it with these routing rules:

```
TRANSFER immediately for:
  - "speak to attorney/lawyer/paralegal" → SIP REFER to firm main line or specific extension
  - "emergency/arrested/urgent" → SIP REFER to firm main line (priority)
  - "complaint/manager" → SIP REFER to firm main line
  - "case status/settlement/court date" → SIP REFER to assigned attorney

CREATE CALLBACK for:
  - "billing/invoice/payment" → Callback request, tag: billing
  - "documents/paperwork/signing" → Callback request, tag: documents  
  - "new legal issue/second matter" → Callback request, tag: intake
  - "message for attorney" → Callback request, tag: attorney-callback
  - "address/contact update" → Callback request, tag: admin
```

---

## 3. Adapter Architecture

### 3.1 Pattern (Mirrors Field Service Adapter)

```
src/adapters/law/
├── LawAdapter.ts              # Full interface (already exists)
├── LawAdapterV1.ts            # MVP subset interface (already exists)
├── BaseLawAdapter.ts          # Abstract base class (already exists)
├── LawAdapterFactory.ts       # Factory class (TO CREATE)
├── LawAdapterRegistry.ts      # Registry with caching (TO CREATE)
├── errors.ts                  # Error types (already exists)
├── phoneVerification.ts       # Phone matching (already exists)
├── types/law.ts               # Unified types (already exists)
└── platforms/
    ├── lawmatics/
    │   ├── LawmaticsAdapter.ts    # (exists, needs update)
    │   └── LawmaticsClient.ts     # (exists, needs update)
    ├── clio/
    │   ├── ClioAdapter.ts         # (exists, needs update)
    │   └── ClioClient.ts          # (exists, needs update)
    └── mycase/
        ├── MyCaseAdapter.ts       # TO CREATE
        └── MyCaseClient.ts        # TO CREATE
```

### 3.2 LawAdapterFactory (New)

```typescript
export type LawPlatform =
  | 'lawmatics'
  | 'clio';

export interface LawAdapterFactoryConfig {
  platform: LawPlatform;
  connectionId?: string;  // OAuth via Pipedream
  apiKey?: string;        // API key auth (if platform supports)
  apiUrl?: string;
}
```

### 3.3 Auth Strategy per Platform

| Platform | Auth Method | Token Handling |
|----------|------------|----------------|
| **Clio** | OAuth 2.0 | Pipedream |
| **Lawmatics** | API Key or OAuth 2.0 | API key direct or Pipedream |
| **MyCase** | OAuth 2.0 | Pipedream |

---

## 4. API Endpoint Mapping — Clio, Lawmatics, MyCase

### 4.1 `findContactByPhone` — Look Up Caller

| Platform | Method | Endpoint | Phone Search Strategy |
|----------|--------|----------|----------------------|
| **Clio** | `GET` | `/contacts.json?limit=50&fields=id,first_name,last_name,name,phone_numbers` | ⚠️ No direct phone search — batch fetch + filter client-side by `phone_numbers[].number` |
| **Lawmatics** | `GET` | `/contacts?phone={normalizedPhone}` | ✅ Direct phone search parameter |
| **MyCase** | `GET` | `/clients?filter[cell_phone_number]={phone}` | ✅ Direct phone filter. Also try `filter[work_phone_number]` and `filter[home_phone_number]` |

**Notes:**
- Clio has no direct phone search — implement paginated fetch + E.164 phone matching in the adapter
- Clio stores phone numbers as a separate sub-resource; may need `GET /contacts/{id}/phone_numbers.json`
- MyCase has 3 phone fields (`cell_phone_number`, `work_phone_number`, `home_phone_number`) — search all three

---

### 4.2 `createLead` — Create Contact / Lead

| Platform | Method | Endpoint | Lead Strategy |
|----------|--------|----------|---------------|
| **Clio** | `POST` | `/contacts.json` | ⚠️ No native leads — create contact with `tags: ["lead"]` |
| **Lawmatics** | `POST` | `/leads` | ✅ Native leads API |
| **MyCase** | `POST` | `/leads` | ✅ Native leads API |

**Request Body Mapping:**

| Our Field | Clio | Lawmatics | MyCase |
|-----------|------|-----------|--------|
| `firstName` | `data.first_name` | `first_name` | `first_name` |
| `lastName` | `data.last_name` | `last_name` | `last_name` |
| `email` | `data.email_addresses[0].address` | `email` | `email` |
| `phone` | `data.phone_numbers[0].number` | `phone` | `phone_number` |
| `source` | N/A (use tag) | `source` | `referral_source.id` |
| `notes` | N/A | `notes` | `description` |

---

### 4.3 `createAppointment` — Schedule Appointment

| Platform | Method | Endpoint | Notes |
|----------|--------|----------|-------|
| **Clio** | `POST` | `/calendar_entries.json` | Uses `attendees: [{type: "Contact", id: contactId}]` |
| **Lawmatics** | `POST` | `/appointments` | Uses `contact_id` directly |
| **MyCase** | `POST` | `/events` | Link to case via case ID |

**Request Body Mapping:**

| Our Field | Clio | Lawmatics | MyCase |
|-----------|------|-----------|--------|
| `title` | `data.summary` | `title` | `name` |
| `description` | `data.description` | `notes` | `description` |
| `startTime` | `data.start_at` | `start_time` | `start` |
| `endTime` | `data.end_at` | `end_time` | `end` |
| `location` | `data.location` | `location` | `location.id` |
| `contactId` | `data.attendees[0].id` | `contact_id` | case relationship |

**Platform-Specific Requirements:**
- **Clio**: Calendar entries use attendees array with `{type: "Contact", id: contactId}`
- **MyCase**: Events are linked to cases. Need `case_id` → may need to look up or create a case first

---

### 4.4 `cancelAppointment` — Cancel Appointment

| Platform | Method | Endpoint | Notes |
|----------|--------|----------|-------|
| **Clio** | `DELETE` | `/calendar_entries/{id}.json` | Hard delete |
| **Lawmatics** | `DELETE` | `/appointments/{id}` | Hard delete |
| **MyCase** | `DELETE` | `/events/{id}` | Hard delete |

**Implementation Notes:**
- All platforms use HTTP DELETE for cancellation
- Before deleting, verify the appointment belongs to the caller (phone match)
- Log the cancellation reason in our system even if the platform doesn't support reason fields
- Consider updating status to "cancelled" (PATCH) instead of hard delete where platform supports it

---

### 4.5 `updateAppointment` (Reschedule) — Change Date/Time

| Platform | Method | Endpoint | Notes |
|----------|--------|----------|-------|
| **Clio** | `PATCH` | `/calendar_entries/{id}.json` | Update `start_at` and `end_at` |
| **Lawmatics** | `PUT` | `/appointments/{id}` | Update `start_time` and `end_time` |
| **MyCase** | `PUT` | `/events/{id}` | Update `start` and `end` |

**Request Body Mapping (Reschedule):**

| Our Field | Clio | Lawmatics | MyCase |
|-----------|------|-----------|--------|
| `startTime` | `data.start_at` | `start_time` | `start` |
| `endTime` | `data.end_at` | `end_time` | `end` |

---

### 4.6 `getAppointments` — List Upcoming Appointments (Supporting Method)

| Platform | Method | Endpoint | Filter Strategy |
|----------|--------|----------|------------------|
| **Clio** | `GET` | `/calendar_entries.json?from={start}&to={end}&visible=true` | Filter by contact as attendee client-side |
| **Lawmatics** | `GET` | `/contacts/{contactId}/appointments?start_date={start}&end_date={end}` | ✅ Direct contact filter |
| **MyCase** | `GET` | `/events?filter[updated_after]={date}` | ⚠️ Limited filtering — fetch and filter by case→client |

---

## 5. Platform Comparison Summary

### Feature Support Matrix

| Feature | Clio | Lawmatics | MyCase |
|---------|------|-----------|--------|
| Phone lookup | ⚠️ Batch | ✅ Direct | ✅ Filter |
| Native leads | ❌ (use tags) | ✅ | ✅ |
| Native appointments | ⚠️ (calendar entries) | ✅ | ✅ (events) |
| Cancel appointment | ✅ DELETE | ✅ DELETE | ✅ DELETE |
| Reschedule | ✅ PATCH | ✅ PUT | ✅ PUT |
| Webhook support | ✅ | ✅ | ✅ |

### Complexity Rating

| Platform | Complexity | Reason |
|----------|-----------|--------|
| **Lawmatics** | 🟢 Low | Native leads, native appointments, direct phone search |
| **MyCase** | 🟢 Low | Native leads, native events, phone filter parameters |
| **Clio** | 🟡 Medium | No native leads, calendar entries instead of appointments, no phone search |

---

## 6. Implementation Order

Based on complexity and existing scaffolding:

| Priority | Platform | Rationale | Estimated Effort |
|----------|----------|-----------|------------------|
| 1 | **Lawmatics** | Lowest complexity, adapter already scaffolded, native leads + appointments | 4–6 hours |
| 2 | **MyCase** | Low complexity, native leads + events, direct phone filter | 6–8 hours |
| 3 | **Clio** | Largest market share among legal CRMs, adapter already scaffolded | 6–8 hours |

**Total estimated effort:** 16–22 hours

---

## 7. Unified Type Changes Needed

The existing `types/law.ts` types are already well-suited for the MVP. Minor additions:

```typescript
// Add to types/law.ts

/** Matter/Case reference (needed for MyCase case linkage) */
export interface MatterRef {
  id: string;
  name?: string;
  status?: string;
}

// Update Appointment to include optional matter/case reference
export interface Appointment {
  // ... existing fields ...
  matterId?: string;       // Needed for MyCase (events linked to cases)
  matter?: MatterRef;      // Optional enrichment
}

// Add to CreateAppointmentInput
export interface CreateAppointmentInput {
  // ... existing fields ...
  matterId?: string;       // Required for MyCase, optional for Clio/Lawmatics
}
```

---

## 8. Pipedream OAuth Apps Needed

Each platform will need a custom OAuth app in Pipedream (project `proj_BgsRyvp`):

| Platform | Pipedream App Name | Status |
|----------|--------------------|--------|
| Clio | `clio` | TO CREATE |
| Lawmatics | `lawmatics` | TO CREATE |
| MyCase | `mycase` | TO CREATE |

For each app:
1. Register as a developer with the platform
2. Create OAuth application in the platform's developer console
3. Get client ID + client secret
4. Create custom OAuth app in Pipedream with the credentials
5. Configure scopes (contacts read/write, calendar read/write)
6. Add Pipedream redirect URI to the platform's OAuth app

---

## 9. Existing Documentation Reference

All API documentation is already in the codebase:

| Platform | Documentation File | Spec File |
|----------|-------------------|-----------|
| Clio | `api-docs/law/CLIO_API_VOICE_AGENT_SUMMARY.md` | `api-docs/law/clio-api-voice-agent.json` (860KB) |
| Lawmatics | `api-docs/law/LAWMATICS_API_DOCUMENTATION.md` | — |
| MyCase | `api-docs/law/MYCASE_API_DOCUMENTATION.md` | `api-docs/law/mycase-scraped.json` |

Additional reference:
- `src/adapters/law/README.md` — Architecture overview
- `src/adapters/law/MVP_API_MAPPING.md` — Existing Clio + Lawmatics mapping

---

## 10. Future Platforms (Deferred)

The following platforms have API documentation in the codebase and can be added later:

| Platform | Documentation | Notes |
|----------|--------------|-------|
| Smokeball | `api-docs/law/SMOKEBALL_API_DOCUMENTATION.md` | Medium complexity — leads are matters with `isLead: true` |
| Filevine | `api-docs/law/FILEVINE_API_DOCUMENTATION.md` | High complexity — no native appointments, requires org/user headers |
| PracticePanther | `api-docs/law/PRACTICEPANTHER_API_DOCUMENTATION.md` | Medium complexity — OData queries, Swagger-only docs |
