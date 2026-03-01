# Google Calendar: Availability Windows + Booking Guard Fixes

Date: March 1, 2026

Three bugs discovered during QA testing of the Google Calendar integration. All three relate to the scheduling flow.

---

## Bug 1: Agent Suggests Invalid Appointment Times (e.g., 4:30 PM with 90-min Duration Past 5 PM Close)

### Symptom
Business is open 9 AM–5 PM with 90-minute default duration. The agent suggested and allowed booking at 4:30 PM, which would end at 6:00 PM — past closing.

### Root Cause
The Python tool `check_google_calendar_availability` (line 132) **discards the actual slot data** and only returns a count message to the LLM:

```python
return result.get("message", "Availability check completed")
# LLM receives: "There are 12 available appointment slot(s) on 2026-03-02."
```

The backend `computeAvailableSlots()` correctly limits slots to `close - duration` (line 11893: `lastSlotStart = hours.closeMinutes - durationMin`), so 4:30 PM would never appear in the slots array. But the LLM never sees the slots — it invents times based on the business hours in the prompt.

The backend create-event guard (lines 12131-12145) **should** reject a 4:30 PM booking since the end time (6:00 PM) bleeds past 5 PM. This guard may have a secondary parsing issue, but the primary fix is preventing the agent from suggesting invalid times in the first place.

### Fix (3 parts)

#### Part A: Backend — Add `windows` to get-availability response
**File:** `src/server.ts`

Add a `collapseToWindows()` helper that groups contiguous slots into availability windows:

- **Input slots:** `[9:00, 9:30, 10:00, 10:30, (gap), 2:30, 3:00, 3:30]` (90-min duration)
- **Output windows:** `[{start: "9:00 AM", end: "12:00 PM"}, {start: "2:30 PM", end: "5:00 PM"}]`

Where `windowEnd = lastSlotStartInGroup + durationMinutes`. This gives the intuitive range: "from earliest arrival to when the latest appointment would finish."

Add `windows` array to the get-availability response alongside existing `slots` (no breaking change).

#### Part B: Python tool — Return formatted windows to the LLM
**File:** `livekit-python/tools/google_calendar_check_availability.py`

Replace `return result.get("message", ...)` with logic that reads `result["windows"]` and formats them into natural language:

```
Available on Monday, March 2 (appointments are 90 minutes):
- 9:00 AM to 12:00 PM
- 2:30 PM to 5:00 PM
Any start time within these windows works.
```

The LLM now **only knows about valid start times** and cannot invent times outside the computed windows.

#### Part C: Prompt — Instruct agent to present windows as ranges
**File:** `src/utils.ts`

Update the "AVAILABILITY CHECKING" section (~line 1840) to:
- Present availability as time ranges, not individual 30-min slots
- Example: "We have availability from 9 AM through noon, and again from 2:30 to 5 PM. What time works best?"
- Don't enumerate every 30-minute increment

---

## Bug 2: Agent Speed-Reads Individual Slot Times

### Symptom
Agent says "10, 11 AM, 12 PM, 1 PM, 1:30 PM..." rapidly listing every 30-minute slot. Callers can't process this.

### Root Cause
Same as Bug 1 — even if we passed slot data to the LLM, returning 15+ individual timestamps would cause enumeration. The response needs to be collapsed into contiguous time ranges.

### Fix
Same as Bug 1 — Parts A, B, and C above. The `windows` format naturally produces ranges like "9 AM to noon" instead of listing individual times.

---

## Bug 3: Booking Limits Guard Completely Bypassed (Duplicate Day Bookings Allowed)

### Symptom
Already had an appointment on a day, but the system allowed creating another event on the same day. The guard was supposed to enforce max 1 appointment per calendar day per caller.

### Root Cause
**Field name mismatch** in the Prisma query. The `Appointment` model uses `customerPhone`, but the guard queries the non-existent field `callerPhoneNumber`:

```typescript
// Guard query (server.ts line 12254-12262) — BROKEN
const futureAppointments = await prisma.appointment.findMany({
  where: {
    locationId: locationId,
    callerPhoneNumber: callerPhoneNumber,  // ❌ NOT a field on Appointment model
    status: { not: 'cancelled' },
    date: { gte: now },
  },
  select: { date: true },
});
```

The `Appointment` model (schema.prisma line 138):
```prisma
customerPhone String @map("customer_phone")
```

Prisma throws a runtime error because `callerPhoneNumber` isn't a valid field. The catch block (lines 12287-12290) swallows it as "non-fatal" and continues with event creation:

```typescript
} catch (limitError: any) {
  console.warn(`[google-calendar-create-event] Booking limit check failed (non-fatal): ${limitError.message}`);
  // Continue with creation even if limit check fails  ← bypasses BOTH limits
}
```

Ironically, the appointment *creation* code (line 12617) uses the correct field:
```typescript
customerPhone: callerPhoneNumber || 'Unknown',  // ✅ correct
```

### Fix
**File:** `src/server.ts` (line 12257)

Change:
```typescript
callerPhoneNumber: callerPhoneNumber,
```
To:
```typescript
customerPhone: callerPhoneNumber,
```

This is a one-line fix. Both the max-3-future-appointments AND max-1-per-day guards will start working once the Prisma query succeeds.

---

## Summary of Changes

| File | Change | Fixes |
|---|---|---|
| `src/server.ts` | Add `collapseToWindows()` helper + `windows` field in get-availability response | Bug 1 Part A |
| `src/server.ts` | Fix `callerPhoneNumber` → `customerPhone` in booking limits guard | Bug 3 |
| `livekit-python/tools/google_calendar_check_availability.py` | Return formatted windows to LLM instead of count message | Bug 1 Part B, Bug 2 |
| `src/utils.ts` | Update prompt to instruct presenting availability as ranges | Bug 1 Part C, Bug 2 |

## Testing

After implementing:
1. Call the get-availability endpoint → verify `windows` array in response
2. Agent says "We have availability from X to Y" instead of listing individual times
3. Agent does NOT suggest times that would bleed past closing (e.g., no 4:30 PM for 90-min appointments with 5 PM close)
4. Book an appointment → try booking another on the same day → should get rejected
5. Book 3 appointments → 4th should get rejected
