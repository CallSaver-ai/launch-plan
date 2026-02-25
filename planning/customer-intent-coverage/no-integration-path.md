# No-Integration Path — Analysis & Recommendations

**Date:** Feb 24, 2026  
**Status:** Analysis Complete, Pending Decision

## Current State

### What the agent gets with NO integration connected:

**Tools:**
- `validate-address` — always available
- `submit-intake-answers` — saves caller name, address, custom Q&A
- `request-callback` (Path A only) — creates a callback request
- `transfer-call` or `warm-transfer` (Path B only) — live transfers to a phone number

**System Prompt:**
- Standard `generateSystemPromptForLocation` with no integration type
- Includes: business name, summary, hours, services, areas served, intake questions
- Does NOT include: any scheduling/booking/FS workflow instructions

**Sidebar:**
- Callback Requests tab: shown ONLY for Path A ("Keep Your Number") — gated by `hasKeepNumberLocation` in `app-sidebar.tsx` line 105
- Appointments tab: hidden when no integration connected — gated by `hasIntegration` line 109
- Visible: Dashboard, Callers, Locations, Settings

### The Gap

| | Path A (Keep Your Number) | Path B (New CallSaver Number) |
|---|---|---|
| **Transfer** | ❌ No | ✅ `transfer-call` |
| **Callback Request** | ✅ `request-callback` | ❌ No |
| **Callback Tab** | ✅ Visible | ❌ Hidden |
| **Intake** | ✅ `submit-intake-answers` | ✅ `submit-intake-answers` |

**Problem:** Path B users can transfer but can't request callbacks. If the transfer target doesn't answer, the agent has no fallback. And there's no way for the business owner to see missed callback opportunities.

---

## Should We Offer This?

**Yes. Strongly yes.** Here's why:

### Who uses the no-integration path?

1. **Solo operators with no CRM** — Plumber with a cell phone. Just wants calls answered professionally when they're on a job. Biggest segment of potential customers.

2. **Businesses evaluating CallSaver** — Signed up, haven't connected an integration yet. Want to test the experience first. Removing friction from onboarding = higher conversion.

3. **Businesses with unsupported CRMs** — ServiceTitan, FieldPulse, Workiz, etc. Still want AI call handling. We shouldn't block them from getting value.

4. **Lower-tier pricing plan customers** — Integration features could be premium. The base tier is "AI Receptionist" — answer calls, screen, collect info, callback/transfer.

### What the agent does well without an integration:

- **Answers questions**: Hours, services, areas served, FAQ — all from the system prompt
- **Screens calls**: Identifies spam, wrong numbers, solicitors
- **Collects caller info**: Name, address, service description, intake questions
- **Routes calls**: Transfer to the right person OR take a callback request
- **Builds caller history**: Every call is recorded, transcribed, caller records are created

### The "AI Receptionist" framing

This is actually the **simplest, broadest, and lowest-friction** tier. Every business can use it. No integration setup. No API keys. Just:
1. Sign up
2. Set your business info (hours, services, areas)
3. Get a phone number
4. Start taking calls

It's call screening + message taking + professional answering service. That's a standalone product worth paying for.

---

## Recommendations

### 1. Always provide BOTH callback AND transfer tools

**Current:** Mutually exclusive — Path A gets callback only, Path B gets transfer only.

**Proposed:** Both paths get `request-callback`. Path B additionally gets `transfer-call`.

```
Path A (Keep Your Number):
  - request-callback ✅ (primary)
  - transfer-call ❌ (no transfer number configured)

Path B (New CallSaver Number):
  - transfer-call ✅ (primary — tries transfer first)
  - request-callback ✅ (fallback — if transfer fails or caller prefers callback)
```

**Why:** The caller may prefer a callback over a live transfer. For example: "Actually, can you just have them call me back?" The agent needs a tool for that.

**⚠️ SIP REFER Limitation:** Our current transfer architecture uses SIP REFER — a blind transfer. The agent has **no way to detect if the transfer target answers or not**. If the target doesn't answer, the call goes to their voicemail. We do NOT get a failure signal back. True transfer failure detection would require warm transfer architecture (creating a second LiveKit room, bridging, monitoring). That's a future enhancement.

