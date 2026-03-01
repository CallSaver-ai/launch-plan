# Voice Agent Composability & Availability Provider Refactor

Date: March 1, 2026  
Status: Future reference — not yet implemented

This document captures two architectural proposals discussed during the Google Calendar QA session. Both are designed to make the voice agent system more elegant, testable, and future-proof as we add new verticals (legal, hospitality, etc.) and integrations.

---

## Part 1: Abstract Availability Provider

### The Problem

Three platforms compute availability differently, but the end result is the same: "given a date and business constraints, produce contiguous time windows where an appointment can be booked." Currently each platform has its own ~200-line implementation with duplicated logic for business hours, buffer time, and duration handling.

### How Each Platform Works Today

#### Google Calendar — "Here's when I'm busy"
- **API:** `freeBusy` endpoint returns `[{ start, end }]` busy periods
- **Our code does:** Generate a grid of candidate slots every 15 minutes from open to (close − duration). For each candidate, expand by buffer on both sides, reject if it overlaps any busy period.
- **Output:** Individual slot start times → collapsed into windows
- **File:** `src/server.ts` — `computeAvailableSlots()` + `collapseToWindows()`

#### Jobber — "Here's everything that's scheduled"
- **API:** `scheduledItems` GraphQL query returns visits, assessments, tasks, events with `{ startAt, endAt }`
- **Our code does:** Walk through the day, find gaps between scheduled items. Each gap that's ≥ duration + buffer becomes an available window.
- **Output:** `TimeSlot[]` windows (contiguous free blocks)
- **File:** `src/adapters/field-service/platforms/jobber/JobberAdapter.ts` — `checkAvailability()`

#### Housecall Pro — "Here's when you CAN book"
- **API:** `GET /booking_windows` returns `[{ start_time, end_time, available }]` pre-computed windows
- **Our code does:** Filter `available=true`, merge consecutive windows into contiguous blocks
- **Output:** `TimeSlot[]` merged windows
- **File:** `src/adapters/field-service/platforms/housecallpro/HousecallProAdapter.ts` — `checkAvailability()`

### The Key Insight

Despite three totally different APIs, all three reduce to the same abstract operation. The difference is just **where the math happens**:

| Platform | Who computes availability? | What you receive |
|---|---|---|
| Google Calendar | **You** (from busy periods) | Busy ranges → you invert |
| Jobber | **You** (from scheduled items) | Occupied ranges → you find gaps |
| Housecall Pro | **The platform** | Available windows → you just merge |

### Proposed Interface

```typescript
interface AvailabilityWindow {
  start: Date;       // earliest possible appointment start
  end: Date;         // latest appointment end (last start + duration)
}

interface AvailabilityConfig {
  durationMinutes: number;
  bufferMinutes: number;
  stepMinutes: number;          // granularity of start times (15 min)
  timezone: string;
  businessHours: BusinessHoursForWeek;
}

interface AvailabilityProvider {
  /**
   * Returns raw "occupied" or "available" periods from the platform.
   * The engine doesn't care HOW you got them — just the shape.
   */
  getOccupiedPeriods(
    date: string,
    config: AvailabilityConfig
  ): Promise<TimePeriod[]>;

  /**
   * What kind of data does this provider return?
   * - 'busy':      periods represent OCCUPIED time (GCal, Jobber)
   * - 'available': periods represent AVAILABLE time (HCP)
   */
  readonly periodType: 'busy' | 'available';
}
```

### The Engine (Platform-Agnostic)

This is the part that could be an open-source library. It takes any `AvailabilityProvider` and produces `AvailabilityWindow[]`:

```typescript
async function computeAvailability(
  provider: AvailabilityProvider,
  date: string,
  config: AvailabilityConfig
): Promise<AvailabilityWindow[]> {
  const periods = await provider.getOccupiedPeriods(date, config);
  const hours = getBusinessHoursForDate(date, config.timezone, config.businessHours);
  if (!hours) return [];  // closed

  if (provider.periodType === 'available') {
    // HCP path: periods ARE the available windows already.
    // Just clip to business hours and ensure each fits ≥ 1 appointment.
    return periods
      .map(p => clipToBusinessHours(p, hours))
      .filter(p => durationFits(p, config.durationMinutes));
  }

  // GCal / Jobber path: periods are BUSY. Invert them.
  const candidates = generateGrid(hours, config);
  const available = candidates.filter(slot =>
    !conflicts(slot, periods, config.durationMinutes, config.bufferMinutes)
  );
  return collapseToWindows(available, config.durationMinutes, config.stepMinutes);
}
```

