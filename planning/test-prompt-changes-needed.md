# Test Prompt Changes → Production Prompt Backlog

This file tracks every behavioral change made to the **test prompts** (`livekit-python/tests/prompts.py`) that caused tests to pass, so they can be ported to the **production prompt generation** (`callsaver-api/src/utils.ts` → `generateSystemPrompt()` and `callsaver-api/src/server.ts` → `/internal/agent-config` endpoint).

Each entry documents: what changed in the test, why it works, and exactly where to apply it in production.

---

## Pending Production Changes

*None — all changes applied Feb 26, 2026.*

---

## Applied Production Changes (Feb 26, 2026)

### 1. SAFETY_RULES — Generalized for all 47 business categories + added to base prompt

**What changed:**
- **`utils.ts` `generateSystemPrompt()`** (~line 2170): Added a comprehensive safety block to the BASE prompt (was previously MISSING — only FS-specific modes had safety rules). Covers ALL integration modes and ALL business categories with:
  - General principle: "If someone could be seriously injured or killed RIGHT NOW..."
  - 8 common emergency examples (gas, fire, CO, flooding, structural, chemical, power lines, catch-all)
  - Minor issue clarification: "dripping faucet, slow leak, small cosmetic damage are NOT emergencies"
- **`server.ts`** FS sections (returning + new caller): Replaced the duplicate 5-item safety blocks with a brief reference: "The safety rules in the base prompt above apply here"
- **`prompts.py` test SAFETY_RULES**: Updated to match the new generalized production format

---

### 2. RETURNING CALLERS — Test injection now matches production format

**Test file change:** `NO_INTEGRATION_PROMPT` returning caller section in `prompts.py` + `test_email_collection.py`  
**What changed:**
1. `prompts.py` RETURNING CALLERS section: strengthened to imperative language.
2. `test_email_collection.py`: replaced the raw `RETURNING CALLER INFO ON FILE:` injection with the **exact production format** from `server.ts` line 9312:
```
📞 CALLER INFORMATION (RETURNING CALLER):
- Name: Sarah Connor
- Email: sarah@example.com
- Address: 789 Pine St, Los Gatos, CA 95030

**IMPORTANT - USING CALLER INFORMATION**:
- DO NOT ask for information that is already provided above (name, phone number, email, address)
- If the caller's name is available, use it naturally in conversation - do NOT ask "What's your name?"
```

**Why:** The test's original freeform injection was too weak — the LLM ignored it. The structured production format with `**IMPORTANT**` header and explicit `DO NOT` instructions is what makes it work.

**Production status (reviewed Feb 26): ✅ No change needed.** `server.ts` lines 9312–9326 already use the exact format the test now mirrors. The `**IMPORTANT - USING CALLER INFORMATION**` block is the key driver.

---

### 3. INTAKE FLOW — Add triage/probing step before name collection

**Test file change:** `NO_INTEGRATION_PROMPT` intake flow in `prompts.py`  
**What changed:** Added step 0 before name collection (refined with explicit examples):
```
0. TRIAGE (only if needed): If the caller's request is very vague with NO specifics 
   (e.g., "I need some help", "I need a plumber"), briefly ask what's going on. But if 
   the caller has already described ANY specific symptoms, fixtures, or details 
   (e.g., "my faucet is dripping", "my AC isn't cooling"), acknowledge the issue and 
   skip directly to step 1.
```

**Why:** Without this, the agent jumps straight to "May I have your first and last name?" even for vague requests like "I need some plumbing help."

**Production status (reviewed Feb 26): ✅ Already in production.** `utils.ts` lines 1540–1558 has a full `triageSection` called "SERVICE DETAIL TRIAGE" with explicit WHEN TO PROBE vs WHEN NOT TO examples:
- ✅ PROBE: "I need drain cleaning" → ask what's happening
- ❌ DON'T PROBE: Caller already gave detail → move to intake

This is actually **more detailed** than the test version. No production change needed. The test's step 0 is a simplified version of what production already does.

---

### 4. PATH B / CALLBACK — Call request_callback immediately, don't ask for reason first

**Test file change:** `PATH_B_RULES` in `prompts.py`  
**What changed:** Added explicit instruction:
```
call request_callback immediately with whatever reason is available. Do NOT ask for a reason 
before calling the tool — the reason parameter is optional.
```

**Why:** The agent was asking "Could you please let me know the reason for the callback request?" before calling the tool, causing an extra unnecessary turn and a test failure when `contains_function_call(name="request_callback")` was asserted in the same turn.

**Production status: ✅ APPLIED Feb 26, 2026.**
`server.ts` Path B (line 9829): Changed to "Call the request_callback tool immediately with whatever context you have. Do NOT ask the caller for a reason before calling the tool — infer the reason from the conversation."
`server.ts` Path A (line 9856): Restructured to "Call the request_callback tool immediately with whatever context you have — do NOT ask the caller for a reason before calling the tool. Infer the reason from the conversation."

---

### 5. END CALL — Don't say farewell before calling end_call

**Test file change:** `END_CALL_RULES` in `prompts.py`  
**What changed:** Changed from:
```
say a warm sign-off like "Great, you're all set! Have a wonderful day!" and then call 
the end_call tool to hang up.
```
To:
```
call the end_call tool immediately. Do NOT say a farewell message first — the end_call 
tool will handle the sign-off.
```

