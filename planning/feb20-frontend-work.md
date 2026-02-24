# Feb 20 Frontend Work

Four workstreams for today's frontend + backend work:

1. **Onboarding Redesign** — Move integrations before services, conditionally skip services step
2. **Auto-Schedule Assessment Toggle** — Add UI toggle in location settings for `autoScheduleAssessment`
3. **Include Pricing Toggle** — Add UI toggle in agent config for `includePricing`, conditionally strip prices from get-services
4. **Disconnect Integration** — Add disconnect button + confirmation dialog on Integrations page

---

## 1. Onboarding: Integration-First Redesign

### Problem

The current onboarding flow is:

```
Step 1: Business Info (read-only)
Step 2: Service Areas
Step 3: Services ← REDUNDANT for Jobber/HCP/Square
Step 4: Customize Voice
Step 5: Connect Integrations ← TOO LATE — needed earlier to skip Step 3
Step 6: Choose Your Setup Path
Step 7: Call Forwarding / Transfer Setup
```

**Issues**:
- **Step 3 (Services)** asks users to manually select/add services. But Jobber, Housecall Pro, and Square Bookings all manage their own service catalogs. Only Google Calendar users need to manually configure services.
- **Step 5 (Integrations)** comes AFTER services, so we don't know which integration the user will connect until it's too late to skip Step 3.
- Users connecting Jobber/HCP/Square waste time on a step that will be overridden by their platform's service catalog.

### Proposed New Flow

Move integrations **before** services, then conditionally skip or adapt the services step:

```
Step 1: Business Info (read-only)                    — unchanged
Step 2: Service Areas                                — unchanged
Step 3: Connect Integration (moved up from Step 5)   — MOVED
Step 4: Services (conditional — skip for Jobber/HCP/Square) — CONDITIONAL
Step 5: Customize Voice (was Step 4)                 — renumbered
Step 6: Choose Your Setup Path (was Step 6)          — renumbered
Step 7: Call Forwarding / Transfer Setup (was Step 7) — renumbered
```

#### Step 3: Connect Integration (New Position)

Same UI as current Step 5, but now positioned right after Service Areas. This lets us know the integration type before we reach the services step.

**Key behavior**: When a user connects an integration, we immediately know:
- `google-calendar` → needs manual services step
- `jobber` → services managed in Jobber, skip services step
- `housecall-pro` → services managed in HCP, skip services step (when added)
- `square-bookings` → services managed in Square, skip services step

If the user **skips** the integration step (clicks "Next Step" without connecting), they proceed to the services step as normal (same as today for non-integrated users).

#### Step 4: Services (Conditional)

| Connected Integration | Services Step Behavior |
|----------------------|----------------------|
| None (skipped)       | Show full services step (current behavior) |
| Google Calendar      | Show full services step (GCal has no service catalog) |
| Jobber               | **SKIP** — auto-skip to Voice step |
| Housecall Pro        | **SKIP** — auto-skip to Voice step |
| Square Bookings      | **SKIP** — auto-skip to Voice step |

**Recommendation**: Auto-skip (Option A) for simplicity. The integration connection dialog already confirms the connection.

### Implementation Plan

#### File: `src/pages/OnboardingPage.tsx`

**1. Track connected integration type**

Already have `connectedIntegrationIds` (Set). Need to derive the integration type:

```typescript
const connectedIntegrationType = React.useMemo(() => {
  for (const cfg of AVAILABLE_INTEGRATIONS) {
    if (connectedIntegrationIds.has(cfg.id)) return cfg.id;
  }
  return null;
}, [connectedIntegrationIds]);

const integrationManagesServices = connectedIntegrationType === 'jobber' 
  || connectedIntegrationType === 'square-bookings';
```

**2. Reorder steps**

```
Old: 1=BizInfo, 2=ServiceAreas, 3=Services, 4=Voice, 5=Integrations, 6=Path, 7=Forwarding
New: 1=BizInfo, 2=ServiceAreas, 3=Integrations, 4=Services(conditional), 5=Voice, 6=Path, 7=Forwarding
```

**3. Update `handleNextStep` logic**

```typescript
} else if (currentStep === 3) {
  if (integrationManagesServices) {
    setCurrentStep(5); // Skip services
  } else {
    setCurrentStep(4); // Show services
  }
}
```

**4. Update `handlePreviousStep` logic**