### The Three Implementations

#### GoogleCalendarProvider (~10 lines)
```typescript
class GoogleCalendarProvider implements AvailabilityProvider {
  readonly periodType = 'busy';

  async getOccupiedPeriods(date, config) {
    const response = await this.calendarApi.freeBusy({
      timeMin: `${date}T00:00:00Z`,
      timeMax: `${date}T23:59:59Z`,
      timeZone: config.timezone,
      items: [{ id: this.calendarId }]
    });
    return response.calendars[this.calendarId].busy;
  }
}
```

#### JobberProvider (~15 lines)
```typescript
class JobberProvider implements AvailabilityProvider {
  readonly periodType = 'busy';

  async getOccupiedPeriods(date, config) {
    const items = await this.client.query(SCHEDULED_ITEMS_QUERY, {
      filter: {
        occursWithin: { startAt: `${date}T00:00Z`, endAt: `${date}T23:59Z` },
        schedulingAspects: ['ALL']
      }
    });
    return items.nodes
      .filter(item => item.startAt && item.endAt)
      .map(item => ({ start: item.startAt, end: item.endAt }));
  }
}
```

#### HousecallProProvider (~12 lines)
```typescript
class HousecallProProvider implements AvailabilityProvider {
  readonly periodType = 'available';

  async getOccupiedPeriods(date, config) {
    const response = await this.client.get('/booking_windows', {
      start_date: date, show_for_days: 1
    });
    return response.booking_windows
      .filter(w => w.available !== false)
      .map(w => ({ start: w.start_time, end: w.end_time }));
  }
}
```

### Multi-Technician Scheduling (Future v2)

The current architecture treats the business as one calendar. But a plumbing company with 3 techs has 3 independent calendars — an appointment at 10 AM for tech A doesn't block 10 AM for tech B.

The interface would need to expand:

```typescript
interface AvailabilityProvider {
  getOccupiedPeriods(date, config): Promise<TimePeriod[]>;
  // OR, for multi-resource:
  getOccupiedPeriodsPerResource?(date, config): Promise<Map<string, TimePeriod[]>>;
  
  readonly periodType: 'busy' | 'available';
  readonly resourceMode: 'single' | 'multi';
}
```

For `multi` resource mode, the engine would:
1. Get occupied periods per technician
2. Compute availability per technician independently
3. Union the results — if ANY tech is available at 10 AM, 10 AM is available
4. Optionally expose which tech is assigned (for dispatch)

This applies to:
- **Jobber:** `scheduledItems` can be filtered by `assignedUsers`
- **HCP:** booking windows can be per-employee
- **ServiceTitan:** dispatching is employee-based
- **Google Calendar:** could use multiple calendars (one per tech)

This is a v2 concern. For a voice agent that's just finding "when can the business see me?", the single-calendar abstraction works perfectly.

### Potential Open-Source Library Structure

```
@callsaver/availability-engine
├── src/
│   ├── types.ts              # AvailabilityWindow, AvailabilityConfig, TimePeriod
│   ├── engine.ts             # computeAvailability() — the pure math
│   ├── grid.ts               # generateGrid(), collapseToWindows()
│   ├── business-hours.ts     # parseBusinessHours(), getHoursForDate()
│   └── conflict.ts           # conflicts(), clipToBusinessHours()
├── providers/                # Optional, separate packages
│   ├── google-calendar.ts
│   ├── jobber.ts
│   └── housecallpro.ts
└── index.ts
```

The engine is ~150-200 lines of pure TypeScript with zero dependencies. Providers are thin wrappers (~10-15 lines each).

---

## Part 2: Composable Prompt Architecture

### The Problem

`generateSystemPrompt()` in `utils.ts` is an ~800-line monolithic function that conditionally assembles a system prompt from ~20 data sources. It has a big `switch` on `integrationType` with inline sections for business identity, caller context, services, workflow, guardrails, intake, scheduling, closing, and style — all tangled together.

