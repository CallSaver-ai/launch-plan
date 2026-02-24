# Multi-Vertical Architecture Evolution — The $100M Plan

> **Date:** 2026-02-24
> **Status:** Strategic Planning
> **Scope:** How to evolve CallSaver from a field-service voice agent into a multi-vertical platform that replaces incumbent SaaS across 7+ industries

---

## 1. Current Architecture Audit

### What We Have Today

```
┌─────────────────────────────────────────────────────────┐
│                    FRONTEND (React)                      │
│  IntegrationsPage → integrations-config.ts (3 entries)  │
│  Pages: Dashboard, Callers, ServiceRequests, Appointments│
│  Sidebar: vertical-aware labels (Jobber→"Service Reqs") │
│  Hooks: useIntegrations, useServiceRequests              │
└─────────────────────────┬───────────────────────────────┘
                          │ REST
┌─────────────────────────▼───────────────────────────────┐
│                   NODE API (server.ts)                    │
│  ~9500 lines, monolithic                                 │
│                                                          │
│  Agent Config: GET /internal/agent-config                │
│    → detects platform (Jobber/HCP/GCal)                  │
│    → generates system prompt with fsInstructions         │
│    → returns tool_names[] array                          │
│                                                          │
│  Tool Routes: /internal/tools/fs/{endpoint}              │
│    → field-service-tools.ts (1565 lines, 25+ endpoints) │
│    → calls adapter.method() per platform                 │
│                                                          │
│  Adapters: src/adapters/                                 │
│    field-service/ ← PRODUCTION (Jobber, HCP)             │
│    law/           ← SCAFFOLDED (Lawmatics, Clio)         │
│    hospitality/   ← SCAFFOLDED (Mews, Apaleo, Alice)    │
│    wellness/      ← SCAFFOLDED (Vagaro, MindBody, Blvd)  │
│    restaurant/    ← SCAFFOLDED (Toast)                   │
└─────────────────────────┬───────────────────────────────┘
                          │ httpx POST
┌─────────────────────────▼───────────────────────────────┐
│              PYTHON AGENT (livekit-python)                │
│                                                          │
│  callsaver_agent.py → CallSaverAgent(Agent)              │
│  tools/__init__.py → register_tools() big if/elif chain  │
│  tools/fs_helpers.py → call_fs_endpoint() generic caller │
│  tools/fs_*.py → 26 field-service tool files             │
│  tools/google_calendar_*.py → 5 calendar tools           │
│  api_client.py → call start/end/transfer/upload          │
│                                                          │
│  Pattern: tool → httpx POST → Node API → Adapter → API  │
└─────────────────────────────────────────────────────────┘
```

### Current Pattern Per Vertical (Field Service as Example)

Each vertical currently requires **6 parallel tracks** of code:

| Layer | Files | Pattern |
|---|---|---|
| **Types** | `src/types/field-service.ts` (654 lines) | Domain types: Customer, Job, Appointment, etc. |
| **Adapter Interface** | `src/adapters/field-service/FieldServiceAdapter.ts` | 34 abstract methods |
| **Base Adapter** | `BaseFieldServiceAdapter.ts` | Phone verification, common patterns |
| **Platform Adapters** | `platforms/jobber/JobberAdapter.ts` (4956 lines!) | Platform-specific API mapping |
| **Platform Clients** | `platforms/jobber/JobberClient.ts` (200 lines) | HTTP/GraphQL client |
| **Registry + Factory** | `Registry.ts` + `Factory.ts` | Platform detection + instantiation |
| **Tool Routes** | `routes/field-service-tools.ts` (1565 lines) | Express endpoints that call adapter |
| **Python Tools** | `tools/fs_*.py` (10 files) | LLM function tools that call Node API |
| **System Prompt** | `server.ts` fsInstructions block (~100 lines) | Voice agent instructions |
| **Frontend** | Pages, hooks, sidebar config | Dashboard UI |

**Duplication problem:** The law vertical already copy-pasted `BaseAdapter`, `CallerContext`, `phoneVerification`, the factory/registry pattern, and the error types. Hospitality and wellness did the same. **4 copies of CallerContext. 4 copies of BaseAdapter. 4 copies of phoneVerification.** This won't scale to 7+ verticals.

### Existing Scaffolding Inventory

