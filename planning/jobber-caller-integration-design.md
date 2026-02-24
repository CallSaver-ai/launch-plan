# Jobber ↔ Caller/CallRecord Integration Design

## Status Quo: What Happens Today

### Call Lifecycle (Jobber-connected location)

1. **Call starts** → `POST /internal/call-records/start`
   - Creates a `Caller` record (phone number only — no name, no address)
   - Creates a `CallRecord` linked to that Caller via `callerId`
   - ✅ Caller and CallRecord **are** created for Jobber calls

2. **During the call** — agent uses `fs_*` tools:
   - `fs_create_customer` → creates a **Jobber Client** (name, phone)
   - `fs_create_property` → creates a **Jobber Property** (address)
   - `fs_create_service_request` → creates a **Jobber Request + Assessment**
   - ❌ None of these update the local `Caller` or `CallerAddress` records

3. **Call ends** → `POST /internal/call-records/end` + summarization queue
   - Updates `CallRecord` with transcript, summary, success evaluation
   - Ensures `Caller` exists (phone-only upsert)
   - ❌ **Name/address extraction was intentionally removed** from the summarization worker
   - Comment in `queues.ts:297`: _"Name/email/address extraction was removed — submit-intake-answers is the source of truth"_
   - But `submit_intake_answers` is **excluded** for Jobber/HCP integrations

### The Gap

| Data | Where it lives | Local Caller record |
|------|----------------|-------------------|
| Phone number | Caller.phoneNumber ✅ | ✅ Populated at call start |
| First/Last name | Jobber Client only | ❌ Empty |
| Email | Jobber Client only | ❌ Empty |
| Address | Jobber Property only | ❌ No CallerAddress created |
| Service request | Jobber Request only | ❌ No local equivalent |
| Assessment | Jobber Assessment only | ❌ No local equivalent |

**Result**: The Callers page in the dashboard shows phone numbers with no names, no addresses, and no context beyond the call summary.

---

## Proposed Solution

### Phase 1: Backfill Caller from fs_create_customer (Backend — Quick Win)

When `fs_create_customer` succeeds, update the local `Caller` record with the name.

**File**: `src/routes/field-service-tools.ts` — `create-customer` endpoint

```typescript
// After successful fs_create_customer, sync name to local Caller
if (customer.firstName || customer.lastName) {
  const normalizedPhone = normalizeToE164(callerPhoneNumber);
  if (normalizedPhone) {
    const location = await prisma.location.findUnique({
      where: { id: locationId },
      select: { organizationId: true },
    });
    if (location) {
      await prisma.caller.upsert({
        where: {
          phoneNumber_organizationId: {
            phoneNumber: normalizedPhone,
            organizationId: location.organizationId,
          },
        },
        update: {
          firstName: customer.firstName || undefined,
          lastName: customer.lastName || undefined,
          name: [customer.firstName, customer.lastName].filter(Boolean).join(' ') || undefined,
        },
        create: {
          phoneNumber: normalizedPhone,
          organizationId: location.organizationId,
          locationId,
          firstName: customer.firstName || undefined,
          lastName: customer.lastName || undefined,
          name: [customer.firstName, customer.lastName].filter(Boolean).join(' ') || undefined,
        },
      });
    }
  }
}
```

### Phase 2: Backfill CallerAddress from fs_create_property (Backend — Quick Win)

When `fs_create_property` succeeds, create a `CallerAddress` record.

**File**: `src/routes/field-service-tools.ts` — `create-property` endpoint

```typescript
// After successful fs_create_property, sync address to local CallerAddress
if (address && callerId) {
  const fullAddress = [address.street, address.city, address.state, address.zip]
    .filter(Boolean).join(', ');
  if (fullAddress) {
    await prisma.callerAddress.upsert({
      where: { callerId_address: { callerId, address: fullAddress } },
      update: {},
      create: {
        callerId,
        address: fullAddress,
        city: address.city || null,
        state: address.state || null,
        zipCode: address.zip || null,
        isPrimary: true,
      },
    });
  }
}
```

### Phase 3: Store Jobber Client ID on Caller (Backend — Link)

Add an `externalCustomerId` field to the `Caller` model to link to the Jobber Client.