Problems:
1. **Everything is tangled.** GCal instructions (200+ lines) live in the same function as Jobber FSM workflow (200+ lines), voice persona, FAQ section, triage rules, etc.
2. **Test parity is fragile.** `livekit-python/tests/prompts.py` manually replicates prompt sections — if production changes, tests silently drift.
3. **New verticals require surgery.** Adding legal means weaving a new `case 'lawmatics':` block into the existing switch, touching 5+ places.
4. **No token budgeting.** Can't see which sections consume how many tokens, can't selectively trim.

### The Core Insight

The voice agent session has **five orthogonal concerns** currently mixed together:

| Concern | What it answers | Current location |
|---|---|---|
| **Business Identity** | Who is this business? Hours, services, areas, policies | `utils.ts` — top of generateSystemPrompt |
| **Caller Context** | Who is calling? Returning? Previous calls? | `server.ts` — buildDynamicAssistantConfig + variable injection |
| **Integration Workflow** | What tools exist? How should they be used? | `utils.ts` — the big switch block |
| **Conversation Rules** | Tone, guardrails, safety, name handling, closing | `utils.ts` — scattered + prompt-fragments.json |
| **Data Collection** | What intake questions? What ordering? When to save? | `utils.ts` — intakeSectionDynamic |

Each is independently composable. A GCal location and a Jobber location share 80% of their prompt — they differ only in Integration Workflow.

### The PromptSection Model

```typescript
interface PromptSection {
  id: string;              // e.g., 'business-identity', 'gcal-scheduling'
  category: SectionCategory;
  priority: number;        // ordering: lower = earlier in prompt
  content: string;
  estimatedTokens?: number;
  requiredBy?: string[];   // which integration types need this section
}

type SectionCategory =
  | 'identity'      // who the business is
  | 'caller'        // who's calling
  | 'workflow'      // integration-specific tools & flow
  | 'rules'         // behavioral constraints & guardrails
  | 'collection'    // intake & data gathering
  | 'closing';      // end-of-call behavior
```

### The Provider Interface

```typescript
interface SessionContext {
  location: Location;
  organization: Organization;
  profile: BusinessProfile | null;
  googlePlaceDetails: GooglePlaceDetails | null;
  caller: CallerInfo | null;
  isReturningCaller: boolean;
  previousCallSummary: string | null;
  previousCallToolCalls: any[] | null;
  callerCalendarEvents: any[] | null;
  integrationConnection: IntegrationConnection | null;
  integrationType: IntegrationType;
  timezone: string;
  currentTime: string;
}

interface PromptProvider {
  getSections(ctx: SessionContext): PromptSection[];
}
```

### The Five Providers

#### 1. BusinessIdentityProvider (always present)
Produces sections for: persona, name, summary, hours, service areas, payment methods, business scope, trust/credentials, value props, policies, brands, FAQs, discounts.

Each `buildXxxSection()` is a small (20-40 line) testable pure function. The current 800-line monster becomes ~15 small functions.

#### 2. CallerContextProvider (always present)
Adapts based on whether caller data exists. Produces sections for: caller personalization variables, recent call context, calendar events, name handling. Returns empty sections if no caller data.

#### 3. IntegrationWorkflowProvider (polymorphic — one per platform)

```
BaseSchedulingProvider (abstract)
  ├── GoogleCalendarWorkflowProvider
  ├── JobberWorkflowProvider
  ├── HousecallProWorkflowProvider
  ├── SquareWorkflowProvider
  └── NoIntegrationWorkflowProvider

Future:
  ├── LawmaticsWorkflowProvider
  ├── AcuityWorkflowProvider
  └── ClioWorkflowProvider
```

`BaseSchedulingProvider` has shared methods (timezone section, business hours section, duration/buffer section) that ALL scheduling integrations reuse. Platform-specific instructions are separate.

#### 4. ConversationRulesProvider (always present)
Produces mostly static sections: voice style, phone number pronunciation, price style, email spelling, safety rules, escalation rules, guardrails, agent identity. These rarely change between integrations.

#### 5. DataCollectionProvider (always present)
Handles intake questions, ordering, "saving caller info" section. For field-service integrations, intake is handled differently (embedded in the workflow) — this provider knows to defer.

### The Assembly Engine