| Vertical | Adapter Interface | Platforms Scaffolded | Methods | Types File | Production? |
|---|---|---|---|---|---|
| **Field Service** | FieldServiceAdapter (34 methods) | Jobber ✅, HCP ✅, SF ❌, ST ❌ | 34 | field-service.ts | **YES** |
| **Law** | LawAdapter (11 methods) | Lawmatics ❌, Clio ❌ | 11 | law.ts | Scaffolded |
| **Hospitality** | HospitalityAdapter | Mews ❌, Apaleo ❌, Alice ❌ | ~20 | hospitality.ts | Scaffolded |
| **Wellness** | WellnessAdapter | Vagaro ❌, MindBody ❌, Boulevard ❌ | ~18 | wellness.ts | Scaffolded |
| **Restaurant** | (unknown) | Toast ❌ | ? | ? | Scaffolded |
| **Booking** | (Google Calendar in server.ts) | GCal ✅ | ~5 | N/A (inline) | **YES** (inline) |
| **Automotive** | N/A | N/A | N/A | N/A | Not started |
| **Property Mgmt** | N/A | N/A | N/A | N/A | Not started |

---

## 2. The Core Problem: Vertical Sprawl

If we keep the current pattern, each new vertical adds:
- ~650 lines of types
- ~400 lines of adapter interface + base
- ~200 lines of factory + registry (copy-pasted)
- ~150 lines of error types + phone verification (copy-pasted)
- ~5000 lines per platform adapter
- ~1500 lines of tool routes
- ~500 lines of Python tool files
- ~100 lines of system prompt instructions

**7 verticals × 5 platforms each = 35 platform adapters.** At ~5000 lines each that's 175,000 lines of adapter code alone. This is not how you build a $100M company — it's how you build a maintenance nightmare.

---

## 3. Architecture Evolution: The Unified Core

### 3.1 Shared Kernel

**Step 1: Extract a shared core that ALL verticals inherit from.**

```
src/
  core/                              ← NEW: shared kernel
    BaseAdapter.ts                   ← ONE copy (auth, health, platform name)
    CallerContext.ts                  ← ONE copy (phone, timezone, business hours)
    BaseEntityAdapter.ts             ← Generic phone verification, customer match
    phoneVerification.ts             ← ONE copy
    errors.ts                        ← Unified error types with vertical-agnostic codes
    types/
      common.ts                      ← Address, DateRange, TimeSlot, Note, Tag, etc.
      customer.ts                    ← Generic Customer/Contact (shared across ALL verticals)
    registry/
      AdapterRegistry.ts             ← ONE generic registry (parameterized by vertical)
      AdapterFactory.ts              ← ONE generic factory
    tools/
      tool-route-builder.ts          ← Generic Express route generator from adapter interface
    prompts/
      prompt-builder.ts              ← Composable system prompt generation

  verticals/                         ← Replaces src/adapters/
    field-service/
      types.ts                       ← ONLY field-service-specific types (Job, Estimate, etc.)
      interface.ts                   ← FieldServiceAdapter extends core.BaseEntityAdapter
      platforms/
        jobber/
        housecallpro/
        servicefusion/
        callsaver-crm/               ← Our built-in CRM

    law/
      types.ts                       ← Lead, Matter, Consultation
      interface.ts                   ← LawAdapter extends core.BaseEntityAdapter
      platforms/
        lawmatics/
        clio/
        callsaver-crm/               ← Our built-in law CRM

    wellness/
      types.ts                       ← Service, Staff, Class, Package
      interface.ts
      platforms/
        vagaro/
        mindbody/
        boulevard/
        callsaver-crm/

    automotive/
      types.ts                       ← Vehicle, RepairOrder, ServiceAdvisor
      interface.ts
      platforms/
        tekmetric/
        shopmonkey/
        callsaver-crm/

    hospitality/
      types.ts                       ← Guest, Reservation, Room, Folio
      interface.ts
      platforms/
        mews/
        apaleo/
        callsaver-crm/

    property-management/
      types.ts                       ← Tenant, Unit, Lease, MaintenanceRequest
      interface.ts
      platforms/
        buildium/
        appfolio/
        callsaver-crm/

    booking/
      types.ts                       ← Booking, Calendar, TimeSlot
      interface.ts
      platforms/
        google-calendar/              ← Move from inline server.ts
        acuity/
        square/
        callsaver-crm/
```

### 3.2 Generic Registry (ONE Implementation)