**Migration**:
```sql
ALTER TABLE callers ADD COLUMN external_customer_id TEXT;
ALTER TABLE callers ADD COLUMN external_platform TEXT; -- 'jobber' | 'housecall-pro'
CREATE INDEX idx_callers_external_customer ON callers(external_customer_id, external_platform);
```

**Prisma schema addition**:
```prisma
model Caller {
  // ... existing fields ...
  externalCustomerId  String?  @map("external_customer_id")
  externalPlatform    String?  @map("external_platform")  // 'jobber' | 'housecall-pro'
}
```

**Set on create-customer**:
```typescript
await prisma.caller.upsert({
  // ...
  update: {
    externalCustomerId: customer.id,  // Jobber EncodedId
    externalPlatform: 'jobber',
    // ... name fields
  },
  create: {
    externalCustomerId: customer.id,
    externalPlatform: 'jobber',
    // ... other fields
  },
});
```

This enables:
- Dashboard can show "View in Jobber" link
- Future: fetch live data from Jobber for a Caller detail page
- Deduplication: if same phone calls again, we know their Jobber Client ID

### Phase 4: Frontend Adaptation (CallSaver-Sourced Only)

#### Product Decision: Option A — CallSaver-Sourced Data Only

The dashboard shows **only data that originated from CallSaver calls**, not all Jobber data. Rationale:

- **CallSaver's value prop** is "here's what your AI agent did for you" — the dashboard answers: *How many leads did my agent capture? What did callers ask for? Were they scheduled?*
- **Jobber is already the system of record** for all clients/jobs/invoices. We don't replicate it.
- **No extra API calls** on page load — local Caller/CallRecord data is fast.
- **No scope creep** — we'd otherwise be rebuilding Jobber's UI (pagination, search, filtering across thousands of records).

#### 4a. Sidebar Menu Changes

When a Jobber integration is connected, rename "Callers" to "Clients" but do NOT add Requests/Schedule pages:

| Current | Jobber-Connected |
|---------|------------------|
| Callers | Clients |
| Call History | Call History (unchanged) |

```tsx
const isJobberConnected = activeIntegration?.type === 'jobber';
const menuItems = [
  { label: isJobberConnected ? 'Clients' : 'Callers', path: '/callers', icon: Users },
  { label: 'Call History', path: '/calls', icon: Phone },
];
```

#### 4b. Callers/Clients Page — Local Data + "View in Jobber" Link

**Data source**: Local `Caller` records only (populated by Phase 1-2 sync). These have:
- Name (from `fs_create_customer` sync)
- Address (from `fs_create_property` sync)
- Call history, summaries, call count, last-called timestamps

**Jobber linking** (Phase 3): When `externalCustomerId` is set, show a **"View in Jobber"** button that opens the client in Jobber's dashboard. No need to fetch/display Jobber data in our UI.

```
GET /me/callers → List (local Caller records, fast, no Jobber API calls)
```

#### ~~4c. Requests + Schedule Pages~~ — DROPPED

These are unnecessary. Jobber's own UI is better for managing requests and schedules. The voice agent already has full context via `fs_get_customer_by_phone` for returning callers.

### Phase 5: Disconnect Integration (Frontend + Backend)

#### Problem

There is **no disconnect button** on the Integrations page. The `IntegrationCard` only shows "Connect" or "Connected" (disabled). The only way to "disconnect" is to connect a different integration, which triggers the Nango webhook to delete the old connection. Users need a way to disconnect without connecting something else.

#### Backend: `DELETE /me/integrations/:integrationType`

New endpoint to disconnect an integration:

```typescript
app.delete('/me/integrations/:integrationType', requireAuth, async (req, res) => {
  const userId = req.user.id;
  const { integrationType } = req.params;

  const member = await prisma.organizationMember.findFirst({
    where: { userId },
    select: { organizationId: true },
  });
  if (!member) return res.status(404).json({ message: 'Not a member of any organization' });

  const connection = await prisma.nangoConnection.findFirst({
    where: {
      organizationId: member.organizationId,
      integrationType,
      status: 'active',
    },
  });
  if (!connection) return res.status(404).json({ message: 'Integration not connected' });

  // Delete from Nango first
  const nango = new Nango({ secretKey: process.env.NANGO_SECRET_KEY! });
  const providerKey = connection.providerConfigKey || connection.integrationType;
  await nango.deleteConnection(providerKey, connection.connectionId);

  // Delete from local DB
  await prisma.nangoConnection.delete({ where: { id: connection.id } });

  // Clear FieldServiceAdapterRegistry cache for all locations in this org
  // (so next call doesn't try to use the deleted adapter)

  return res.json({ message: `${integrationType} disconnected` });
});
```