So `request-callback` on Path B is for **caller preference only** — not as a transfer failure fallback.

**Implementation (DONE):** In `getLiveKitToolsForLocation`, added `request-callback` to Path B:
```typescript
if (isPathB) {
  tools.push(useWarmTransfer ? 'warm-transfer' : 'transfer-call');
  tools.push('request-callback'); // Caller preference — "just have them call me back"
} else {
  tools.push('request-callback');
}
```

### 2. Always show Callback Requests in the sidebar

**Current:** Only shown for Path A (`hasKeepNumberLocation`).

**Proposed:** Always show it. Callback requests are created by:
- `request-callback` tool (both paths)
- System callback logging (when transfers fail)
- Could be created manually in the future

Even if a business is on Path B and mostly does transfers, they'll still get callback requests when the owner doesn't answer. They need to see them.

**Implementation:** Remove the `hasKeepNumberLocation` gate in `app-sidebar.tsx`:
```typescript
// Remove this filter:
if (item.title === 'Callback Requests' && !hasKeepNumberLocation) {
  return false
}
```

### 3. Enhance the no-integration system prompt

The current base prompt doesn't have explicit call flow instructions. It has intake questions and business info, but no equivalent of the "WORKFLOW FOR NEW CALLERS" that FS integrations get.

**Add a lightweight "AI Receptionist" workflow to the base prompt:**

```
CALL HANDLING WORKFLOW:
1. Answer professionally and identify the business.
2. Ask how you can help.
3. Based on the caller's request:
   - If asking about services/hours/areas → answer from business info above
   - If requesting service → collect their name, address, and service details via intake questions
   - If asking for a specific person → [transfer if Path B] / [take a callback request if Path A]
   - If asking about an existing appointment → offer to take a callback request for the office to follow up
4. Always collect the caller's name and information before ending the call.
5. If you can't help with their request, [transfer / offer a callback request].
```

This would be a prompt addition in `server.ts` for the no-integration case (when `!hasFsTools && !hasSchedulingTools`).

### 4. Pricing tier alignment

| Tier | Features | Integration |
|---|---|---|
| **Starter** | AI Receptionist — answer calls, screen, intake, callback requests | None required |
| **Professional** | + Google Calendar scheduling | Google Calendar |
| **Business** | + CRM integration (Jobber / HCP) — full lead capture, scheduling, customer management | Jobber or HCP |

The Starter tier maps perfectly to the no-integration path. It's not a broken state — it's a feature.

---

## Open Questions

1. **Should Path A also get transfer-call?** Currently Path A can't transfer because the business kept their number (CallSaver is behind their existing line). But technically they could configure a transfer number (e.g., owner's cell) even on Path A. Worth considering for a future enhancement.

2. **Callback request notification:** How does the business owner know they have a callback request? Currently they'd need to check the dashboard. Should we add:
   - Email notification?
   - SMS notification?
   - Push notification?
   This becomes more critical if callback requests are the primary workflow (no-integration tier).

3. **Intake questions for no-integration:** The current intake questions are configured during onboarding. Are the default intake questions (name, address, service description) sufficient for the no-integration tier? Or should we add a "reason for calling" question by default?

4. **What about the Callers tab?** Every call creates a caller record. The Callers tab is always visible. For the no-integration tier, the Callers tab + Callback Requests tab IS the product. The business owner checks their callbacks, sees caller history, and follows up manually.

---

## Summary

The no-integration path is **not a gap — it's a feature**. It's the lowest-friction, broadest-appeal tier. The main changes needed:

1. **Always provide `request-callback` tool** (both paths) — small backend change
2. **Always show Callback Requests tab** — small frontend change  
3. **Add lightweight call handling workflow to base prompt** — prompt engineering
4. **Frame it as "AI Receptionist" tier in pricing** — marketing/positioning

These are all low-effort, high-impact changes that make the no-integration experience intentionally good rather than accidentally incomplete.