```typescript
function assembleSystemPrompt(ctx: SessionContext): string {
  const providers: PromptProvider[] = [
    new BusinessIdentityProvider(),
    new CallerContextProvider(),
    getWorkflowProvider(ctx.integrationType),
    new ConversationRulesProvider(),
    new DataCollectionProvider(),
  ];

  const allSections = providers.flatMap(p => p.getSections(ctx));
  const sorted = allSections
    .filter(s => s.content.trim().length > 0)
    .sort((a, b) => a.priority - b.priority);

  // Log section manifest for debugging
  console.log('[prompt] Sections:', sorted.map(s => `${s.id}(${s.priority})`).join(', '));

  return sorted.map(s => s.content).join('\n\n');
}
```

### What This Buys

1. **Isolated testability** — each provider unit-tested independently. No more recreating the entire prompt in test files.

2. **Perfect test parity** — tests import the exact same providers, override specific sections. No drift between production and test prompts.

3. **Prompt auditing** — every call logs its section manifest. When a call goes wrong, you see exactly which sections were included.

4. **Token budgeting** — each section estimates token count. Lower-priority sections (discounts, FAQ, brands) get trimmed first if needed.

5. **New verticals are clean** — adding legal = create `LawmaticsWorkflowProvider` + optionally override `DataCollectionProvider`. Business identity, caller context, conversation rules are all inherited.

6. **A/B testing** — swap one provider for a variant. "Does SchedulingInstructionsV2 improve booking rates?"

### Proposed File Structure

```
src/prompt-providers/
  ├── base.ts                          # PromptSection, SessionContext, PromptProvider types
  ├── business-identity.ts             # BusinessIdentityProvider
  ├── caller-context.ts                # CallerContextProvider
  ├── conversation-rules.ts            # ConversationRulesProvider
  ├── data-collection.ts               # DataCollectionProvider
  ├── workflows/
  │   ├── base-scheduling.ts           # BaseSchedulingProvider (shared timezone/hours/duration)
  │   ├── google-calendar.ts           # GoogleCalendarWorkflowProvider
  │   ├── jobber.ts                    # JobberWorkflowProvider
  │   ├── housecall-pro.ts             # HousecallProWorkflowProvider
  │   ├── square-bookings.ts           # SquareWorkflowProvider
  │   ├── lawmatics.ts                 # LawmaticsWorkflowProvider (future)
  │   └── no-integration.ts            # NoIntegrationWorkflowProvider
  └── index.ts                         # assembleSystemPrompt + factory
```

### What This Does NOT Change

- **LiveKit's tool system stays the same.** Tools are registered via `@function_tool`. This is purely about prompt assembly.
- **The Python agent (server.py) stays the same.** It calls `/internal/agent-config`, gets back a system prompt and tool list.
- **Backend tool endpoints stay the same.** Guards, Prisma queries, API calls — none of that changes.

The refactor is entirely in `utils.ts` → new `src/prompt-providers/` directory.

### Incremental Migration Path

1. **Phase 1:** Extract the 5 provider classes, each returning the same text the current function produces. `assembleSystemPrompt()` calls them and joins. **Zero behavioral change, just restructuring.** (4-6 hours)

2. **Phase 2:** Share providers between production (`utils.ts`) and tests (`prompts.py`). Export section builders as a shared module. Kill duplicated prompt text in tests.

3. **Phase 3:** Add section manifest logging. Debug calls by seeing which sections were included.

4. **Phase 4:** Use providers for the legal vertical — proves the architecture scales.

---

## Relationship Between the Two Proposals

The Availability Provider and the Prompt Architecture are complementary:

- The **AvailabilityProvider** is a runtime abstraction — it handles the actual computation during a call when the agent checks availability.
- The **PromptProvider** is a configuration-time abstraction — it handles assembling the instructions that tell the agent HOW to use the availability tools.

In the composable architecture, each `IntegrationWorkflowProvider` would:
1. Own the prompt sections that explain how to use its scheduling tools
2. Own (or reference) the `AvailabilityProvider` that computes actual slots
3. Own the tool definitions that the Python agent registers

This creates a clean vertical slice per integration:
```
GoogleCalendarIntegration/
  ├── GoogleCalendarWorkflowProvider    → prompt sections
  ├── GoogleCalendarAvailabilityProvider → slot computation
  └── google_calendar_*.py              → Python tool implementations
```

Everything about Google Calendar lives together, and nothing about Google Calendar leaks into Jobber's code or vice versa.