```typescript
// src/core/registry/AdapterRegistry.ts

export class AdapterRegistry<TAdapter extends BaseAdapter> {
  private adapters: Map<string, TAdapter> = new Map();
  private prisma: PrismaClient;
  private vertical: VerticalType;
  private factory: AdapterFactory<TAdapter>;

  constructor(config: {
    prisma: PrismaClient;
    vertical: VerticalType;
    factory: AdapterFactory<TAdapter>;
  }) { ... }

  async getAdapter(locationId: string, platform?: string): Promise<TAdapter> {
    // Same logic as today, but generic:
    // 1. Look up platform from DB (IntegrationConnection or OrganizationIntegration)
    // 2. Check if 'callsaver-crm' is the fallback (no external integration)
    // 3. Build config (OAuth via Pipedream, API key, or local DB)
    // 4. Cache and return
  }
}

// Usage per vertical (ONE LINE each):
const fsRegistry = new AdapterRegistry<FieldServiceAdapter>({
  prisma, vertical: 'field-service', factory: fieldServiceFactory
});
const lawRegistry = new AdapterRegistry<LawAdapter>({
  prisma, vertical: 'law', factory: lawFactory
});
```

**Eliminates:** 5 copies of 300-line Registry files → 1 generic 300-line file.

### 3.3 Generic Tool Route Builder

The biggest single win. Today `field-service-tools.ts` is 1565 lines of repetitive Express routes. Each route follows the same pattern:

```typescript
// CURRENT (repeated 25+ times):
router.post('/get-customer-by-phone', async (req, res) => {
  const { locationId, callerPhoneNumber } = req.body;
  const adapter = await getAdapter(locationId);
  const locSettings = await getLocationSettings(locationId);
  const context = buildContext(callerPhoneNumber, locSettings);
  try {
    const customer = await adapter.findCustomerByPhone(context);
    return res.json({ customer });
  } catch (error) {
    return handleError(res, 'get-customer-by-phone', error);
  }
});
```

**New approach: declarative tool definitions.**

```typescript
// src/core/tools/tool-route-builder.ts

interface ToolDefinition {
  name: string;                     // 'get-customer-by-phone'
  method: string;                   // 'findCustomerByPhone'
  params: ParamDef[];               // [{ name: 'customerId', from: 'body' }]
  responseMapper?: (result: any, tz: string) => any;  // Optional transform
}

function buildToolRoutes<T extends BaseAdapter>(
  vertical: string,
  registry: AdapterRegistry<T>,
  tools: ToolDefinition[],
): Router {
  const router = Router();
  for (const tool of tools) {
    router.post(`/${tool.name}`, async (req, res) => {
      // Generic: get adapter, build context, call method, handle errors
    });
  }
  return router;
}

// field-service tools become a config array:
export const FIELD_SERVICE_TOOLS: ToolDefinition[] = [
  { name: 'get-customer-by-phone', method: 'findCustomerByPhone', params: [] },
  { name: 'create-customer', method: 'createCustomer', params: [
    { name: 'firstName', from: 'body' },
    { name: 'lastName', from: 'body' },
    { name: 'email', from: 'body', optional: true },
  ]},
  // ... 32 more
];
```

**Eliminates:** 1565 lines → ~100 lines of tool definitions + ~200 lines of generic builder.

### 3.4 Generic Python Tool Generator

Same principle for the Python agent side. Today: 10 `fs_*.py` files, each with the same httpx POST pattern. A giant if/elif chain in `__init__.py`.

**New approach:**

```python
# tools/vertical_tools.py — ONE generic file

class VerticalTool:
    """Generic tool that calls /internal/tools/{vertical}/{endpoint}."""
    def __init__(self, vertical: str, name: str, endpoint: str, 
                 description: str, params: list[ToolParam]):
        self.vertical = vertical
        self.endpoint = endpoint
        ...

    def create_function_tool(self, context: ToolContext):
        """Returns a @function_tool decorated callable."""
        ...

# tools/definitions/field_service.py — just data
FIELD_SERVICE_TOOLS = [
    VerticalTool('fs', 'fs_get_customer_by_phone', 'get-customer-by-phone',
                 'Look up customer by phone number', []),
    VerticalTool('fs', 'fs_create_customer', 'create-customer',
                 'Create a new customer', [
                     ToolParam('first_name', str, 'Customer first name'),
                     ToolParam('last_name', str, 'Customer last name'),
                 ]),
    ...
]

# tools/__init__.py — register by vertical prefix
async def register_tools(tool_names, context):
    tools = {}
    for name in tool_names:
        prefix = name.split('-')[0]  # 'fs', 'law', 'well', 'auto', etc.
        defn = TOOL_REGISTRY.get(name)
        if defn:
            tools[name] = defn.create_function_tool(context)
    return tools
```

**Eliminates:** 10+ tool files per vertical → 1 definitions file per vertical (~50 lines each).

### 3.5 Composable System Prompt Builder

Today system prompts are generated inline in `server.ts` with platform-specific if/else blocks. For multi-vertical this needs to be composable.