```typescript
} else if (currentStep === 5) {
  if (integrationManagesServices) {
    setCurrentStep(3); // Skip back over services
  } else {
    setCurrentStep(4);
  }
}
```

**5. Update `handleCompleteOnboarding`**

```typescript
if (!integrationManagesServices) {
  const allServices = [...selectedServices, ...customServices];
  // ... existing save logic
}
```

**6. Update step titles** — Step 3 title becomes "Connect Integration"

**7. Update progress indicator** — Step 3 (integrations) needs wider card class

**8. Fix `handleIntegrationConnected`** — Remove `handleCompleteOnboarding()` call. Connecting should NOT complete onboarding.

```typescript
const handleIntegrationConnected = async (integrationId: string, connectionId: string) => {
  setConnectedIntegrationIds((prev) => new Set(prev).add(integrationId));
  toast.success(`${config?.displayName ?? 'Integration'} connected!`);
  await refetchIntegrations();
  setTargetIntegration(null);
  setShowConnectDialog(false);
  // DO NOT call handleCompleteOnboarding() here anymore
};
```

### Step Count Summary

| Scenario | Steps User Sees |
|----------|----------------|
| No integration | 1 → 2 → 3 → 4 → 5 → 6 → 7 (all 7) |
| Google Calendar | 1 → 2 → 3 → 4 → 5 → 6 → 7 (all 7) |
| Jobber | 1 → 2 → 3 → ~~4~~ → 5 → 6 → 7 (6 steps) |
| Square Bookings | 1 → 2 → 3 → ~~4~~ → 5 → 6 → 7 (6 steps) |

### Edge Cases

1. **Connect Jobber → go back → disconnect → go forward** — `integrationManagesServices` recalculates, services step reappears.
2. **Skip integration → add services → go back → connect Jobber** — Harmless. Save is skipped for Jobber.
3. **Pre-fetched services from bootstrap** — Empty for Jobber users anyway. No change needed.
4. **HCP not yet in AVAILABLE_INTEGRATIONS** — Add `'housecall-pro'` to check when available.

---

## 2. Auto-Schedule Assessment Toggle

### Problem

`autoScheduleAssessment` lives in `agents.config` JSONB and is currently only settable via the internal API (`POST /internal/toggle-auto-schedule-assessment`). There's no UI for business owners to control whether the voice agent auto-schedules assessments or leaves them unscheduled for the team.

### Design

Add a toggle to the **Location Settings** page (not onboarding — this is a post-setup preference).

#### Where in the UI

The Location Settings page already has sections for appointment settings, business profile, etc. Add a new **"Field Service Settings"** section that only appears when a field service integration (Jobber/HCP) is connected.

```
┌─────────────────────────────────────────────┐
│ Field Service Settings                       │
│                                              │
│ Auto-Schedule Assessments          [toggle]  │
│ When enabled, the voice agent will           │
│ offer callers available times and            │
│ schedule the initial consultation            │
│ automatically. When disabled, the            │
│ team handles scheduling manually.            │
│                                              │
│ Include Pricing in Services        [toggle]  │
│ When enabled, the voice agent will           │
│ mention service prices to callers.           │
│ When disabled, prices are hidden             │
│ and the agent won't discuss pricing.         │
└─────────────────────────────────────────────┘
```

#### Backend

Already exists: `POST /internal/toggle-auto-schedule-assessment` with `{ locationId, enabled }`.

Need a **user-facing endpoint** (or extend the existing `PATCH /me/locations/:locationId`):

**Option A: Extend `PATCH /me/locations/:locationId`** — Add `agentConfig` to the request body schema:

```typescript
// Add to updateLocationRequestBodySchema:
agentConfig: z.object({
  autoScheduleAssessment: z.boolean().optional(),
  includePricing: z.boolean().optional(),
}).optional(),
```

In the handler, when `agentConfig` is provided, update the agent's config JSONB:

```typescript
if (body.agentConfig) {
  const agent = await prisma.agent.findFirst({
    where: { locationId, isDefault: true },
  });
  if (agent) {
    const existingConfig = (agent.config as any) || {};
    const updatedConfig = {
      ...existingConfig,
      ...(body.agentConfig.autoScheduleAssessment !== undefined && {
        autoScheduleAssessment: body.agentConfig.autoScheduleAssessment,
      }),
      ...(body.agentConfig.includePricing !== undefined && {
        includePricing: body.agentConfig.includePricing,
      }),
    };
    await prisma.agent.update({
      where: { id: agent.id },
      data: { config: updatedConfig },
    });
  }
}
```