**Why:** The `EndCallTool` has `end_instructions="Thank the caller warmly and wish them a great day."` which generates the farewell *after* the tool fires. Telling the LLM to say goodbye first caused it to say goodbye and stop — never calling the tool at all.

**Production status: ✅ APPLIED Feb 26, 2026.**
`utils.ts` CLOSING section (~line 2202): Updated to:
```
CLOSING
- Confirm next step ("I'll have the team confirm parts and call you back").
- The customer's phone number is already available for the callback, so you don't need to repeat it.
- When ending the call, call the end_call tool directly. Do NOT say a farewell
  message first — the end_call tool will handle the sign-off automatically.
```

---

### 6. CURRENT TIME INJECTION — Test-only (already correct in production)

**Test file change:** Added `CURRENT TIME: Wednesday, 10:00 AM` to `NO_INTEGRATION_PROMPT`.  
**Why (tests):** Test prompts had no time context, so the agent couldn't answer "are you open right now?" definitively.

**Production status: ✅ Already done.**  
`callsaver-api/src/server.ts` lines ~9196–9217 already inject `📅 CURRENT DATE AND TIME CONTEXT` with the real timezone-aware timestamp into every system prompt. No action needed.

---

### 7. RECORDING_DISCLOSURE — Remove from system prompt entirely

**Test file change:** Removed `RECORDING_DISCLOSURE` block from all 4 prompt templates in `prompts.py`.  
**What changed:** The block instructed the LLM: *"Your first message MUST include: 'This call may be recorded...'"* — removed entirely.

**Why:** In production, the recording disclosure is delivered via `session.say(firstMessage, allow_interruptions=False)` in `server.py` at line ~1933. The `firstMessage` is built by `buildPersonalizedFirstMessage()` in `utils.ts` and already includes "This call is being recorded for training purposes." Putting this instruction in the system prompt caused the LLM to prepend it to its own responses, overriding returning-caller greetings and generally producing unnatural first turns.

**Where to apply in production:**  
**No change needed to production.** Production is already correct — `firstMessage` handles the disclosure via `session.say()`, not the system prompt. If the recording disclosure line exists anywhere in the production system prompt (`utils.ts` or `server.ts`), **remove it**.

---

## Confirmed Already in Production (no action needed)

- Current date/time injection → `server.ts` lines 9196–9217 ✅
- Returning caller `isReturningCaller` flag and identity injection → `server.ts` lines 9312–9326 ✅
- Returning caller info format (`📞 CALLER INFORMATION` + `**IMPORTANT**` block) → `server.ts` lines 9312–9323 ✅
- Field service customer ID + property pre-loading → `server.ts` lines 9253–9271 ✅
- Triage / probing step (SERVICE DETAIL TRIAGE) → `utils.ts` lines 1540–1558 ✅
- Recording disclosure via `session.say(firstMessage)` not system prompt → `server.py` line 1933 + `utils.ts` `buildPersonalizedFirstMessage()` ✅

---

## All Production Changes Applied ✅

All 7 entries have been reviewed and resolved. 4 were already in production, 3 have been applied:

| # | Change | Status |
|---|--------|--------|
| 1 | Safety rules — generalized for all categories + added to base prompt | ✅ Applied |
| 2 | Returning caller info format | ✅ Already in production |
| 3 | Triage / probing step | ✅ Already in production |
| 4 | Call request_callback immediately | ✅ Applied |
| 5 | End-call — call tool directly, no farewell | ✅ Applied |
| 6 | Current time injection | ✅ Already in production |
| 7 | Recording disclosure via session.say | ✅ Already in production |

Run `pytest tests/ -v` to verify test-production parity.

---

## Prompt Drift Prevention — Shared Fragments

To prevent test prompts from drifting out of sync with production prompts, behavioral rules are now loaded from a **single shared JSON file**:

**File:** `callsaver-api/shared/prompt-fragments.json`

**Consumers:**
- **Production:** `src/utils.ts` → `generateSystemPrompt()` reads via `promptFragments.safety_rules`, `promptFragments.agent_identity`, `promptFragments.escalation_rules`
- **Tests:** `livekit-python/tests/prompts.py` → loads via `json.loads()` from `shared/prompt-fragments.json`

**Shared fragments (3):**
| Fragment | Description |
|----------|-------------|
| `safety_rules` | Full safety hazard block — generalized for all 47 business categories |
| `agent_identity` | AI identity disclosure rules |
| `escalation_rules` | When to escalate to a human |

**Not shared (test-specific):**
- `BUSINESS_INFO` — mock business data for tests
- `END_CALL_RULES` — test has detailed step-by-step; production has simpler CLOSING section
- `EMAIL_COLLECTION_RULES` — production has mode-specific (required/optional) logic
- `PROMOTIONS`, `FAQ_SECTION`, `BRANDS_SECTION`, `POLICIES_SECTION` — mock data
- `PATH_B_RULES`, `INTAKE FLOW` — test-condensed versions of larger production sections

**How to update behavioral rules:**
1. Edit `shared/prompt-fragments.json`
2. Both production and tests automatically pick up the change
3. Run `pytest tests/ -v` to verify