```typescript
// src/core/prompts/prompt-builder.ts

interface VerticalPromptConfig {
  vertical: VerticalType;
  platformName: string;
  terminology: Record<string, string>;  // { 'Customer': 'Client', 'Job': 'Request' }
  workflows: PromptSection[];           // Ordered workflow steps
  toolPrefix: string;                   // 'fs', 'law', 'well', 'auto'
  features: {
    hasServiceArea: boolean;
    hasAssessments: boolean;
    hasEstimates: boolean;
    autoSchedule: boolean;
    // ...
  };
}

function buildVerticalPrompt(config: VerticalPromptConfig): string {
  // Generates the full vertical-specific instruction block
  // using composable templates instead of hardcoded strings
}
```

### 3.6 The Vertical Type System on Organization

Today the vertical is implicit — detected from which integration is connected. This needs to be explicit:

```prisma
model Organization {
  // ... existing fields ...
  vertical        String?   @default("field-service")
  // "field-service" | "law" | "wellness" | "automotive" |
  // "hospitality" | "property-management" | "booking" | "restaurant"
}
```

This drives:
- Which adapter registry to use
- Which tool routes to mount
- Which Python tools to register
- Which system prompt template to use
- Which frontend pages/terminology to show
- Which built-in CRM schema to activate

---

## 4. Customer Assets Model

For automotive, HVAC, and any business that services physical assets:

```prisma
model CrmAsset {
  id               String       @id @default(cuid())
  organizationId   String       @map("organization_id")
  customerId       String       @map("customer_id")
  propertyId       String?      @map("property_id")  // Optional link to service location

  // Identity
  name             String                              // "2019 Toyota Camry", "Carrier AC Unit"
  assetType        String       @map("asset_type")     // "vehicle", "equipment", "appliance", "system"
  category         String?                              // "HVAC", "Plumbing", "Automotive", "Electrical"

  // Common fields
  make             String?                              // "Toyota", "Carrier", "Rheem"
  model            String?                              // "Camry", "24ACC636A003", "RTG-84DVN"
  year             Int?
  serialNumber     String?      @map("serial_number")
  
  // Vehicle-specific
  vin              String?                              // Vehicle Identification Number
  licensePlate     String?      @map("license_plate")
  mileage          Int?                                 // Last recorded mileage
  color            String?
  engine           String?                              // "2.5L 4-cylinder"
  transmission     String?                              // "automatic", "manual"
  fuelType         String?      @map("fuel_type")       // "gasoline", "diesel", "electric", "hybrid"

  // Equipment-specific
  installDate      DateTime?    @map("install_date")
  warrantyExpiry   DateTime?    @map("warranty_expiry")
  location         String?                              // "Basement", "Roof", "Garage bay 3"
  capacity         String?                              // "3 ton", "50 gallon", "200 amp"

  // Metadata
  notes            String?
  tags             String[]     @default([])
  customFields     Json?        @map("custom_fields")   // Flexible key-value for industry-specific data
  photoUrls        String[]     @default([]) @map("photo_urls")

  // Status
  status           String       @default("active")      // active, inactive, retired, sold
  condition        String?                               // excellent, good, fair, poor

  createdAt        DateTime     @default(now()) @map("created_at")
  updatedAt        DateTime     @updatedAt @map("updated_at")
  deletedAt        DateTime?    @map("deleted_at")

  // Relations
  organization     Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  customer         CrmCustomer  @relation(fields: [customerId], references: [id], onDelete: Cascade)
  property         CrmProperty? @relation(fields: [propertyId], references: [id])
  serviceHistory   CrmAssetServiceRecord[]

  @@index([organizationId])
  @@index([customerId])
  @@index([vin])
  @@index([serialNumber, organizationId])
  @@index([assetType, organizationId])
  @@map("crm_assets")
}

model CrmAssetServiceRecord {
  id            String    @id @default(cuid())
  assetId       String    @map("asset_id")
  jobId         String?   @map("job_id")

  // Service details
  serviceDate   DateTime  @map("service_date")
  serviceType   String    @map("service_type")    // "oil change", "filter replacement", "inspection"
  description   String?
  mileageAt     Int?      @map("mileage_at")      // Mileage at time of service (vehicles)
  technicianId  String?   @map("technician_id")

  // Parts/materials
  partsUsed     Json?     @map("parts_used")       // [{ name, partNumber, qty, cost }]
  laborHours    Decimal?  @map("labor_hours") @db.Decimal(5, 2)

  createdAt     DateTime  @default(now()) @map("created_at")

  asset         CrmAsset  @relation(fields: [assetId], references: [id], onDelete: Cascade)
  job           CrmJob?   @relation(fields: [jobId], references: [id])

  @@index([assetId])
  @@index([serviceDate])
  @@map("crm_asset_service_records")
}
```