**Option B: Dedicated endpoint** — `PATCH /me/locations/:locationId/agent-config` with `{ autoScheduleAssessment?, includePricing? }`. Cleaner separation but more code.

**Recommendation**: Option A — extend the existing location update endpoint. Fewer moving parts.

#### Frontend

In the Location Settings page, read the current agent config and render toggles:

```typescript
// Fetch: GET /me/locations/:locationId/agent returns agent.config
const agentConfig = agent?.config || {};
const autoScheduleAssessment = agentConfig.autoScheduleAssessment ?? false;
const includePricing = agentConfig.includePricing ?? true; // default ON

// Save: PATCH /me/locations/:locationId with { agentConfig: { autoScheduleAssessment: true } }
```

#### Read path

The `GET /me/locations/:locationId/agent` endpoint already returns the agent object. We need to ensure `config` is included in the response. Check `getAgentResponseSchema` and add `config` if missing.

---

## 3. Include Pricing Toggle

### Problem

Currently, `get-services` always includes `price` in the response and the formatted message. Some businesses don't want the voice agent quoting prices — they prefer to discuss pricing during the assessment/consultation.

### Design

#### Storage

`includePricing` lives in `agents.config` JSONB alongside `autoScheduleAssessment`:

```json
{
  "autoScheduleAssessment": true,
  "includePricing": false
}
```

Default: `true` (prices shown) — backward compatible.

#### Backend: `get-services` endpoint

The `get-services` endpoint needs to know whether to include pricing. Two options:

**Option A: Pass `includePricing` from the Python agent** — The Python tool already has access to the agent config via the tool context. Pass it as a body param.

**Option B: Read agent config in the endpoint** — The endpoint already has `locationId`, so it can look up the agent config directly.

**Recommendation**: Option B — keeps the logic server-side and doesn't require Python changes.

```typescript
// In get-services endpoint:
const agent = await prisma.agent.findFirst({
  where: { locationId, isDefault: true },
  select: { config: true },
});
const agentConfig = (agent?.config as any) || {};
const includePricing = agentConfig.includePricing !== false; // default true

const cleanServices = services.map((svc: any) => ({
  id: svc.id,
  name: svc.name,
  description: svc.description,
  category: svc.category,
  duration: svc.duration,
  price: includePricing ? svc.price : undefined,  // Conditionally include
  isActive: svc.isActive,
}));

// In the formatted message:
const serviceList = cleanServices.map((svc: any, index: number) => {
  const parts = [`${index + 1}. ${svc.name}`];
  if (svc.id) parts.push(`[service_id=${svc.id}]`);
  if (svc.description) parts.push(`(${svc.description})`);
  if (svc.duration) parts.push(`- ${svc.duration} min`);
  if (includePricing && svc.price) parts.push(`- $${svc.price}`);
  return parts.join(' ');
}).join('\n');
```

#### System prompt adaptation

When `includePricing` is false, the system prompt Step 9 instructions should NOT reference `service_price`:

```typescript
// In server.ts fsInstructions, after reading agentConfig:
const includePricing = agentConfig.includePricing !== false;

// Step 9 instructions:
// If includePricing:
//   "- **service_price**: the price shown in the fs_get_services result..."
// If !includePricing:
//   "- Do NOT mention or discuss pricing. If the caller asks about cost, say pricing will be discussed during the consultation."
```

#### Frontend

Same toggle UI as described in Section 2 above — part of the "Field Service Settings" card.

---

## 4. Disconnect Integration

### Problem

The Integrations page (`IntegrationsPage.tsx`) has **no disconnect button**. The `IntegrationCard` shows "Connect" or "Connected" (disabled). The only way to disconnect is to connect a different integration, which triggers the Nango webhook to delete the old connection. Users need a way to disconnect without connecting something else.

### Backend: `DELETE /me/integrations/:integrationType`

New endpoint. See `jobber-caller-integration-design.md` Phase 5 for full implementation.

Key steps:
1. Find the active `NangoConnection` for the org + integrationType
2. Delete from Nango via `nango.deleteConnection(providerKey, connectionId)`
3. Delete from local DB
4. Run `cleanupAfterDisconnect(orgId, integrationType)` — clears `externalCustomerId`, `externalPlatform`, and field-service agent config flags
5. Invalidate FieldServiceAdapterRegistry cache

