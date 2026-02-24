# Multi-Location Integration Plan: Jobber & Housecall Pro

## Date: Feb 17, 2026

---

## 1. Current Architecture Summary

### How Provisioning Works Today

Our provisioning pipeline is triggered from Attio CRM and flows through:

```
Attio Person → POST /provision → DocuSeal (MSA) → Stripe Checkout → Webhook → executeProvisioning()
```

**Key entities created during provisioning:**

| Entity | Cardinality | Source of Truth |
|--------|------------|-----------------|
| Organization | 1 per Attio Company | `attioCompanyId` (unique) |
| User | 1+ per Organization | `attioPersonId` (unique) |
| Location | 1+ per Organization | `googlePlaceId` (from Attio) |
| Agent | 1 per Location | Auto-created during provisioning |
| LivekitAgent | 1 per Location | Created during SIP setup |
| TwilioPhoneNumber | 1 per Location | Provisioned per location |

**Current flow in `executeProvisioning()`:**
1. Fetch Attio person + company data
2. Create Organization (linked to Attio company, Stripe customer/subscription)
3. Create User + OrganizationMember (owner)
4. For each `googlePlaceId` → `createLocationWithFullEnrichment()`:
   - Fetch Google Place Details
   - Create Location record
   - Create default Agent
   - Classify business categories (LLM)
   - Assign service presets
   - Set up service areas
   - Generate system prompt
   - Provision Twilio phone number + LiveKit SIP

### How Integrations Work Today

Integrations are stored at the **Organization** level, not the Location level:

| Model | Scope | Auth Method |
|-------|-------|-------------|
| `NangoConnection` | Organization | OAuth (Jobber, ServiceTitan) |
| `OrganizationIntegration` | Organization | API key (HCP) |

**The `FieldServiceAdapterRegistry`** resolves adapters by:
1. Taking a `locationId`
2. Looking up `location.organizationId`
3. Finding the active `NangoConnection` or `OrganizationIntegration` for that org
4. Returning a cached adapter instance keyed by `locationId:platform`

**Critical assumption today: One integration per organization, shared across all locations.**

### Current Data Model Relationships

```
Organization (1)
├── OrganizationIntegration (1 per platform) ← org-level
├── NangoConnection (1 per platform)         ← org-level
├── Location (1+)
│   ├── Agent (1+)
│   ├── LivekitAgent (1)
│   ├── TwilioPhoneNumber (1)
│   ├── googlePlaceDetails (JSON)
│   ├── services[] (string array)
│   ├── externalPlatformId (nullable)        ← currently unused
│   └── CallRecord, Appointment, etc.
└── OrganizationMember (1+)
    └── User
```

---

## 2. How Jobber Handles Multi-Location

### Jobber Central (Franchise Model)

Jobber uses a **separate account per location** model with a central management layer:

- Each franchise location is a **separate Jobber account** with its own data silo
- **Jobber Central** is a group-level workspace for franchise owners to view aggregated insights
- Users switch between locations via a dropdown in the Jobber UI
- Each account has its own clients, jobs, invoices, schedule, etc.

### Implications for Our Integration

**OAuth scope**: When a user connects Jobber via Nango OAuth, the OAuth token is scoped to **one Jobber account** (one location). To support multiple Jobber locations, the user would need to:

1. Connect Jobber separately for each location (separate OAuth flow per account), OR
2. Use Jobber Central API (if/when available) — currently Jobber Central is UI-only, no public API

**This means**: For Jobber multi-location, we likely need **one NangoConnection per Location**, not per Organization.

### Jobber API Considerations

- Jobber's GraphQL API is scoped to the authenticated account
- No `X-Company-Id` header or location filter — the OAuth token determines which account's data you access
- Each Jobber account has its own `productOrServices`, `clients`, `jobs`, `schedule`, etc.
- The service catalog (products/services) is per-account, so different locations may offer different services

---

## 3. How Housecall Pro Handles Multi-Location

### Multi-Location API (X-Company-Id Header)

HCP has **native multi-location support** via a single API key:

```
GET https://api.housecallpro.com/company → returns all location IDs
X-Company-Id: <location-uuid> → scopes requests to that location
```

**Key characteristics:**
- A single API key grants access to the parent location and all descendants
- Location hierarchy: Main → Sub-locations → Nested locations
- API key access follows the hierarchy (parent can access children, not vice versa)
- OAuth tokens provide user-level access control (may be restricted to subset of locations)

### Implications for Our Integration

**Single credential, multiple locations**: One `OrganizationIntegration` record with one API key can serve all HCP locations. The adapter just needs to include the `X-Company-Id` header per request.

**This means**: For HCP, the current org-level integration model works, but the adapter needs to know which HCP location ID maps to which CallSaver Location.

### HCP API Considerations

- `GET /company` returns all accessible locations with their IDs
- Each API request can be scoped to a specific location via `X-Company-Id`
- Customers, jobs, invoices, etc. are all location-scoped when the header is present
- Without the header, requests return data for the API key owner's location only