### How Assets Work Across Verticals

| Vertical | Asset Type | Example | Key Fields |
|---|---|---|---|
| **Automotive** | vehicle | 2019 Toyota Camry | VIN, mileage, licensePlate, engine, transmission |
| **HVAC** | equipment | Carrier 24ACC636A003 | serialNumber, installDate, warrantyExpiry, capacity, location |
| **Plumbing** | system | Rheem RTG-84DVN water heater | serialNumber, installDate, warrantyExpiry, location |
| **Electrical** | system | 200A main panel | capacity, installDate, location |
| **Appliance Repair** | appliance | Samsung RF28R7351SG refrigerator | make, model, serialNumber, warrantyExpiry |
| **Pool Service** | equipment | Pentair IntelliFlo pump | serialNumber, installDate, capacity |

The `customFields` JSON and `tags` array handle industry-specific data without schema changes.

### Voice Agent Asset Workflow

```
Caller: "I need an oil change for my Toyota Camry"
Agent: → fs_get_customer_by_phone (finds customer)
       → fs_get_customer_assets (finds 2019 Camry, VIN, last service 3mo ago at 45,000mi)
       → "I see your 2019 Toyota Camry. Your last oil change was 3 months ago at 45,000 miles.
          Would you like to schedule another one?"
```

New adapter methods for assets:

```typescript
// Added to FieldServiceAdapter (or any vertical adapter)
getCustomerAssets(context: CallerContext, customerId: string): Promise<Asset[]>;
getAsset(context: CallerContext, assetId: string): Promise<Asset>;
createAsset(context: CallerContext, data: CreateAssetInput): Promise<Asset>;
updateAsset(context: CallerContext, assetId: string, data: UpdateAssetInput): Promise<Asset>;
```

---

## 5. Vertical Expansion Playbook

### Phase 0: Core Extraction (Pre-Requisite) — 12-16 hours

Before adding ANY new vertical:

1. **Extract `src/core/`** from field-service code
   - Move shared types (Address, DateRange, TimeSlot, CallerContext) to `core/types/`
   - Create `core/BaseAdapter.ts` (single source of truth)
   - Create `core/phoneVerification.ts` (single copy)
   - Create `core/errors.ts` (unified error types)

2. **Build generic AdapterRegistry** — parameterized by vertical
3. **Build generic tool-route-builder** — declarative tool definitions
4. **Build generic Python tool generator** — data-driven instead of file-per-tool
5. **Add `vertical` column to Organization** (migration)
6. **Refactor field-service to use new core** — prove the pattern works

### Phase 1: Field Service Completion — 24-31 hours (already planned)

- CallSaver CRM adapter (built-in thin CRM)
- Service Fusion adapter
- Asset management (CrmAsset model)
- Auto-activate CRM for non-integrated orgs

### Phase 2: Legal — 23-34 hours (already planned)

- Lawmatics + Clio adapters
- Legal-specific CRM tables (Matter, Consultation, PracticeArea)
- Python law_*.py tools (8 tools)
- Legal system prompt
- Frontend terminology switching

### Phase 3: Booking (Generalized) — 10-14 hours

- Extract Google Calendar from inline server.ts → proper adapter
- Add Acuity, Square Bookings adapters
- BookingAdapter interface: ~8 methods (checkAvailability, createBooking, getBookings, updateBooking, cancelBooking, getServices, getStaff, getLocations)
- This vertical serves ANY business that just needs appointment scheduling

### Phase 4: Wellness — 16-20 hours

- Vagaro, MindBody, Boulevard adapters (already scaffolded!)
- WellnessAdapter: ~18 methods (client, appointment, service, staff, class, package)
- Wellness-specific: packages, memberships, class schedules, intake forms

### Phase 5: Automotive — 14-18 hours

- Tekmetric, Shopmonkey adapters
- AutomotiveAdapter: ~16 methods (customer, vehicle, repair order, appointment, estimate, service advisor)
- Vehicle-centric: VIN lookup, service history, recall checking
- Heavy asset usage (CrmAsset with vehicle fields)

### Phase 6: Hospitality — 16-20 hours

- Mews, Apaleo adapters (already scaffolded!)
- HospitalityAdapter: ~20 methods (guest, reservation, room, service request, menu, folio)
- Hotel-specific: room types, availability, concierge requests, restaurant orders

### Phase 7: Property Management — 14-18 hours

- Buildium, AppFolio adapters
- PropertyMgmtAdapter: ~14 methods (tenant, unit, lease, maintenance request, amenity booking)
- PM-specific: lease lookup, rent status, maintenance scheduling, move-in/move-out