#### Frontend: Disconnect Button

Add a "Disconnect" button to `IntegrationCard` when `isConnected`:

```tsx
{isConnected && (
  <Button
    variant="outline"
    onClick={onDisconnect}
    className="h-[3.2rem] text-[1.0rem] text-red-600 border-red-300 hover:bg-red-50"
  >
    Disconnect
  </Button>
)}
```

Show a confirmation dialog before disconnecting:

```
"Disconnect Jobber?"
"Your call history and caller records will be preserved, but the voice agent
will no longer be able to look up customers, create service requests, or
schedule assessments through Jobber."
[Cancel] [Disconnect]
```

---

### Phase 6: Integration Switching — Data Flow

#### Scenario: User switches from Google Calendar → Jobber (or vice versa)

**What happens today** (Nango webhook handler, `server.ts:6660-6709`):
1. New connection webhook arrives
2. All other `NangoConnection` records for the org are **deleted** (from Nango + local DB)
3. New connection is created and set as active

This is correct for the connection layer. But we need to define what happens to **local data**.

#### Data Preservation Rules

| Data | On Disconnect | On Switch | Rationale |
|------|--------------|-----------|-----------|
| `Caller` records | **KEEP** | **KEEP** | Phone numbers, names, call history are platform-agnostic |
| `CallerAddress` records | **KEEP** | **KEEP** | Addresses are useful regardless of integration |
| `CallRecord` records | **KEEP** | **KEEP** | Transcripts, summaries, evaluations are always valuable |
| `Caller.externalCustomerId` | **CLEAR** | **CLEAR** | Jobber IDs are meaningless after disconnect |
| `Caller.externalPlatform` | **CLEAR** | **CLEAR** | Same — stale platform reference |
| `Agent.config.autoScheduleAssessment` | **CLEAR** | **CLEAR** | Jobber-specific setting, irrelevant for GCal |
| `Agent.config.includePricing` | **CLEAR** | **CLEAR** | Jobber-specific setting |
| Google Calendar events | N/A | **KEEP** (in GCal) | We don't store GCal events locally |
| Jobber Clients/Requests | N/A | **KEEP** (in Jobber) | We don't store Jobber data locally |

**Key principle**: Local `Caller` and `CallRecord` data is **always preserved**. Only platform-specific linking fields (`externalCustomerId`, `externalPlatform`) and platform-specific agent config flags are cleared on disconnect/switch.

#### Implementation: Cleanup on Disconnect

When the disconnect endpoint is called (or when the Nango webhook deletes old connections), run a cleanup:

```typescript
async function cleanupAfterDisconnect(organizationId: string, integrationType: string) {
  // 1. Clear externalCustomerId/externalPlatform for callers linked to this platform
  if (integrationType === 'jobber' || integrationType === 'housecall-pro') {
    const locations = await prisma.location.findMany({
      where: { organizationId },
      select: { id: true },
    });
    const locationIds = locations.map(l => l.id);

    await prisma.caller.updateMany({
      where: {
        locationId: { in: locationIds },
        externalPlatform: integrationType,
      },
      data: {
        externalCustomerId: null,
        externalPlatform: null,
      },
    });

    // 2. Clear field-service-specific agent config flags
    const agents = await prisma.agent.findMany({
      where: { locationId: { in: locationIds }, isDefault: true },
    });
    for (const agent of agents) {
      const config = (agent.config as any) || {};
      const { autoScheduleAssessment, includePricing, ...rest } = config;
      await prisma.agent.update({
        where: { id: agent.id },
        data: { config: Object.keys(rest).length > 0 ? rest : null },
      });
    }
  }
}
```

#### Switching Scenarios