---

## 4. Gap Analysis: What Needs to Change

### 4.1 Schema Changes

#### New: `Location.externalPlatformId` (already exists, currently unused)

This field was added but never populated. It should store:
- **Jobber**: The Jobber account ID (from the OAuth token's account context)
- **HCP**: The HCP location UUID (from `GET /company` response)

#### New: Location-level integration linking

Currently, integrations are org-level. We need a way to link a specific integration credential to a specific location.

**Option A: Add `locationId` to NangoConnection + OrganizationIntegration**

```prisma
model NangoConnection {
  // ... existing fields ...
  locationId String? @map("location_id")  // NEW: optional, for location-scoped connections
  location   Location? @relation(fields: [locationId], references: [id])
}

model OrganizationIntegration {
  // ... existing fields ...
  locationId String? @map("location_id")  // NEW: optional, for location-scoped integrations
  location   Location? @relation(fields: [locationId], references: [id])
}
```

**Option B: New `LocationIntegration` join table**

```prisma
model LocationIntegration {
  id                       String  @id @default(cuid())
  locationId               String  @map("location_id")
  platform                 String  // 'jobber', 'housecallpro', 'servicetitan'
  externalLocationId       String? @map("external_location_id") // HCP location UUID, Jobber account ID
  nangoConnectionId        String? @map("nango_connection_id")
  organizationIntegrationId String? @map("organization_integration_id")
  config                   Json?   // Platform-specific config (e.g., autoScheduleAssessment)
  isActive                 Boolean @default(true)
  
  location                 Location @relation(...)
  nangoConnection          NangoConnection? @relation(...)
  organizationIntegration  OrganizationIntegration? @relation(...)
  
  @@unique([locationId, platform])
}
```

**Recommendation: Option B** — cleaner separation, supports both auth strategies, and the `config` field can hold location-specific settings like `autoScheduleAssessment` (currently on LivekitAgent.config).

### 4.2 Adapter Registry Changes

The `FieldServiceAdapterRegistry.getAdapter()` currently resolves credentials at the org level. It needs to:

1. Check for a `LocationIntegration` record first (location-scoped)
2. Fall back to org-level lookup (backward compatible)
3. For HCP: Pass `externalLocationId` to the adapter so it includes `X-Company-Id` header
4. For Jobber: Use the location-specific `NangoConnection`

```typescript
// Pseudocode for updated resolution
async getAdapter(locationId: string): Promise<FieldServiceAdapter> {
  // 1. Check LocationIntegration (new, location-scoped)
  const locIntegration = await prisma.locationIntegration.findFirst({
    where: { locationId, isActive: true },
    include: { nangoConnection: true, organizationIntegration: true },
  });
  
  if (locIntegration) {
    return this.buildAdapterFromLocationIntegration(locIntegration);
  }
  
  // 2. Fall back to org-level (existing behavior)
  return this.buildAdapterFromOrgLevel(locationId);
}
```

### 4.3 HCP Adapter Changes

The `HousecallProAdapter` needs to accept an optional `locationId` (HCP's location UUID) and include it as `X-Company-Id` header on every request:

```typescript
class HousecallProAdapter extends BaseFieldServiceAdapter {
  private apiKey: string;
  private hcpLocationId?: string; // HCP's location UUID
  
  constructor(config: { apiKey: string; hcpLocationId?: string }) {
    this.apiKey = config.apiKey;
    this.hcpLocationId = config.hcpLocationId;
  }
  
  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Authorization': `Bearer ${this.apiKey}`,
    };
    if (this.hcpLocationId) {
      headers['X-Company-Id'] = this.hcpLocationId;
    }
    return headers;
  }
}
```

### 4.4 Jobber Adapter Changes

Minimal changes needed for Jobber — each location already gets its own OAuth connection. The main change is ensuring the `NangoConnection` is linked to the correct `Location` (not just the Organization).

### 4.5 Provisioning Changes

#### Scenario A: Customer has one location (no change)

Current flow works as-is. Single Google Place ID → single Location → single integration.

#### Scenario B: Customer has multiple locations, same platform

**Jobber (franchise):**
1. Provision creates multiple Locations (one per Google Place ID) — already supported
2. User connects Jobber for each location separately via the Integrations page
3. Each connection creates a `NangoConnection` + `LocationIntegration` linking it to the correct Location
4. Frontend needs a "Connect Jobber for [Location Name]" flow instead of a single "Connect Jobber" button

**HCP (multi-location):**
1. Provision creates multiple Locations — already supported
2. User connects HCP once (single API key) → creates one `OrganizationIntegration`
3. System calls `GET /company` to fetch HCP location list
4. User maps each HCP location to a CallSaver Location (UI needed)
5. System creates `LocationIntegration` records with `externalLocationId` for each mapping

#### Scenario C: Customer has multiple locations, different platforms

e.g., Location A uses Jobber, Location B uses HCP. This is already architecturally supported since integrations are per-org and the adapter registry resolves per-location. With `LocationIntegration`, each location explicitly declares its platform.

### 4.6 Frontend Changes

#### Integrations Page

Currently shows a flat list of integrations for the org. Needs to evolve:

**Single-location orgs (most customers):** No change — works as today.

**Multi-location orgs:**
1. Show which integration is connected to which location
2. For Jobber: "Connect Jobber" button per location (each triggers separate OAuth)
3. For HCP: "Connect Housecall Pro" once, then show location mapping UI
4. Location mapping UI: dropdown to match HCP locations to CallSaver locations

#### Settings/Config

The `autoScheduleAssessment` toggle (currently on `LivekitAgent.config`) should move to `LocationIntegration.config` since it's integration-specific, not agent-specific.

---

## 5. Migration Path

### Phase 1: Foundation (do now, minimal disruption)

1. **Populate `Location.externalPlatformId`** for existing Jobber connections
   - Query Jobber API for account ID, store on Location
2. **Create `LocationIntegration` migration** (new table)
3. **Backfill `LocationIntegration`** records from existing `NangoConnection` + `OrganizationIntegration` records
4. **Update `FieldServiceAdapterRegistry`** to check `LocationIntegration` first, fall back to org-level

### Phase 2: HCP Multi-Location Support

1. **Add `X-Company-Id` support** to HCP adapter
2. **Add HCP location discovery** endpoint: `GET /internal/hcp-locations` that calls HCP's `GET /company`
3. **Build location mapping UI** in frontend
4. **Store mappings** as `LocationIntegration` records with `externalLocationId`

### Phase 3: Jobber Multi-Location (Franchise) Support

1. **Update Integrations page** to support per-location Jobber connections
2. **Update Nango OAuth flow** to accept a `locationId` parameter
3. **Create `LocationIntegration`** record when OAuth completes, linked to specific Location
4. **Test with Jobber Central** accounts (need franchise test account)

### Phase 4: Provisioning Enhancements

1. **Auto-detect platform** during provisioning if customer's Attio record indicates they use Jobber/HCP
2. **Pre-create `LocationIntegration`** stubs during provisioning (status: `pending_connection`)
3. **Guided onboarding**: After provisioning, prompt user to connect their field service platform per location

---

## 6. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Jobber Central has no public API | Can't aggregate across franchise locations from one token | Accept per-location OAuth; monitor Jobber API roadmap |
| HCP location mapping is manual | User error in mapping locations | Auto-match by address/name similarity; show confirmation |
| Breaking existing single-location customers | Regression | `LocationIntegration` lookup falls back to org-level; fully backward compatible |
| Nango doesn't support per-location OAuth state | Can't pass locationId through OAuth callback | Use Nango's `metadata` field on connection to store target locationId |
| Different service catalogs per location | Agent offers wrong services | `fs-get-services` already queries per-adapter (per-location); no change needed |

---

## 7. Data Model Summary (Target State)

```
Organization (1)
├── OrganizationIntegration (1 per platform) ← org-level credential store
├── NangoConnection (1+ per platform)        ← may be location-scoped
├── LocationIntegration (1 per location+platform) ← NEW: explicit mapping
│   ├── externalLocationId (HCP UUID / Jobber account ID)
│   ├── config { autoScheduleAssessment, ... }
│   └── links to NangoConnection OR OrganizationIntegration
├── Location (1+)
│   ├── Agent / LivekitAgent
│   ├── TwilioPhoneNumber
│   ├── externalPlatformId (denormalized from LocationIntegration)
│   └── services[] (from platform catalog when connected, else from enrichment)
└── OrganizationMember (1+)
    └── User
```

---

## 8. Immediate Action Items (Pre-Launch)

For launch with single-location customers, **no schema changes are required**. The current architecture works. However, these items prepare for multi-location:

1. **Start populating `Location.externalPlatformId`** when Jobber/HCP is connected
2. **Move `autoScheduleAssessment`** from `LivekitAgent.config` to a more appropriate place (either `Location.settings` or future `LocationIntegration.config`)
3. **Add `X-Company-Id` header support** to HCP adapter (even for single-location, it's good practice)
4. **Document the `LocationIntegration` schema** so it's ready to implement when the first multi-location customer signs up

---

## 9. Open Questions

1. **Jobber franchise test account**: Do we have access to a Jobber Central / franchise setup for testing? If not, we need to request one from Jobber's partner program.
2. **HCP OAuth timeline**: When do we become an official HCP partner? OAuth would simplify multi-location since user permissions are handled by HCP.
3. **ServiceTitan**: ServiceTitan also has multi-location (tenant) support. Should we include it in this plan? Their API uses tenant IDs similarly to HCP's `X-Company-Id`.
4. **Billing**: Should multi-location customers pay per-location or per-organization? This affects how we structure Stripe subscriptions.
5. **Service catalog override**: When Jobber/HCP is connected, should the platform's service catalog completely replace `Location.services[]`, or merge with it? Currently the system prompt uses `Location.services[]` from enrichment, but `fs-get-services` queries the platform directly.