### Each Phase Follows the Same Checklist

```
□ types/{vertical}.ts — domain types
□ verticals/{vertical}/interface.ts — adapter interface
□ verticals/{vertical}/platforms/{platform}/Client.ts
□ verticals/{vertical}/platforms/{platform}/Adapter.ts
□ verticals/{vertical}/platforms/callsaver-crm/Adapter.ts — built-in CRM
□ verticals/{vertical}/tool-definitions.ts — declarative tool config
□ tools/definitions/{vertical}.py — Python tool definitions
□ server.ts: prompt-builder config for vertical
□ integrations-config.ts: add platform entries
□ Frontend: vertical-aware terminology + pages
□ Test script: testing/test-{vertical}-integration.sh
```

---

## 6. Database Architecture Evolution

### Current Schema Issues

1. **`Organization` has no vertical indicator** — vertical is inferred from which integration is connected
2. **`Service` model is field-service-specific** — needs to generalize
3. **`Appointment` model is GCal-specific** — lives alongside field-service appointments
4. **`Caller` vs `CrmCustomer`** — two customer concepts that need clean bridging
5. **`Location.services`** — JSON blob used for voice agent service catalog, not typed

### Target Schema

```
Organization
  ├── vertical: "field-service" | "law" | "wellness" | "automotive" | ...
  ├── Location (multi-location support, already exists)
  │     ├── timezone, businessHours, serviceAreas (already exist)
  │     └── Agent (voice agent config, already exists)
  │
  ├── IntegrationConnection (OAuth, already exists)
  ├── OrganizationIntegration (API key, already exists)
  │
  ├── [Vertical-specific CRM tables]
  │     Field Service: CrmCustomer, CrmProperty, CrmJob, CrmAppointment, ...
  │     Law: CrmContact, CrmMatter, CrmConsultation, ...
  │     Automotive: CrmCustomer (shared), CrmAsset (vehicles), CrmRepairOrder, ...
  │     Wellness: CrmClient, CrmService, CrmPackage, CrmAppointment, ...
  │
  └── [Shared CRM tables]
        CrmNote, CrmTag, CrmSource, CrmSequence, CrmAsset
```

### Key Principle: Share Customer, Specialize Domain

The `CrmCustomer` + `CrmContact` + `CrmPhone` + `CrmEmail` models are **shared across ALL verticals**. Every business has customers with contact info. The domain-specific tables (Job, Matter, RepairOrder, Reservation) are what differ.

```
SHARED (all verticals):        FIELD-SERVICE SPECIFIC:
  CrmCustomer                    CrmProperty
  CrmContact                    CrmServiceRequest
  CrmPhone                      CrmJob
  CrmEmail                      CrmAppointment
  CrmNote                       CrmEstimate
  CrmTag                        CrmEstimateLineItem
  CrmSource
  CrmSequence                  AUTOMOTIVE SPECIFIC:
  CrmAsset                       CrmRepairOrder
  CrmAssetServiceRecord          CrmServiceAdvisor

                               LAW SPECIFIC:
                                 CrmMatter
                                 CrmConsultation
                                 CrmPracticeArea

                               WELLNESS SPECIFIC:
                                 CrmWellnessService
                                 CrmPackage
                                 CrmMembership
                                 CrmClass

                               HOSPITALITY SPECIFIC:
                                 CrmReservation
                                 CrmRoom
                                 CrmFolio
```

---

## 7. Python Agent Architecture Evolution

### Current Pain Points

1. **`tools/__init__.py`** — 191-line if/elif chain that grows linearly with every tool
2. **10 `fs_*.py` files** — each repeats the same httpx POST pattern
3. **`fs_helpers.py`** — hardcodes `/internal/tools/fs/` prefix
4. **`callsaver_agent.py`** — no vertical awareness

### Target Architecture

```
livekit-python/
  callsaver_agent.py              ← Vertical-aware agent
  api_client.py                   ← Unchanged
  tools/
    __init__.py                   ← Generic registry (reads tool definitions)
    base_tool.py                  ← VerticalTool class (generic httpx caller)
    definitions/
      field_service.py            ← ToolDefinition list (data, not code)
      law.py
      wellness.py
      automotive.py
      hospitality.py
      property_management.py
      booking.py
      common.py                   ← validate-address, request-callback, etc.
    transfer_call.py              ← Keep: SIP-specific, not HTTP-based
    warm_transfer.py              ← Keep: SIP-specific
```

