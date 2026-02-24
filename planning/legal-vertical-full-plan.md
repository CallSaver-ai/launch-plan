# Legal Vertical — Full Implementation Plan

**Date:** February 22, 2026  
**Status:** Planning  
**Platforms:** Lawmatics (Priority 1), Clio (Priority 2)  
**Scope:** Backend adapters + Frontend adaptation for legal practice market

---

## Table of Contents

1. [Backend — Adapter Implementation](#1-backend--adapter-implementation)
2. [Backend — API Routes & Tool Endpoints](#2-backend--api-routes--tool-endpoints)
3. [Backend — Voice Agent Prompt & Instructions](#3-backend--voice-agent-prompt--instructions)
4. [Frontend — Integrations Config](#4-frontend--integrations-config)
5. [Frontend — Sidebar & Navigation](#5-frontend--sidebar--navigation)
6. [Frontend — Onboarding Page](#6-frontend--onboarding-page)
7. [Frontend — Dashboard Page](#7-frontend--dashboard-page)
8. [Frontend — Callers Page → Contacts Page](#8-frontend--callers-page--contacts-page)
9. [Frontend — Caller Detail Page → Contact Detail Page](#9-frontend--caller-detail-page--contact-detail-page)
10. [Frontend — Appointments Page → Consultations Page](#10-frontend--appointments-page--consultations-page)
11. [Frontend — Service Requests Page (Not Applicable)](#11-frontend--service-requests-page-not-applicable)
12. [Frontend — Callbacks Page](#12-frontend--callbacks-page)
13. [Frontend — Locations Page](#13-frontend--locations-page)
14. [Frontend — Service Presets Data](#14-frontend--service-presets-data)
15. [Pipedream OAuth Setup](#15-pipedream-oauth-setup)
16. [Database / Prisma Changes](#16-database--prisma-changes)
17. [Email Templates — Legal Vertical Audit](#17-email-templates--legal-vertical-audit)
18. [Multi-Transfer Routing for Legal Vertical](#18-multi-transfer-routing-for-legal-vertical)
19. [Python Agent (livekit-python) Changes](#19-python-agent-livekit-python-changes)
20. [Implementation Order & Estimates](#20-implementation-order--estimates)

---

## 1. Backend — Adapter Implementation

### 1.1 Existing Scaffolding (Already Created)

The law adapter architecture already mirrors the field-service pattern:

| File | Status | Notes |
|------|--------|-------|
| `src/adapters/law/LawAdapter.ts` | ✅ Complete | Full interface: 11 methods (Contact, Lead, Appointment) |
| `src/adapters/law/LawAdapterV1.ts` | ✅ Complete | MVP subset: 8 methods |
| `src/adapters/law/BaseLawAdapter.ts` | ✅ Complete | Abstract base with phone verification |
| `src/adapters/law/LawAdapterFactory.ts` | ✅ Complete | Factory for lawmatics + clio |
| `src/adapters/law/LawAdapterRegistry.ts` | ✅ Complete | Registry with caching, Pipedream + API key auth |
| `src/adapters/law/errors.ts` | ✅ Complete | Error types |
| `src/adapters/law/phoneVerification.ts` | ✅ Complete | E.164 normalization |
| `src/adapters/law/index.ts` | ✅ Complete | Barrel exports |
| `src/types/law.ts` | ✅ Complete | CallerContext, Contact, Lead, Appointment types |
| `src/adapters/law/platforms/lawmatics/` | ❌ Empty | Needs LawmaticsAdapter.ts + LawmaticsClient.ts |
| `src/adapters/law/platforms/clio/` | ❌ Empty | Needs ClioAdapter.ts + ClioClient.ts |

### 1.2 Scaffolding Fixes Needed

1. **`LawAdapterRegistry.ts` line 208** — uses `prisma.nangoConnection` → needs updating to `prisma.integrationConnection` to match the rename done across the field-service adapter.

2. **`LawAdapterRegistry.ts` lines 17-23** — incorrectly categorizes Lawmatics as `API_KEY_PLATFORMS` and only Clio as `PIPEDREAM_PLATFORMS`. **Both** should be in `PIPEDREAM_PLATFORMS` since Lawmatics uses OAuth 2.0 via Pipedream.
   ```typescript
   // WRONG (current):
   const PIPEDREAM_PLATFORMS: LawPlatform[] = ['clio'];
   const API_KEY_PLATFORMS: LawPlatform[] = ['lawmatics'];
   
   // CORRECT:
   const PIPEDREAM_PLATFORMS: LawPlatform[] = ['lawmatics', 'clio'];
   const API_KEY_PLATFORMS: LawPlatform[] = [];
   ```

3. **`LawAdapterFactory.ts` lines 41-49** — Lawmatics case uses `apiKey` credential. Needs to be changed to `accessToken` (OAuth token from Pipedream), same as Clio.
   ```typescript
   // WRONG (current):
   case 'lawmatics': {
     if (!apiKey) throw new Error('Lawmatics adapter requires apiKey');
     const credentials: LawmaticsCredentials = { apiKey, baseUrl: apiUrl };
     return new LawmaticsAdapter(credentials);
   }
   
   // CORRECT:
   case 'lawmatics': {
     if (!accessToken) throw new Error('Lawmatics adapter requires accessToken');
     const credentials: LawmaticsCredentials = { accessToken, baseUrl: apiUrl };
     return new LawmaticsAdapter(credentials);
   }
   ```

### 1.3 Lawmatics Adapter (Priority 1)

**Files to create:**
- `src/adapters/law/platforms/lawmatics/LawmaticsClient.ts`
- `src/adapters/law/platforms/lawmatics/LawmaticsAdapter.ts`

**LawmaticsClient.ts** — HTTP client:
```
Auth: OAuth 2.0 Bearer token (via Pipedream)
Base URL: https://api.lawmatics.com/v1
Methods:
  - searchContacts(phone) → GET /contacts?phone={phone}
  - getContact(id) → GET /contacts/{id}
  - updateContact(id, data) → PUT /contacts/{id}
  - createLead(data) → POST /leads
  - getAppointments(contactId, dateRange?) → GET /contacts/{contactId}/appointments
  - getAppointment(id) → GET /appointments/{id}
  - createAppointment(data) → POST /appointments
  - updateAppointment(id, data) → PUT /appointments/{id}
  - deleteAppointment(id) → DELETE /appointments/{id}
```

**LawmaticsAdapter.ts** — Adapter implementing LawAdapter:
- `findContactByPhone` → Direct phone search (✅ Lawmatics supports this natively)
- `createLead` → Native leads API (`POST /leads`)
- `createAppointment` → `POST /appointments` with `contact_id`
- `cancelAppointment` → `DELETE /appointments/{id}`
- `updateAppointment` → `PUT /appointments/{id}` (reschedule)
- `getAppointments` → `GET /contacts/{contactId}/appointments` with date filter

**Auth:** OAuth 2.0 via Pipedream Connect (same pattern as Jobber/Google Calendar)

### 1.4 Clio Adapter (Priority 2)

**Files to create:**
- `src/adapters/law/platforms/clio/ClioClient.ts`
- `src/adapters/law/platforms/clio/ClioAdapter.ts`

**ClioClient.ts** — HTTP client:
```
Auth: OAuth 2.0 Bearer token (via Pipedream, same as Lawmatics)
Base URL: https://app.clio.com/api/v4
Methods:
  - searchContacts(phone) → GET /contacts.json + client-side phone filter
  - getContact(id) → GET /contacts/{id}.json
  - updateContact(id, data) → PATCH /contacts/{id}.json
  - createContact(data) → POST /contacts.json (with tags: ["lead"])
  - getCalendarEntries(contactId?, dateRange?) → GET /calendar_entries.json
  - getCalendarEntry(id) → GET /calendar_entries/{id}.json
  - createCalendarEntry(data) → POST /calendar_entries.json
  - updateCalendarEntry(id, data) → PATCH /calendar_entries/{id}.json
  - deleteCalendarEntry(id) → DELETE /calendar_entries/{id}.json
```

**ClioAdapter.ts quirks:**
- `findContactByPhone` → ⚠️ Clio has NO direct phone search. Must paginated fetch + E.164 match against `phone_numbers[].number`. Cache contacts list for performance.
- `createLead` → ❌ No native leads. Create a Contact with `tags: ["lead", "callsaver-lead"]` and custom field for source.
- `createAppointment` → Uses calendar_entries with `attendees: [{type: "Contact", id: contactId}]`
- Appointments are "calendar entries" — map title→summary, description→description

**Auth:** OAuth 2.0 via Pipedream Connect. Token fetched from Pipedream SDK using connectionId stored in `integrationConnection`. Same pattern as Lawmatics.

---

## 2. Backend — API Routes & Tool Endpoints

### 2.1 New Route File: `src/routes/law-tools.ts`

Mirror the pattern from `src/routes/field-service-tools.ts`. Create tool endpoints for the voice agent:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/internal/tools/law-find-contact` | POST | Look up caller by phone |
| `/internal/tools/law-create-lead` | POST | Create new lead/contact |
| `/internal/tools/law-create-appointment` | POST | Schedule consultation |
| `/internal/tools/law-cancel-appointment` | POST | Cancel appointment |
| `/internal/tools/law-reschedule-appointment` | POST | Reschedule appointment |
| `/internal/tools/law-get-appointments` | POST | List upcoming appointments |

Each endpoint:
1. Authenticates via `INTERNAL_API_KEY`
2. Extracts `locationId` and `callerPhoneNumber` from request body
3. Gets adapter from `LawAdapterRegistry`
4. Calls the appropriate adapter method
5. Returns voice-agent-friendly JSON response

### 2.2 User-Facing API Endpoints

For the frontend dashboard (mirror field-service pattern):

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `GET /me/leads` | GET | List leads created by CallSaver |
| `GET /me/consultations` | GET | List consultations/appointments created by CallSaver |

### 2.3 Integration Management

Extend existing integration endpoints to support law platforms:

- `GET /me/integrations` — Already works (returns all `integrationConnection` records)
- `POST /me/integrations/lawmatics` — OAuth callback (same pattern as Jobber)
- `POST /me/integrations/clio` — OAuth callback (same pattern as Jobber)
- `DELETE /me/integrations/{type}` — Disconnect (already generic)

### 2.4 Agent Config Endpoint

Update `GET /internal/agent-config` to:
- Detect if location has a law integration connected
- Return `vertical: 'law'` in the config (currently returns `vertical: 'field-service'` or nothing)
- Include law-specific instructions for the voice agent
- Pre-load caller name from Lawmatics/Clio (same pattern as Jobber pre-load)

---

## 3. Backend — Voice Agent Prompt & Instructions

### 3.1 Law-Specific System Instructions

In `src/utils.ts` or `src/server.ts` (where `fsInstructions` is built), add `lawInstructions`:

```
LAW PRACTICE INTEGRATION
You are answering calls for a law firm. Use professional legal terminology.

TERMINOLOGY:
- Use "consultation" instead of "appointment"
- Use "client" or "potential client" instead of "caller"
- Use "matter" or "case" instead of "job"
- Use "practice area" instead of "service type"
- Use "intake" instead of "service request"

INTAKE FLOW:
Step 1: Greet professionally. "Thank you for calling [firm name], how can I help you today?"
Step 2: Look up the caller by phone number (law-find-contact tool)
Step 3: If NOT found → create a new lead (law-create-lead tool)
  - Collect: first name, last name, email (if offered), brief description of legal need
  - Ask: "What type of legal matter can we help you with?"
Step 4: If caller wants to schedule → offer available consultation times
Step 5: Schedule the consultation (law-create-appointment tool)
Step 6: Confirm details: date, time, attorney name (if applicable)

TRANSFER/CALLBACK RULES:
- "I need to talk to my lawyer" → TRANSFER immediately
- "What's the status of my case?" → TRANSFER to attorney
- "This is an emergency / I've been arrested" → TRANSFER immediately (priority)
- "billing/invoice/payment" → Create CALLBACK request tagged "billing"
- "documents/paperwork" → Create CALLBACK request tagged "documents"
- "leave a message" → Create CALLBACK request tagged "attorney-callback"

IMPORTANT:
- Never provide legal advice
- Never discuss case specifics or strategy
- Never quote fees unless firm has configured standard consultation fees
- For sensitive matters (arrests, emergencies), transfer immediately
- Always be empathetic — callers may be in distress
```

### 3.2 Tool Definitions for Voice Agent

In `livekit-python/server.py`, add law-specific tools alongside existing field-service tools. The agent config endpoint will determine which tool set to load based on the connected integration type.

---

## 4. Frontend — Integrations Config

### 4.1 File: `src/lib/integrations-config.ts`

Add Lawmatics and Clio to `AVAILABLE_INTEGRATIONS`:

```typescript
// ADD after housecall-pro entry:
{
  id: 'lawmatics',
  displayName: 'Lawmatics',
  shortDescription: 'Legal CRM & intake automation',
  fullDescription: 'Connect your Lawmatics account to let CallSaver create leads, schedule consultations, and sync client data from incoming calls.',
  image: '/images/lawmatics.png',
  appSlug: 'lawmatics',
  oauthAppId: 'oa_YYYYYY',  // TBD: Create in Pipedream
  apiMatchKeys: ['lawmatics'],
},
{
  id: 'clio',
  displayName: 'Clio',
  shortDescription: 'Practice management & scheduling',
  fullDescription: 'Connect your Clio account to sync contacts, schedule consultations, and manage client intake through CallSaver.',
  image: '/images/clio.png',
  appSlug: 'clio',
  oauthAppId: 'oa_XXXXXX',  // TBD: Create in Pipedream
  apiMatchKeys: ['clio'],
},
```

### 4.2 Logo Assets

Add to `public/images/`:
- `lawmatics.png` — Lawmatics logo
- `clio.png` — Clio logo

---

## 5. Frontend — Sidebar & Navigation

### 5.1 File: `src/components/layout/app-sidebar.tsx`

**Current behavior:**
- `Appointments` item hidden when no integration connected
- Renamed to `Service Requests` (Wrench icon) when Jobber connected
- Renamed to `Jobs` (Briefcase icon) when HCP connected

**Legal adaptation needed:**

```typescript
// ADD after housecall-pro check (line ~120):
if (item.title === 'Appointments' && (integrationType === 'lawmatics' || integrationType === 'clio')) {
  const { items: _items, ...rest } = item as any;
  return { ...rest, title: 'Consultations', url: '/consultations', icon: Scale } as typeof item;
}
```

- Import `Scale` (or `Gavel` or `BookOpen`) from lucide-react for the legal icon

**Callers → Contacts rename:**

```typescript
// ADD mapping for callers item:
if (item.title === 'Callers' && (integrationType === 'lawmatics' || integrationType === 'clio')) {
  return { ...item, title: 'Contacts', url: '/contacts' };
}
```

### 5.2 File: `src/components/layout/data/sidebar-data.ts`

No changes needed — the sidebar data provides the base items, and `app-sidebar.tsx` transforms them based on integration type.

### 5.3 New Routes in `App.tsx`

```typescript
// ADD alongside existing routes:
<Route path="/contacts" element={/* ... CallersPage with legal mode */} />
<Route path="/contacts/:contactId" element={/* ... CallerDetailPage with legal mode */} />
<Route path="/consultations" element={/* ... ConsultationsPage */} />
```

**Strategy:** Rather than creating entirely new page components, use the existing pages with a `vertical` or `mode` prop/context that switches terminology and behavior. This avoids code duplication.

---

## 6. Frontend — Onboarding Page

### 6.1 File: `src/pages/OnboardingPage.tsx` (2,741 lines)

The onboarding page has 7 steps:
1. **Business Info** — Shows business name + phone from Google Place
2. **Service Areas** — City/county selection
3. **Connect Integration** — Shows AVAILABLE_INTEGRATIONS cards
4. **Services** — Service selection from presets (conditionally skipped)
5. **Voice Selection** — Choose agent voice
6. **Choose Path** — Keep number vs auto pilot
7. **Call Forwarding / Transfer Setup**

**Changes needed for legal vertical:**

#### Step 1: Business Info
- **Currently:** "Business Name", "Business Phone"
- **Legal:** Same labels work fine. "Law Firm Name" could be nice but "Business Name" is acceptable.
- **Change:** Replace "Need to update your business information? → update your Google Place listing" notice with law-appropriate text. Many law firms may not have a Google Place listing — consider making this optional or adding a manual entry fallback.

#### Step 2: Service Areas
- **Currently:** "Select cities or counties your business serves"
- **Legal:** Change to "Select cities or counties your firm serves" when law integration is connected
- **Note:** Many law firms serve entire states, not just cities. Consider adding state-level option for legal.

#### Step 3: Connect Integration
- **Currently:** Shows Google Calendar, Jobber, HCP cards
- **Legal:** This is dynamic from `AVAILABLE_INTEGRATIONS` — Lawmatics + Clio will appear automatically once added to the config
- **Consideration:** The cards currently show ALL integrations. We may want to filter by vertical — show only field-service integrations for field-service businesses, and only law integrations for law firms. **This requires knowing the vertical BEFORE the integration step.**
  
  **Decision needed:** Either:
  - (A) Show all integrations and let the user pick (simpler, current behavior)
  - (B) Determine vertical during provisioning (via Cal.com booking pipeline / Attio) and filter integrations accordingly
  
  **Recommendation: Option A for MVP.** The user will self-select — a law firm won't connect Jobber.

#### Step 4: Services
- **Currently:** Shows field-service presets (928 items: "AC Installation", "Plumbing", etc.)
- **Legal:** Need legal practice area presets. The `integrationManagesServices` flag skips this step for Jobber. For Lawmatics, practice areas are configured in Lawmatics itself, so we could:
  - (A) Skip the services step when Lawmatics/Clio is connected (set `integrationManagesServices = true` for law integrations)
  - (B) Show law-specific practice areas instead

  **Recommendation: Option A for MVP.** When Lawmatics or Clio is connected, skip the services step. Practice areas come from the platform. When NO integration is connected, show law-specific presets.

- **Change in `OnboardingPage.tsx` line 441:**
  ```typescript
  const integrationManagesServices = 
    connectedIntegrationType === 'jobber' || 
    connectedIntegrationType === 'lawmatics' || 
    connectedIntegrationType === 'clio';
  ```

#### Step 5: Voice Selection
- No changes needed. Voice options are universal.

#### Step 6: Choose Path
- **Currently:** "Keep Your Number" vs "Full Auto Pilot"
- **Legal:** Same options work for law firms. Wording is already generic enough.

#### Step 7: Call Forwarding / Transfer Setup
- No changes needed. Carrier-specific forwarding instructions are universal.

---

## 7. Frontend — Dashboard Page

### 7.1 File: `src/pages/DashboardPage.tsx` (1,931 lines)

**Current sections:**
1. **Agent Card** — Business info from Google Place (name, rating, hours, address, photo, voice)
2. **Stats Cards** — Total calls, avg duration, etc. for 24h/14d/lifetime
3. **Calendar Events** — `<CalendarEvents>` component (only shown when GCal connected)
4. **Recent Calls** — List of call records with expandable transcripts + tool calls

**Changes needed for legal vertical:**

#### Agent Card
- **Currently:** Shows Google Place rating, reviews, hours, primary type
- **Legal:** Same info is relevant for law firms. No changes needed — Google Place details work universally.

#### Stats Cards
- No changes. Call stats are universal.

#### Calendar Events
- **Currently:** Only shows when `isGcalConnected` is true (`connectedIntegration?.type === 'google-calendar'`)
- **Legal:** When Lawmatics/Clio is connected, show **Upcoming Consultations** instead of calendar events
- **Change:**
  ```typescript
  const isGcalConnected = connectedIntegration?.type === 'google-calendar';
  const isLawConnected = ['lawmatics', 'clio'].includes(connectedIntegration?.type ?? '');
  ```
  - If `isGcalConnected` → show `<CalendarEvents>` (existing)
  - If `isLawConnected` → show `<UpcomingConsultations>` (new component, fetches from `GET /me/consultations`)
  - If neither → hide section

#### Recent Calls — Tool Call Rendering
- **Currently:** Tool calls rendered for Google Calendar tools (create-event, check-availability, etc.) and field-service tools (validate-address, create-service-request)
- **Legal:** Add rendering for law-specific tool calls:
  - `law-find-contact` → "Looked up contact: [name]"
  - `law-create-lead` → "Created new lead: [name]"
  - `law-create-appointment` → "Scheduled consultation: [title] on [date]"
  - `law-cancel-appointment` → "Cancelled consultation: [title]"
  - `law-reschedule-appointment` → "Rescheduled consultation to [date]"

- **Files affected:**
  - `src/lib/tool-call-formatters.ts` — Add `isLawTool()`, `formatLawToolCall()` helpers
  - `src/pages/DashboardPage.tsx` — Add law tool call rendering in the call card expansion
  - `src/pages/CallerDetailPage.tsx` — Same law tool call rendering

---

## 8. Frontend — Callers Page → Contacts Page

### 8.1 File: `src/pages/CallersPage.tsx` (888 lines)

**Current state:** Lists all callers with phone number, name, call count, last call date. Clicking navigates to `/callers/:callerId`.

**Changes for legal vertical:**

#### Terminology
When a law integration is connected:
- **Page title:** "Callers" → "Contacts"
- **Empty state:** "No callers yet" → "No contacts yet"
- **Description:** "Your caller directory" → "Your contact directory"

#### Implementation Strategy
Use `useIntegrations()` hook to detect law integration:

```typescript
const { connectedIntegration } = useIntegrations();
const isLaw = ['lawmatics', 'clio'].includes(connectedIntegration?.type ?? '');
const entityName = isLaw ? 'Contact' : 'Caller';
const entityNamePlural = isLaw ? 'Contacts' : 'Callers';
```

#### External Link
- When Lawmatics connected: Show "View in Lawmatics" link (if `externalCustomerUrl` is set on the caller record)
- When Clio connected: Show "View in Clio" link
- Same pattern as "View in Jobber" for field-service

#### Additional Fields (Legal-specific)
- **Practice area** — Show if available from lead data
- **Lead source** — Show if available
- **Lead status** — Show badge (new/contacted/qualified/converted)

---

## 9. Frontend — Caller Detail Page → Contact Detail Page

### 9.1 File: `src/pages/CallerDetailPage.tsx` (729 lines)

**Current state:** Shows caller info, call history, calendar events, external links.

**Changes for legal vertical:**

#### Header
- "Caller Details" → "Contact Details" (when law integration connected)

#### Tabs / Sections
Current tabs: Call History, Calendar Events

Legal tabs:
- **Call History** — Same (universal)
- **Consultations** — Show appointments from Lawmatics/Clio (replaces Calendar Events)
- **Lead Info** — Show lead status, source, practice area, intake form data

#### External Links
- "View in Lawmatics" / "View in Clio" button (uses `externalCustomerUrl` field on caller record)
- Link to specific consultation in the platform (uses `externalRequestUrl` on call record, repurposed)

#### Tool Call Rendering
Same law-specific tool call rendering as Dashboard (shared via `tool-call-formatters.ts`).

---

## 10. Frontend — Appointments Page → Consultations Page

### 10.1 New Page: `src/pages/ConsultationsPage.tsx`

When a law integration is connected, the sidebar shows "Consultations" linking to `/consultations`.

This page should:
1. Fetch consultations from `GET /me/consultations` (new backend endpoint)
2. Display in a card list similar to ServiceRequestsPage
3. Show: title, date/time, contact name, status, external link

**Card fields:**
- **Title** — Consultation title (e.g., "Initial Consultation - Personal Injury")
- **Date/Time** — Scheduled start/end
- **Contact** — Name + phone
- **Status** — scheduled / confirmed / completed / cancelled / no_show
- **External link** — "View in Lawmatics" / "View in Clio"

**Tabs:** Upcoming | Past (similar to ServiceRequestsPage's tab structure)

**Empty state:** "No consultations yet. When your CallSaver AI agent schedules consultations during phone calls, they will appear here."

### 10.2 Existing AppointmentsPage.tsx

Currently only used for Google Calendar events via `<CalendarEvents>`. When law integration is connected, the sidebar routes to `/consultations` instead, so `AppointmentsPage.tsx` doesn't need changes.

---

## 11. Frontend — Service Requests Page (Not Applicable)

The ServiceRequestsPage is Jobber-specific. It will NOT be used for law firms. The sidebar routing logic already handles this — when a law integration is connected, the sidebar shows "Consultations" instead.

Similarly, `JobsPage.tsx` is HCP-specific. No changes needed.

---

## 12. Frontend — Callbacks Page

### 12.1 File: `src/pages/CallbacksPage.tsx` (30,599 bytes)

**Current state:** Shows callback requests created by the voice agent. Available when onboarding path is "keep_your_number".

**Changes for legal vertical:**

The callback system is **critical for law firms** — many caller intents route to callback (billing, documents, attorney messages). Changes:

#### Tag Display
Legal callbacks will have specific tags from the voice agent:
- `billing` → "Billing Inquiry"
- `documents` → "Document Request"
- `attorney-callback` → "Attorney Callback"
- `intake` → "New Intake"
- `admin` → "Administrative"

Add tag-to-label mapping for legal callbacks.

#### Priority
Law callbacks may need priority indication:
- Attorney callbacks = high priority
- Document requests = medium
- Billing inquiries = low

This can be handled by the voice agent setting a priority field.

---

## 13. Frontend — Locations Page

### 13.1 File: `src/pages/LocationsPage.tsx` (253,290 bytes)

**Current state:** Shows location details, phone numbers, services, service areas, voice config.

**Changes for legal vertical:**

#### Services Section
- **Currently:** "Services" with field-service presets
- **Legal:** "Practice Areas" label when law integration connected
- The services list would contain practice areas (e.g., "Personal Injury", "Family Law", "Criminal Defense")

#### Service Areas Section
- No change needed — law firms also have geographic service areas

#### Terminology
- "Services your business offers" → "Practice areas your firm handles"

---

## 14. Frontend — Service Presets Data

### 14.1 File: `src/lib/data/service-presets.ts` (928 items)

**Currently:** All field-service oriented (AC Installation, Plumbing, etc.)

**Legal practice area presets to add:**

```typescript
// Legal Practice Areas
{ label: "Personal Injury", value: "Personal Injury" },
{ label: "Car Accident", value: "Car Accident" },
{ label: "Slip and Fall", value: "Slip and Fall" },
{ label: "Medical Malpractice", value: "Medical Malpractice" },
{ label: "Workers' Compensation", value: "Workers' Compensation" },
{ label: "Family Law", value: "Family Law" },
{ label: "Divorce", value: "Divorce" },
{ label: "Child Custody", value: "Child Custody" },
{ label: "Child Support", value: "Child Support" },
{ label: "Adoption", value: "Adoption" },
{ label: "Criminal Defense", value: "Criminal Defense" },
{ label: "DUI Defense", value: "DUI Defense" },
{ label: "Drug Charges", value: "Drug Charges" },
{ label: "Assault Charges", value: "Assault Charges" },
{ label: "Theft Charges", value: "Theft Charges" },
{ label: "White Collar Crime", value: "White Collar Crime" },
{ label: "Estate Planning", value: "Estate Planning" },
{ label: "Wills & Trusts", value: "Wills & Trusts" },
{ label: "Probate", value: "Probate" },
{ label: "Real Estate Law", value: "Real Estate Law" },
{ label: "Commercial Real Estate", value: "Commercial Real Estate" },
{ label: "Landlord-Tenant Disputes", value: "Landlord-Tenant Disputes" },
{ label: "Business Law", value: "Business Law" },
{ label: "Business Formation", value: "Business Formation" },
{ label: "Contract Disputes", value: "Contract Disputes" },
{ label: "Employment Law", value: "Employment Law" },
{ label: "Wrongful Termination", value: "Wrongful Termination" },
{ label: "Discrimination Claims", value: "Discrimination Claims" },
{ label: "Harassment Claims", value: "Harassment Claims" },
{ label: "Immigration Law", value: "Immigration Law" },
{ label: "Visa Applications", value: "Visa Applications" },
{ label: "Green Card", value: "Green Card" },
{ label: "Deportation Defense", value: "Deportation Defense" },
{ label: "Bankruptcy", value: "Bankruptcy" },
{ label: "Chapter 7 Bankruptcy", value: "Chapter 7 Bankruptcy" },
{ label: "Chapter 13 Bankruptcy", value: "Chapter 13 Bankruptcy" },
{ label: "Debt Relief", value: "Debt Relief" },
{ label: "Tax Law", value: "Tax Law" },
{ label: "IRS Disputes", value: "IRS Disputes" },
{ label: "Intellectual Property", value: "Intellectual Property" },
{ label: "Trademark Registration", value: "Trademark Registration" },
{ label: "Patent Applications", value: "Patent Applications" },
{ label: "Copyright Law", value: "Copyright Law" },
{ label: "Social Security Disability", value: "Social Security Disability" },
{ label: "Veterans' Benefits", value: "Veterans' Benefits" },
{ label: "Elder Law", value: "Elder Law" },
{ label: "Guardianship", value: "Guardianship" },
{ label: "Nursing Home Abuse", value: "Nursing Home Abuse" },
{ label: "Civil Rights", value: "Civil Rights" },
{ label: "Consumer Protection", value: "Consumer Protection" },
{ label: "Insurance Disputes", value: "Insurance Disputes" },
{ label: "Product Liability", value: "Product Liability" },
{ label: "Environmental Law", value: "Environmental Law" },
{ label: "Construction Law", value: "Construction Law" },
{ label: "Traffic Violations", value: "Traffic Violations" },
{ label: "Expungement", value: "Expungement" },
{ label: "Restraining Orders", value: "Restraining Orders" },
{ label: "Mediation", value: "Mediation" },
{ label: "Arbitration", value: "Arbitration" },
{ label: "General Consultation", value: "General Consultation" },
```

**Strategy:** Add these to `ALL_SERVICES` array. Since the array is sorted alphabetically, they'll be interleaved. The autocomplete search handles the rest. No need for a separate file — but consider filtering by vertical in the future.

### 14.2 Backend Presets: `src/data/service-presets.ts`

The backend file needs the same legal presets added for when practice areas are set during provisioning.

---

## 15. Pipedream OAuth Setup

### 15.1 Lawmatics — OAuth 2.0 via Pipedream

Lawmatics uses OAuth 2.0 and is available as a Pipedream app:
1. **Create custom OAuth app in Pipedream** (project `proj_BgsRyvp`):
   - App name: `lawmatics`
   - Auth type: OAuth 2.0 (Pipedream has built-in Lawmatics support)
   - Use Pipedream's pre-approved OAuth client OR register a custom one in Lawmatics developer settings
   - Scopes: contacts, leads, appointments (as available)
2. **Record oauthAppId** (e.g., `oa_YYYYYY`) → update `integrations-config.ts`
3. Same connection flow as Jobber/Google Calendar — user clicks Connect, Pipedream handles OAuth redirect

### 15.2 Clio — OAuth 2.0 via Pipedream

1. **Register as Clio developer:** https://app.clio.com/nc/#/settings/developer_applications
2. **Create OAuth app** in Clio developer console:
   - Name: "CallSaver"
   - Redirect URI: Pipedream's callback URL
   - Scopes: `contacts:read`, `contacts:write`, `calendar_entries:read`, `calendar_entries:write`
3. **Get Client ID + Client Secret** from Clio
4. **Create custom OAuth app in Pipedream** (project `proj_BgsRyvp`):
   - App name: `clio`
   - Auth type: OAuth 2.0
   - Authorization URL: `https://app.clio.com/oauth/authorize`
   - Token URL: `https://app.clio.com/oauth/token`
   - Client ID: (from step 3)
   - Client Secret: (from step 3)
   - Scopes: `contacts:read contacts:write calendar_entries:read calendar_entries:write`
5. **Record oauthAppId** (e.g., `oa_XXXXXX`) → update `integrations-config.ts`

---

## 16. Database / Prisma Changes

### 16.1 No Schema Changes Required

The existing schema supports law integrations without changes:
- `integrationConnection` (nango_connections table) — stores connectionId for OAuth (Clio) or config.apiKey for API key (Lawmatics)
- `callers` table — `externalCustomerUrl` field already exists (for "View in Lawmatics/Clio" links)
- `call_records` table — `externalRequestId`, `externalRequestUrl` fields exist (for linking to consultations)

### 16.2 Potential Addition: Vertical Field

Consider adding a `vertical` field to the `organizations` table:

```prisma
model Organization {
  // ... existing fields
  vertical  String?  @default("field-service")  // 'field-service' | 'law' | 'hospitality' | etc.
}
```

This would:
- Enable vertical-specific onboarding flows
- Enable vertical-specific service presets in provisioning
- Enable frontend vertical detection without relying solely on integration type

**Decision:** Defer for MVP. Integration type (`lawmatics`/`clio`) is sufficient to determine vertical for now.

---

## 17. Email Templates — Legal Vertical Audit

All email templates live in `src/email/templates/` with centralized config in `src/email/config/email-config.ts`.

### 17.1 Full Template Inventory (21 emails)

| # | Template | File | Verdict | Issue |
|---|----------|------|---------|-------|
| 1 | **Welcome Email** | `welcome-email.ts` | ⚠️ **NEEDS UPDATE** | Says "book jobs", "service areas", "services" — field-service language |
| 2 | **Magic Link** | `magic-link.ts` | ✅ Generic | "sign-in link to access your CallSaver dashboard" — works for any vertical |
| 3 | **Password Reset** | `password-reset.ts` | ✅ Generic | "reset your CallSaver password" — universal |
| 4 | **Stripe Checkout** | `stripe-checkout.ts` | ✅ Generic | "join CallSaver" + trial info — no vertical-specific language |
| 5 | **Docs Invitation** | `docs-invitation.ts` | ✅ Generic | Internal/developer email — not customer-facing |
| 6 | **First Payment** | `billing/first-payment.ts` | ✅ Generic | "AI voice agent will continue answering calls" — works for law |
| 7 | **Trial Ending** | `billing/trial-ending.ts` | ✅ Generic | "AI voice agent will continue answering calls" — works for law |
| 8 | **Payment Failed** | `billing/payment-failed.ts` | ✅ Generic | Payment mechanics only — no vertical language |
| 9 | **Payment Failed Reminder** | `billing/payment-failed-reminder.ts` | ✅ Generic | "keep your AI voice agent answering calls 24/7" — works for law |
| 10 | **Payment Failed Final** | `billing/payment-failed-final.ts` | ✅ Generic | Same as above — universal |
| 11 | **Subscription Cancelled** | `billing/subscription-cancelled.ts` | ✅ Generic | "AI voice agent will stop answering calls" — works for law |
| 12 | **Annual Upgrade** | `billing/annual-upgrade.ts` | ✅ Generic | Savings math + "AI voice agent will continue" — works for law |
| 13 | **Implementation Fee** | `billing/implementation-fee-charged.ts` | ✅ Generic | "AI voice agent setup and training" — works for law |
| 14 | **Getting Started** | `nurture/getting-started.ts` | ⚠️ **NEEDS UPDATE** | "answer questions about your services" — should say "practice areas" for law |
| 15 | **Feature Highlight** | `nurture/feature-highlight.ts` | ⚠️ **NEEDS UPDATE** | "Appointment scheduling" + "book appointments" — should say "consultations" for law |
| 16 | **Annual Savings** | `nurture/annual-savings.ts` | ✅ Generic | Pure pricing/savings math — no vertical language |
| 17 | **Final Urgency** | `nurture/final-urgency.ts` | ⚠️ **NEEDS UPDATE** | "focused on jobs" — field-service language, wrong for law firms |
| 18 | **First Call Celebration** | `nurture/first-call-celebration.ts` | ✅ Generic | "answered its first call" + call details — works for any vertical |
| 19 | **Weekly Summary** | `reports/weekly-summary.ts` | ⚠️ **NEEDS UPDATE** | "Appointments" section header — should say "Consultations" for law |
| 20 | **Ticket Created** | `support/ticket-created.ts` | ✅ Generic | Support ticket mechanics — universal |
| 21 | **Ticket Reply** | `support/ticket-reply.ts` | ✅ Generic | Support ticket mechanics — universal |
| 22 | **Ticket Resolved** | `support/ticket-resolved.ts` | ✅ Generic | Support ticket mechanics — universal |
| 23 | **Ticket Status Update** | `support/ticket-status-update.ts` | ✅ Generic | Support ticket mechanics — universal |

### 17.2 Emails Requiring Updates (5 of 23)

#### 1. Welcome Email (`welcome-email.ts`)

**Current body (field-service oriented):**
```
You're less than 5 minutes away from capturing missed revenue. Once you sign in, we'll guide you through some quick setup steps:
1. Define the service areas you operate in.
2. Add the services your business provides.
3. Choose your AI voice to find the right tone for your business.
4. Sync your calendar so your new agent can book jobs for you.
```

**Problem:** "service areas", "services your business provides", "book jobs" are all field-service terminology.

**Fix:** Make the onboarding steps dynamic based on vertical. Pass `vertical` (or `integrationType`) to the email function and switch copy:

```
// Law vertical:
1. Define the areas your firm serves.
2. Select your practice areas.
3. Choose your AI voice to match your firm's tone.
4. Connect your legal CRM so your agent can schedule consultations.
```

**Implementation:** Add `vertical?: 'field-service' | 'law'` param to `WelcomeEmailOptions`. Default to current copy. When `vertical === 'law'`, use law-specific copy.

#### 2. Getting Started Email (`nurture/getting-started.ts`)

**Current:**
```
📞 Make a test call — Call your business number right now. Your AI will greet you by time of day and can answer questions about your services.
⚙️ Fine-tune your setup — Add more services, adjust your service areas, or change your AI's voice anytime from your dashboard.
```

**Problem:** "questions about your services", "Add more services", "service areas"

**Fix for law:**
```
📞 Make a test call — Call your firm's number right now. Your AI will greet callers professionally and can answer questions about your practice areas.
⚙️ Fine-tune your setup — Update your practice areas, adjust your service regions, or change your AI's voice anytime from your dashboard.
```

**Implementation:** Same pattern — add `vertical` param, switch copy.

#### 3. Feature Highlight Email (`nurture/feature-highlight.ts`)

**Current:**
```
📅 Appointment scheduling — If you connect an integration, your AI can book appointments directly into your calendar.
```

**Problem:** "book appointments" — should be "schedule consultations" for law.

**Fix for law:**
```
📅 Consultation scheduling — Connect your legal CRM and your AI can schedule consultations directly with potential clients.
```

#### 4. Final Urgency Email (`nurture/final-urgency.ts`)

**Current:**
```
Was available 24/7 while you focused on jobs
```

**Problem:** "focused on jobs" is field-service language.

**Fix for law:**
```
Was available 24/7 while you focused on your cases
```

#### 5. Weekly Summary Email (`reports/weekly-summary.ts`)

**Current:**
```
📅 Appointments
- Appointments booked
- Appointments rescheduled
- Appointments cancelled
```

**Problem:** "Appointments" header and labels — should be "Consultations" for law.

**Fix for law:**
```
📅 Consultations
- Consultations scheduled
- Consultations rescheduled
- Consultations cancelled
```

**Implementation:** The weekly summary already receives structured data. Add `vertical` to `WeeklySummaryEmailOptions` and switch the section header + labels.

### 17.3 Implementation Strategy

**Option A: Vertical parameter on each email function** (Recommended for MVP)
- Add `vertical?: string` to the 5 affected email option interfaces
- Use simple ternary/conditional for copy switching
- Minimal code change, no new infrastructure
- Caller passes `vertical` from organization data

**Option B: Centralized vertical-aware copy system** (Future)
- Create a `getVerticalCopy(vertical, key)` utility
- All emails pull copy from a central registry
- Better for 5+ verticals, overkill for 2

**Recommendation:** Option A for MVP. Only 5 emails need changes, and the conditional logic is simple.

### 17.4 Email Config (`email-config.ts`)

The centralized config (subject lines, sender addresses, greetings) is **fully generic** — no vertical-specific language in any subject line or sender config. No changes needed.

### 17.5 Email Service (`service.ts`) & Brand Assets

The email service, MJML templates, and brand assets are **fully generic**. The CallSaver logo, colors, and layout work for all verticals. No changes needed.

---

## 18. Multi-Transfer Routing for Legal Vertical

### 18.1 Why Legal Practices Need Multiple Transfer Numbers

**Current system:** Single `transferPhoneNumber` field on `Location` (Prisma `String?`). The voice agent always transfers to the same number regardless of context.

**Problem for law firms:** Legal practices have distinct departments with different contact people:

| Caller Intent | Who Should Receive | Example |
|--------------|-------------------|---------|
| New potential client / intake inquiry | **Intake Coordinator** | "I need help with a custody dispute" |
| Existing case question / "talk to my lawyer" | **Assigned Attorney** or **Paralegal** | "What's the status of my case?" |
| Billing / payment / invoice question | **Billing Department** | "I have a question about my invoice" |
| Emergency / arrest / time-sensitive | **On-Call Attorney** (urgent) | "My ex violated the restraining order" |
| General admin / scheduling | **Office Manager / Front Desk** | "I need to reschedule my meeting" |

A single transfer number forces all transfers to one person, which is wrong for multi-person practices.

### 18.2 Data Model Change

Replace the single `transferPhoneNumber: String?` with a `transferRouting: Json?` field on `Location`:

```prisma
model Location {
  // ... existing fields
  transferPhoneNumber  String?  @map("transfer_phone_number")       // KEEP for backward compat (field service)
  transferRouting      Json?    @map("transfer_routing")             // NEW: multi-number routing for law vertical
}
```

**`transferRouting` JSON structure:**

```typescript
interface TransferRouting {
  defaultNumber: string;         // Fallback if no rule matches (E.164)
  routes: TransferRoute[];
}

interface TransferRoute {
  label: string;                 // "Intake Coordinator", "Billing", "Attorney"
  phoneNumber: string;           // E.164 format
  description?: string;          // "Handles new client inquiries"
  conditions: string[];          // Caller intent tags: ["new_client", "intake"]
  priority?: 'normal' | 'urgent'; // Urgent routes get immediate transfer
}
```

**Example for a law firm:**

```json
{
  "defaultNumber": "+15551234567",
  "routes": [
    {
      "label": "Intake Coordinator",
      "phoneNumber": "+15551234567",
      "description": "New potential client inquiries",
      "conditions": ["new_client", "intake", "consultation_request"]
    },
    {
      "label": "Billing Department",
      "phoneNumber": "+15559876543",
      "description": "Payment and invoice questions",
      "conditions": ["billing", "payment", "invoice"]
    },
    {
      "label": "On-Call Attorney",
      "phoneNumber": "+15555551234",
      "description": "Urgent legal matters and emergencies",
      "conditions": ["emergency", "arrest", "urgent"],
      "priority": "urgent"
    },
    {
      "label": "Office Manager",
      "phoneNumber": "+15552223333",
      "description": "General administrative and scheduling",
      "conditions": ["scheduling", "general", "documents"]
    }
  ]
}
```

### 18.3 Agent Config Endpoint Changes

In `POST /internal/agent-config` (server.ts ~line 9260):

1. If `location.transferRouting` exists (law vertical), include full routing config in response
2. Build routing-aware transfer instructions instead of single-number instructions
3. The voice agent system prompt gets routing rules:

```
TRANSFER ROUTING:
You can transfer calls to different departments based on the caller's need:
- "Intake Coordinator" (+15551234567): New client inquiries, consultations → use transfer_call with department="intake"
- "Billing Department" (+15559876543): Payment, invoice, billing questions → use transfer_call with department="billing"
- "On-Call Attorney" (+15555551234): Emergencies, arrests, urgent matters → use transfer_call with department="urgent"
- "Office Manager" (+15552223333): General admin, scheduling, documents → use transfer_call with department="general"

If the caller's need doesn't match any department, transfer to the default number.
```

### 18.4 Transfer Tool Changes (`transfer_call.py`)

Update the `transfer_call` tool to accept a `department` parameter:

```python
async def transfer_call(
    ctx: RunContext,
    phone_number: Optional[str] = None,    # Direct number override (existing)
    department: Optional[str] = None,       # NEW: Route by department label/condition
    message: Optional[str] = None,
) -> dict:
```

**Routing resolution priority:**
1. `phone_number` argument (explicit override — same as today)
2. `department` argument → look up in `transferRouting.routes` by matching condition
3. `transferRouting.defaultNumber` (law vertical fallback)
4. `transferPhoneNumber` (field-service fallback — backward compat)
5. `locationPhoneNumber` (Google Place business number)

### 18.5 Request Callback Changes (`request_callback.py`)

Update `request_callback` to also include `department` tagging for law vertical:
- Existing `reason` field already covers most cases ("billing", "scheduling_issue", etc.)
- Add department info to the callback request so the right person calls back
- The API endpoint `POST /internal/callback-request` would include a `department` field

### 18.6 Frontend — Transfer Routing Settings

Add a **Transfer Routing** section to the Location Settings page (for law vertical):
- Show a list of configured transfer routes with labels and phone numbers
- Add/edit/remove routes
- Each route has: label, phone number, description, condition tags
- Save as `transferRouting` JSON on the location

### 18.7 Backward Compatibility

- **Field service locations** continue using single `transferPhoneNumber` — no changes needed
- **Law locations** use `transferRouting` — the agent-config endpoint checks which field is populated
- The Python agent's `transfer_call.py` already supports a `phone_number` argument, so the `department` param is additive
- If `transferRouting` is null/empty, falls back to existing single-number behavior

### 18.8 Migration

```sql
-- Migration: add_transfer_routing
ALTER TABLE locations ADD COLUMN transfer_routing JSONB;
```

No data migration needed — existing locations keep using `transferPhoneNumber`, new law locations get `transferRouting` during onboarding.

---

## 19. Python Agent (livekit-python) Changes

### 19.1 Overview of Current Architecture

The Python agent (`livekit-python/server.py`) follows this flow:
1. **Entry** (`entry()`) — Extract location ID from room name, fetch agent config from API
2. **Agent config** — `POST /internal/agent-config` returns system prompt, tools list, voice config, transfer config
3. **Tool registration** — `tools/__init__.py` dynamically registers tools based on `agent_config.tools[]` names
4. **Session** — `AgentSession` runs with STT→LLM→TTS pipeline + registered tools
5. **Transfer** — Two-path approach: Path A (callback) or Path B (live SIP REFER transfer)

**Key insight:** The system prompt and tool list are assembled **server-side** in `server.ts`, so the Python agent is mostly generic. But tool implementations and registration need law-specific additions.

### 19.2 New Tool Files to Create

Create 3 new tool files in `livekit-python/tools/`:

#### `tools/law_contact.py`
```python
# law-find-contact-by-phone — POST /internal/tools/law-find-contact
# law-update-contact — POST /internal/tools/law-update-contact
```
- `law_find_contact_by_phone_tool(context)` → Calls backend law-tools route
- `law_update_contact_tool(context)` → Calls backend law-tools route

#### `tools/law_lead.py`
```python
# law-create-lead — POST /internal/tools/law-create-lead
```
- `law_create_lead_tool(context)` → Calls backend law-tools route
- Args: `first_name`, `last_name`, `email` (optional), `legal_need` (practice area), `notes`

#### `tools/law_appointment.py`
```python
# law-get-appointments — POST /internal/tools/law-get-appointments
# law-get-appointment — POST /internal/tools/law-get-appointment
# law-create-appointment — POST /internal/tools/law-create-appointment
# law-update-appointment — POST /internal/tools/law-update-appointment
# law-cancel-appointment — POST /internal/tools/law-cancel-appointment
```
- All follow the same HTTP-call-to-backend pattern as existing `fs_*` tools
- Key difference: terminology in tool docstrings uses "consultation" not "appointment"

### 19.3 Tool Pattern

All law tools follow the exact same HTTP-to-backend pattern as the field-service tools. Example:

```python
def law_find_contact_by_phone_tool(context: "ToolContext"):
    @function_tool()
    async def law_find_contact_by_phone(ctx: RunContext, phone_number: str) -> dict:
        """Look up a contact in the law firm's CRM by phone number."""
        tool_context = _get_tool_context(ctx)
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                f"{tool_context.api_url}/internal/tools/law-find-contact",
                headers={"Authorization": f"Bearer {tool_context.internal_api_key}"},
                json={
                    "locationId": tool_context.location_id,
                    "phoneNumber": phone_number,
                },
            )
            return response.json()
    return law_find_contact_by_phone
```

### 19.4 Tool Registration (`tools/__init__.py`)

Add imports and elif branches:

```python
# New imports at top
from .law_contact import law_find_contact_by_phone_tool, law_update_contact_tool
from .law_lead import law_create_lead_tool
from .law_appointment import (
    law_get_appointments_tool, law_get_appointment_tool,
    law_create_appointment_tool, law_update_appointment_tool,
    law_cancel_appointment_tool,
)

# New elif branches in register_tools():
elif tool_name == "law-find-contact-by-phone":
    tool = law_find_contact_by_phone_tool(context)
elif tool_name == "law-update-contact":
    tool = law_update_contact_tool(context)
elif tool_name == "law-create-lead":
    tool = law_create_lead_tool(context)
elif tool_name == "law-get-appointments":
    tool = law_get_appointments_tool(context)
elif tool_name == "law-get-appointment":
    tool = law_get_appointment_tool(context)
elif tool_name == "law-create-appointment":
    tool = law_create_appointment_tool(context)
elif tool_name == "law-update-appointment":
    tool = law_update_appointment_tool(context)
elif tool_name == "law-cancel-appointment":
    tool = law_cancel_appointment_tool(context)
```

### 19.5 Transfer Tool Update (`tools/transfer_call.py`)

Add `department` parameter for multi-transfer routing:

```python
async def transfer_call(
    ctx: RunContext,
    phone_number: Optional[str] = None,
    department: Optional[str] = None,  # NEW
    message: Optional[str] = None,
) -> dict:
```

Resolution logic:
```python
# If department specified, look up in transferRouting
if department and not phone_number:
    transfer_routing = agent_config.get("transferRouting")
    if transfer_routing and transfer_routing.get("routes"):
        for route in transfer_routing["routes"]:
            if department in route.get("conditions", []) or department == route.get("label", "").lower():
                phone_number = route["phoneNumber"]
                print(f"[transfer] Routed department='{department}' to {route['label']} ({phone_number})")
                break
        if not phone_number:
            phone_number = transfer_routing.get("defaultNumber")
```

### 19.6 No Changes Needed (Handled Server-Side)

These aspects are handled entirely in the **backend** (server.ts / utils.ts) and require **no Python changes**:

- **System prompt construction** — `lawInstructions` is built server-side and sent via agent-config
- **Tool list** — The backend determines which tools to include based on connected integration
- **First message** — Configured per-agent, no Python logic needed
- **Transfer instructions** — Injected into system prompt by agent-config endpoint
- **STT/LLM/TTS providers** — Generic, no vertical-specific configuration needed
- **Silence detection** — Generic, works for all verticals
- **Max duration watchdog** — Generic, but transfer routing now uses `transferRouting.defaultNumber` fallback

### 19.7 Max Duration Watchdog Update (`server.py` ~line 1520)

The `max_duration_watchdog()` currently uses `transferPhoneNumber || locationPhoneNumber`. For law vertical with `transferRouting`, it should also check `transferRouting.defaultNumber`:

```python
# In max_duration_watchdog:
transfer_routing = agent_config.get("transferRouting")
if transfer_routing:
    transfer_phone = transfer_routing.get("defaultNumber")
else:
    transfer_phone = transfer_phone_number or location_phone_number
```

---

## 20. Implementation Order & Estimates

### Phase 1: Backend Lawmatics Adapter (4-6 hours)

| # | Task | Effort |
|---|------|--------|
| 1.1 | Fix scaffolding: Registry nangoConnection rename + Lawmatics OAuth auth model in Registry + Factory | 30 min |
| 1.2 | Create `LawmaticsClient.ts` (HTTP client) | 1.5 hours |
| 1.3 | Create `LawmaticsAdapter.ts` (adapter implementation) | 2 hours |
| 1.4 | Create `src/routes/law-tools.ts` (voice agent tool endpoints) | 1.5 hours |
| 1.5 | Wire law-tools.ts into `server.ts` | 30 min |

### Phase 2: Frontend Integration Config + Sidebar (1-2 hours)

| # | Task | Effort |
|---|------|--------|
| 2.1 | Add Lawmatics + Clio to `integrations-config.ts` | 15 min |
| 2.2 | Add logo assets to `public/images/` | 15 min |
| 2.3 | Update `app-sidebar.tsx` — law-specific rename logic | 30 min |
| 2.4 | Add `/contacts`, `/consultations` routes to `App.tsx` | 15 min |
| 2.5 | Update `OnboardingPage.tsx` — integrationManagesServices for law | 15 min |

### Phase 3: Frontend Page Adaptations (4-6 hours)

| # | Task | Effort |
|---|------|--------|
| 3.1 | Add vertical context/hook (`useVertical()`) | 30 min |
| 3.2 | Create `ConsultationsPage.tsx` | 2 hours |
| 3.3 | Update `CallersPage.tsx` — terminology switching | 30 min |
| 3.4 | Update `CallerDetailPage.tsx` — legal tabs + links | 1 hour |
| 3.5 | Update `DashboardPage.tsx` — law tool call rendering + consultations | 1 hour |
| 3.6 | Update `tool-call-formatters.ts` — law tool formatting | 30 min |
| 3.7 | Add legal service presets to `service-presets.ts` | 15 min |
| 3.8 | Update `LocationsPage.tsx` — "Practice Areas" label | 15 min |
| 3.9 | Update 5 email templates with `vertical` param + law copy | 1 hour |

### Phase 4: Voice Agent Integration — Backend + Python Agent (4-6 hours)

| # | Task | Effort |
|---|------|--------|
| 4.1 | Add `lawInstructions` prompt to `utils.ts` / `server.ts` | 1 hour |
| 4.2 | Update `agent-config` endpoint — detect law vertical, include law tools + routing config | 30 min |
| 4.3 | Create `livekit-python/tools/law_contact.py` (find-contact, update-contact) | 30 min |
| 4.4 | Create `livekit-python/tools/law_lead.py` (create-lead) | 20 min |
| 4.5 | Create `livekit-python/tools/law_appointment.py` (get/create/update/cancel) | 45 min |
| 4.6 | Update `livekit-python/tools/__init__.py` — add law tool imports + registration | 20 min |
| 4.7 | Update `livekit-python/tools/transfer_call.py` — add `department` param + routing lookup | 30 min |
| 4.8 | Update `livekit-python/server.py` — max_duration_watchdog `transferRouting` fallback | 15 min |
| 4.9 | Update `livekit-python/tools/request_callback.py` — add `department` tagging | 15 min |

### Phase 5: Multi-Transfer Routing (2-3 hours)

| # | Task | Effort |
|---|------|--------|
| 5.1 | Prisma migration: add `transfer_routing JSONB` to `locations` | 15 min |
| 5.2 | Update `agent-config` endpoint — build routing-aware transfer instructions | 45 min |
| 5.3 | Update location schema + update endpoint to accept `transferRouting` | 30 min |
| 5.4 | Frontend: Transfer routing settings UI on LocationsPage (law vertical) | 1 hour |
| 5.5 | Update `OnboardingPage.tsx` — collect transfer routing during law onboarding | 30 min |

### Phase 6: Backend Clio Adapter (4-6 hours)

| # | Task | Effort |
|---|------|--------|
| 6.1 | Set up Clio OAuth app + Pipedream custom OAuth | 30 min |
| 6.2 | Create `ClioClient.ts` (HTTP client) | 1.5 hours |
| 6.3 | Create `ClioAdapter.ts` (adapter with phone-search workaround) | 2.5 hours |
| 6.4 | Test OAuth flow end-to-end | 1 hour |

### Phase 7: Testing & Polish (3-4 hours)

| # | Task | Effort |
|---|------|--------|
| 7.1 | Create test script for Lawmatics adapter | 1 hour |
| 7.2 | Create test script for Clio adapter | 1 hour |
| 7.3 | E2E voice agent test with law tools + transfer routing | 1 hour |
| 7.4 | Test multi-transfer routing (department-based transfers) | 30 min |

---

## Total Estimated Effort

| Phase | Hours |
|-------|-------|
| Phase 1: Lawmatics adapter | 4-6 |
| Phase 2: Frontend config + sidebar | 1-2 |
| Phase 3: Frontend page adaptations + emails | 5-7 |
| Phase 4: Voice agent (backend + Python) | 4-6 |
| Phase 5: Multi-transfer routing | 2-3 |
| Phase 6: Clio adapter | 4-6 |
| Phase 7: Testing | 3-4 |
| **Total** | **23-34 hours** |

---

## Summary: Key Files Modified/Created

### New Files (Backend)
- `src/adapters/law/platforms/lawmatics/LawmaticsClient.ts`
- `src/adapters/law/platforms/lawmatics/LawmaticsAdapter.ts`
- `src/adapters/law/platforms/clio/ClioClient.ts`
- `src/adapters/law/platforms/clio/ClioAdapter.ts`
- `src/routes/law-tools.ts`

### New Files (Python Agent)
- `livekit-python/tools/law_contact.py` — find-contact-by-phone + update-contact tools
- `livekit-python/tools/law_lead.py` — create-lead tool
- `livekit-python/tools/law_appointment.py` — get/create/update/cancel appointment tools

### Modified Files (Backend)
- `src/adapters/law/LawAdapterRegistry.ts` — nangoConnection → integrationConnection fix + move Lawmatics to PIPEDREAM_PLATFORMS
- `src/adapters/law/LawAdapterFactory.ts` — Lawmatics: apiKey → accessToken (OAuth)
- `src/server.ts` — mount law-tools routes, update agent-config endpoint (law vertical detection + transferRouting + routing-aware transfer instructions)
- `src/utils.ts` — add lawInstructions prompt
- `src/schemas/user/user.ts` — add `transferRouting` to location schema
- `src/contracts/more-user-endpoints.contract.ts` — add `transferRouting` to update-location schema
- `prisma/schema.prisma` — add `transferRouting Json?` to Location model
- `src/email/templates/welcome-email.ts` — add `vertical` param, law-specific onboarding steps
- `src/email/templates/nurture/getting-started.ts` — add `vertical` param, "practice areas" copy
- `src/email/templates/nurture/feature-highlight.ts` — add `vertical` param, "consultations" copy
- `src/email/templates/nurture/final-urgency.ts` — add `vertical` param, "cases" instead of "jobs"
- `src/email/templates/reports/weekly-summary.ts` — add `vertical` param, "Consultations" labels

### Modified Files (Python Agent)
- `livekit-python/tools/__init__.py` — import + register 8 law tools
- `livekit-python/tools/transfer_call.py` — add `department` param + `transferRouting` lookup
- `livekit-python/tools/request_callback.py` — add `department` tagging for law vertical
- `livekit-python/server.py` — max_duration_watchdog `transferRouting.defaultNumber` fallback

### New Files (Frontend)
- `src/pages/ConsultationsPage.tsx`
- `public/images/lawmatics.png`
- `public/images/clio.png`

### Modified Files (Frontend)
- `src/lib/integrations-config.ts` — add Lawmatics + Clio
- `src/components/layout/app-sidebar.tsx` — law-specific sidebar rename
- `src/App.tsx` — add /contacts, /consultations routes
- `src/pages/OnboardingPage.tsx` — integrationManagesServices for law + transfer routing collection
- `src/pages/DashboardPage.tsx` — law tool rendering + consultations section
- `src/pages/CallersPage.tsx` — terminology switching
- `src/pages/CallerDetailPage.tsx` — legal tabs + external links
- `src/pages/LocationsPage.tsx` — "Practice Areas" label + transfer routing settings UI
- `src/lib/tool-call-formatters.ts` — law tool formatting
- `src/lib/data/service-presets.ts` — legal practice area presets