**Google Calendar → Jobber:**
1. GCal connection deleted (Nango webhook)
2. Jobber connection created
3. `cleanupAfterDisconnect(orgId, 'google-calendar')` — no-op (GCal has no external IDs)
4. Agent tools switch from `google_calendar_*` to `fs_*` automatically (via `getLiveKitToolsForLocation`)
5. Existing Callers retain their names/addresses (from intake answers)
6. New calls use Jobber for customer lookup instead of local DB

**Jobber → Google Calendar:**
1. Jobber connection deleted (Nango webhook)
2. GCal connection created
3. `cleanupAfterDisconnect(orgId, 'jobber')` — clears `externalCustomerId`/`externalPlatform`, clears `autoScheduleAssessment`/`includePricing`
4. Agent tools switch from `fs_*` to `google_calendar_*`
5. Existing Callers retain their names/addresses (synced from Jobber in Phase 1-2)
6. New calls use local Caller DB + intake answers for identity

**Jobber → Disconnect (no replacement):**
1. Jobber connection deleted
2. `cleanupAfterDisconnect(orgId, 'jobber')` — same cleanup
3. Agent has no integration tools — falls back to basic intake flow
4. Existing Callers still visible in dashboard with names/addresses

#### Edge Case: Re-connecting the Same Integration

If a user disconnects Jobber and reconnects it later:
- `externalCustomerId` was cleared, so the agent will call `fs_get_customer_by_phone` and find the customer in Jobber (they still exist there)
- Phase 1 sync will re-populate `externalCustomerId` on the next `fs_create_customer` call
- For returning callers, `fs_get_customer_by_phone` returns the Jobber client, so no data is lost

---

## Implementation Priority

| Phase | Effort | Impact | Priority |
|-------|--------|--------|----------|
| **Phase 1**: Sync name to Caller on fs_create_customer | ~30 min | High — names appear in dashboard | **P0** |
| **Phase 2**: Sync address to CallerAddress on fs_create_property | ~30 min | High — addresses appear in dashboard | **P0** |
| **Phase 3**: Add externalCustomerId to Caller | ~1 hr | Medium — enables Jobber linking | **P1** |
| **Phase 4a**: Sidebar menu adaptation | ~30 min | Medium — better UX for Jobber users | **P1** |
| **Phase 4b**: "View in Jobber" link on Caller detail | ~30 min | Low — nice-to-have once Phase 3 is done | **P2** |
| ~~Phase 4c~~: ~~Requests + Schedule pages~~ | ~~dropped~~ | N/A — Jobber's UI is better for this | N/A |
| **Phase 5**: Disconnect button (frontend + backend) | ~1.5 hr | High — users can disconnect | **P0** |
| **Phase 6**: Integration switching cleanup | ~1 hr | Medium — clean data on switch | **P1** |

---

## Summary

**Q: Do Caller and CallRecords still get created for Jobber calls?**
Yes — `Caller` (phone-only) and `CallRecord` are created at call start. But name/address are **never populated** because `submit_intake_answers` is excluded for Jobber integrations and the summarization worker no longer extracts name/address from transcripts.

**Q: How to populate name/address?**
Phases 1-2: When `fs_create_customer` and `fs_create_property` succeed, sync the data back to the local `Caller` and `CallerAddress` records.

**Q: How to link Callers to Jobber Clients?**
Phase 3: Add `externalCustomerId` + `externalPlatform` fields to the `Caller` model.

**Q: Frontend adaptation?**
Phase 4: Conditionally rename sidebar items, enrich Client detail views with Jobber data, and optionally add Requests/Schedule pages.

**Q: How do users disconnect an integration?**
Phase 5: Disconnect button on IntegrationCard + `DELETE /me/integrations/:integrationType` endpoint. Confirmation dialog warns that the agent will lose platform-specific capabilities.

**Q: What happens to data when switching integrations?**
Phase 6: Local Caller/CallRecord data is **always preserved**. Platform-specific linking fields (`externalCustomerId`, `externalPlatform`) and agent config flags (`autoScheduleAssessment`, `includePricing`) are cleared. The agent automatically switches tool sets based on the active integration. Data in the external platform (Jobber clients, GCal events) is untouched.