**Key change:** `base_tool.py` provides a generic `VerticalTool` class. Each `definitions/*.py` is a list of tool definitions (name, endpoint, description, parameters). The `__init__.py` `register_tools()` function reads these definitions instead of a giant if/elif.

### Effort: ~4-6 hours (one-time refactor)

---

## 8. Frontend Architecture Evolution

### Current State

The frontend is already somewhat vertical-aware:
- `app-sidebar.tsx` switches labels based on `useIntegrations()` 
- `ServiceRequestsPage.tsx` renders "Leads" for HCP, "Service Requests" for Jobber
- `integrations-config.ts` has 3 entries (GCal, Jobber, HCP)

### Target: Vertical-Driven UI Config

```typescript
// src/lib/vertical-config.ts

interface VerticalUIConfig {
  vertical: VerticalType;
  displayName: string;           // "Field Service", "Legal", "Automotive"
  terminology: {
    customer: string;            // "Customer", "Client", "Contact", "Patient"
    appointment: string;         // "Appointment", "Visit", "Consultation", "Session"
    serviceRequest: string;      // "Service Request", "Lead", "Case", "Repair Order"
    service: string;             // "Service", "Practice Area", "Treatment", "Repair"
    job: string;                 // "Job", "Matter", "Repair Order", "Reservation"
  };
  pages: {
    showServiceRequests: boolean;
    showJobs: boolean;
    showEstimates: boolean;
    showAssets: boolean;
    showProperties: boolean;
  };
  integrations: IntegrationConfig[];
  servicePresets: ServicePreset[];
  sidebarItems: SidebarItem[];
}

const VERTICAL_CONFIGS: Record<VerticalType, VerticalUIConfig> = {
  'field-service': {
    displayName: 'Field Service',
    terminology: { customer: 'Customer', appointment: 'Appointment', ... },
    pages: { showServiceRequests: true, showJobs: true, showEstimates: true, showAssets: true, showProperties: true },
    integrations: [JOBBER_CONFIG, HCP_CONFIG, SERVICE_FUSION_CONFIG],
    ...
  },
  'law': {
    displayName: 'Legal',
    terminology: { customer: 'Contact', appointment: 'Consultation', serviceRequest: 'Case', ... },
    pages: { showServiceRequests: false, showJobs: false, showEstimates: false, showAssets: false, showProperties: false },
    integrations: [LAWMATICS_CONFIG, CLIO_CONFIG],
    ...
  },
  'automotive': {
    displayName: 'Automotive',
    terminology: { customer: 'Customer', appointment: 'Appointment', serviceRequest: 'Repair Order', service: 'Service', job: 'Repair Order' },
    pages: { showServiceRequests: true, showJobs: true, showEstimates: true, showAssets: true, showProperties: false },
    integrations: [TEKMETRIC_CONFIG, SHOPMONKEY_CONFIG],
    ...
  },
  // ...
};
```

**The entire frontend adapts to the vertical via ONE config object.** No per-vertical pages or components needed — just terminology switching and show/hide flags.

### Effort: ~6-8 hours (one-time refactor + config per vertical)

---

## 9. Migration Strategy: Integration → Replacement

### Year 1: Voice Agent Integration Layer (Current)

**"We integrate with your existing software"**
- Phase: Build adapters for each vertical's top 2-3 platforms
- Value prop: AI receptionist that syncs with your existing tools
- Revenue: Subscription ($49-199/mo based on call volume)

### Year 2: Built-In CRM (Next)

**"Use our tools instead — they're free and they work better"**
- Phase: Build CallSaver CRM adapters for each vertical
- Auto-activate for businesses without external integrations
- Value prop: AI receptionist + free CRM, no setup required
- Revenue: Subscription (same) + upsell to premium CRM features

### Year 3: Platform Replacement

**"Why pay $150/mo for Jobber when our CRM does everything you need?"**
- Phase: Feature-expand CRM to cover 80% of incumbent functionality
- Add: team management, basic reporting, mobile web app
- Do NOT add: invoicing, payments, inventory, complex dispatching
- Value prop: AI-native platform that was built for how modern businesses work
- Revenue: Subscription + premium features + data insights

### Year 4: Multi-Vertical Marketplace

**"The AI-native operating system for service businesses"**
- Potential rebrand from CallSaver to something broader
- Cross-vertical features: multi-location, franchise management
- Data moat: call analytics, demand patterns, pricing intelligence
- Revenue: Platform fees + marketplace commissions + data products

---

## 10. Effort Summary

### Core Infrastructure (One-Time)