### Frontend Changes

#### `integration-card.tsx`

Add `onDisconnect` prop and a "Disconnect" button when connected:

```tsx
interface IntegrationCardProps {
  // ... existing props
  onDisconnect?: () => void;
}

// In the button area, after the Connect button:
{isConnected && onDisconnect && (
  <Button
    variant="outline"
    onClick={onDisconnect}
    className="h-[3.2rem] text-[1.0rem] text-red-600 border-red-300 hover:bg-red-50"
  >
    Disconnect
  </Button>
)}
```

#### New: `disconnect-integration-dialog.tsx`

Confirmation dialog before disconnecting:

```
"Disconnect [Integration Name]?"
"Your call history and caller records will be preserved, but the voice agent
will no longer be able to [integration-specific capabilities]."
[Cancel] [Disconnect]
```

Integration-specific capability text:
- **Jobber**: "look up customers, create service requests, or schedule assessments through Jobber"
- **Google Calendar**: "check calendar availability or book appointments through Google Calendar"
- **Square Bookings**: "manage bookings through Square"

#### `IntegrationsPage.tsx`

Add disconnect handler:

```typescript
const [showDisconnectDialog, setShowDisconnectDialog] = useState(false);
const [disconnectTarget, setDisconnectTarget] = useState<IntegrationConfig | null>(null);

const handleDisconnect = useCallback(async () => {
  if (!disconnectTarget) return;
  try {
    await apiClient.delete(`/me/integrations/${disconnectTarget.id}`);
    toast.success(`${disconnectTarget.displayName} disconnected`);
    await refetch();
  } catch (error) {
    toast.error('Failed to disconnect integration');
  } finally {
    setShowDisconnectDialog(false);
    setDisconnectTarget(null);
  }
}, [disconnectTarget, refetch]);
```

### Integration Switching Data Flow

See `jobber-caller-integration-design.md` Phase 6 for the full data preservation rules and cleanup logic. Key principle: **local Caller/CallRecord data is always preserved**. Only platform-specific linking fields and agent config flags are cleared.

---

## Files to Modify

| File | Changes |
|------|---------|
| **Frontend** | |
| `src/pages/OnboardingPage.tsx` | Reorder steps, conditional skip, fix navigation, fix early completion |
| `src/pages/LocationSettingsPage.tsx` (or equivalent) | Add "Field Service Settings" section with toggles |
| `src/pages/IntegrationsPage.tsx` | Add disconnect handler, disconnect dialog state |
| `src/components/integrations/integration-card.tsx` | Add `onDisconnect` prop, Disconnect button |
| `src/components/integrations/disconnect-integration-dialog.tsx` | **NEW** — confirmation dialog |
| **Backend** | |
| `src/contracts/more-user-endpoints.contract.ts` | Add `agentConfig` to `updateLocationRequestBodySchema` |
| `src/server.ts` (or location update handler) | Handle `agentConfig` in PATCH location, update agent.config JSONB |
| `src/server.ts` (agent-config endpoint) | Read `includePricing` from agent config, conditionally adjust Step 9 prompt |
| `src/server.ts` (disconnect endpoint) | **NEW** — `DELETE /me/integrations/:integrationType` |
| `src/server.ts` (nango webhook) | Add `cleanupAfterDisconnect()` call when deleting old connections |
| `src/routes/field-service-tools.ts` | Read `includePricing` in get-services, conditionally strip price |
| `src/server.ts` (getAgent endpoint) | Ensure `config` is returned in GET agent response |

## Effort Estimate

| Task | Effort |
|------|--------|
| Onboarding step reorder + skip logic | ~2 hr |
| Auto-schedule toggle (backend + frontend) | ~1 hr |
| Include pricing toggle (backend + frontend) | ~1.5 hr |
| Disconnect integration (backend + frontend) | ~1.5 hr |
| **Total** | **~6 hr** |

## Implementation Order

1. **Backend first**: Extend PATCH location to accept `agentConfig`, update get-services for `includePricing`, update system prompt, add disconnect endpoint + cleanup function
2. **Onboarding redesign**: Step reorder + conditional skip
3. **Settings toggles**: Add Field Service Settings section with both toggles
4. **Disconnect button**: Add to IntegrationCard + confirmation dialog + handler