| Work | Hours | When |
|---|---|---|
| Extract shared kernel (`src/core/`) | 8-10 | Before Phase 2 |
| Generic AdapterRegistry + Factory | 4-6 | Before Phase 2 |
| Generic tool-route-builder | 6-8 | Before Phase 2 |
| Generic Python tool generator | 4-6 | Before Phase 2 |
| Composable prompt builder | 4-6 | Before Phase 2 |
| Frontend vertical-config system | 6-8 | Before Phase 2 |
| Add `vertical` column + migration | 2-3 | Before Phase 2 |
| CrmAsset model + migration | 3-4 | Phase 1 |
| **Subtotal** | **37-51** | |

### Per-Vertical (After Core)

With the generic infrastructure, each new vertical requires:

| Work | Hours |
|---|---|
| Types + adapter interface | 3-4 |
| Per platform adapter (~2-3 platforms) | 8-15 |
| Built-in CRM adapter | 4-6 |
| Tool definitions (Node + Python) | 2-3 |
| Prompt config | 1-2 |
| Frontend config + terminology | 2-3 |
| Integration page entries | 1-2 |
| Testing | 3-4 |
| **Per-vertical total** | **24-39** |

### Full Roadmap

| Phase | Vertical | Platforms | Hours | Target |
|---|---|---|---|---|
| **0** | Core extraction | — | 37-51 | Q1 2026 |
| **1** | Field Service (complete) | SF, CRM, Assets | 24-31 | Q1 2026 |
| **2** | Legal | Lawmatics, Clio | 23-34 | Q2 2026 |
| **3** | Booking (generalized) | GCal, Acuity, Square | 10-14 | Q2 2026 |
| **4** | Wellness | Vagaro, MindBody, Boulevard | 24-39 | Q2-Q3 2026 |
| **5** | Automotive | Tekmetric, Shopmonkey | 24-39 | Q3 2026 |
| **6** | Hospitality | Mews, Apaleo | 24-39 | Q3-Q4 2026 |
| **7** | Property Mgmt | Buildium, AppFolio | 24-39 | Q4 2026 |
| **Total** | **7 verticals** | **~20 platforms** | **190-286** | **12 months** |

At ~40hrs/week that's **5-7 months of focused development** for a solo developer, or **2-3 months** with 2-3 engineers.

---

## 11. What NOT to Change Right Now

The following things work well and should NOT be disrupted:

1. **server.ts monolith** — Yes it's 9500 lines, but it works. Don't split it until the pain is real.
2. **Prisma ORM** — Perfect for our scale. Don't switch to anything else.
3. **LiveKit + Python agent** — The voice agent architecture is solid. Just make tools data-driven.
4. **Express.js** — No reason to switch frameworks.
5. **React frontend** — The SPA pattern with hooks works well.
6. **ECS deployment** — Infrastructure is fine.
7. **Existing Jobber/HCP adapters** — They're battle-tested. Refactor to use core, don't rewrite.

### The Minimum Viable Architecture Change

If you want to move fast, the **absolute minimum** before adding vertical #2 (Legal):

1. Add `vertical` column to Organization (**1 hour**)
2. Extract shared `CallerContext` + `BaseAdapter` + `phoneVerification` to `src/core/` (**3 hours**)
3. Have law adapter import from core instead of copy-pasting (**1 hour**)
4. Add `law-tools.ts` route file (yes, separate file for now — skip generic builder) (**4 hours**)
5. Add Python `tools/definitions/law.py` + modify `__init__.py` to handle `law-` prefix (**2 hours**)

**Total minimum: ~11 hours** to cleanly add Legal without the full generic infrastructure. The full refactor to generic patterns can happen after 2-3 verticals prove the model.

---

## 12. The $100M Equation

| Metric | Conservative | Aggressive |
|---|---|---|
| **Verticals** | 4 (FS, Legal, Wellness, Auto) | 7+ |
| **Platforms per vertical** | 2-3 external + 1 CRM | 3-5 external + 1 CRM |
| **Total addressable SMBs** | ~2M (US) | ~5M (US + international) |
| **Penetration rate** | 0.1% (2,000 customers) | 0.5% (25,000 customers) |
| **ARPU** | $100/mo | $150/mo |
| **ARR** | **$2.4M** | **$45M** |
| **With CRM upsell (2x ARPU)** | **$4.8M** | **$90M** |
| **With data products (1.5x)** | **$7.2M** | **$135M** |

The $100M path requires:
1. **4+ verticals** with CRM replacement capability
2. **10,000+ paying customers** at ~$100/mo ARPU
3. **CRM upsell** that doubles ARPU for ~50% of customers
4. **Data products** (demand intelligence, pricing benchmarks) as additional revenue

The technical architecture outlined above supports all of this with a team of 3-5 engineers.
