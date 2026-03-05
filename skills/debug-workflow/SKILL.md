---
name: debug-workflow
version: "2.0.0"
user-invocable: true
description: >
  Systematic debugging protocol: root-cause identification before any fix,
  hypothesis-driven investigation, and structured failure recovery. Prevents
  the most common failure mode of weaker models — applying random fixes and
  hoping something works. Trigger: bug, error, crash, broken, wrong output,
  not working, unexpected behavior. Also invoked automatically by task-router.
---

# Debug Workflow — Root-Cause First

> The gap between weak and strong debugging is not intelligence — it is
> **patience**. Weak models guess and patch. Strong models trace and understand.

## The Core Rule

**You may not modify any file until you have identified the root cause.**

A symptom is not a root cause. A guess is not a root cause. You need to point
at a specific line and explain the precise mechanism by which it produces the
wrong behavior.

---

## Phase 1 — REPRODUCE

**Goal**: Establish the concrete gap between actual and expected behavior.

"I read the bug report" ≠ "I reproduced the bug." The report gives the user's
interpretation. Reproduction gives the actual behavior. These often differ.

**Minimum bar to proceed** — you must have EITHER:
- Run the failing code and observed the exact output, OR
- Traced the code mentally with exact inputs and confirmed the failure path

**Output**:
```
REPRODUCTION
Input:    [exact trigger]
Actual:   [exact wrong behavior]
Expected: [what should happen]
Deterministic: YES / NO — [conditions if NO]
```

Cannot reproduce → STOP. Ask for a minimal reproduction. Do not proceed on a
description alone — you will build hypotheses on sand.

---

## Phase 2 — LOCATE

**Goal**: Find the first point where execution diverges from correctness.

This is where most debugging fails. The mistake is almost always **stopping
too early** — you find where the error manifests and assume the bug lives there.

**Work backward in layers**:
1. **Start at the symptom**: identify the line producing the error/wrong output
2. **Ask "why is this value wrong?"**: trace where the bad value came from — a
   parameter? a return value? a module-level variable?
3. **Cross the boundary**: follow the bad value to its origin — often a
   *different* file or layer. This is the step weak models skip.
4. **Keep going until you reach where the INTENT is wrong**, not just the VALUE.
   The root cause is where the programmer's assumption broke, not where the
   runtime complained.

**Common mistakes**: stopping at the crash site instead of tracing why the value
was wrong three calls earlier; looking only in the reported file; blaming the
library before ruling out your own code; grep-ing the error message instead of
tracing data flow.

**Output**:
```
LOCATION
Symptom location:    [file:line — where the error surfaces]
Root cause location: [file:line — where the actual mistake is]
Causal chain:        [A → B → C — how the bad value propagates]
```

If symptom and root cause are the same line, you probably haven't traced far
enough.

---

## Phase 3 — HYPOTHESIZE

**Goal**: State a precise, falsifiable explanation of why the bug exists.

**Good hypothesis**: names a specific mechanism, makes a testable prediction,
explains ALL observed symptoms (not just some).

**Bad hypothesis**: vague attribution ("state management issue"); blaming
external code without evidence; explaining the symptom not the cause ("it
crashes because the value is null" — WHY is it null?); fitting only some
symptoms.

**Confidence calibration**:
- **HIGH**: read the code path end-to-end, can point at the exact line,
  mechanism explains all symptoms
- **MEDIUM**: plausible mechanism, one unverified link in the chain
- **LOW**: have a direction, haven't traced the full path

```
HYPOTHESIS
Root cause: [specific mechanism]
Evidence:   [what supports this]
Predicts:   [what else should be true if correct]
Confidence: HIGH / MEDIUM / LOW
```

LOW → go back to Phase 2. MEDIUM → acceptable only if further tracing is
impractical. Prefer HIGH before fixing.

---

## Phase 4 — FIX

**Goal**: Apply the minimal change that addresses the root cause. Nothing more.

**Scope-creep signals** (stop immediately if you notice these):
- Renaming variables not involved in the bug
- Restructuring control flow for "clarity" beyond the fix
- Adding features ("this function should also handle...")
- Diff touches files not in the causal chain
- You think "while I'm at it"

**Hard constraints**:
- NO suppressing errors (catch-and-ignore, `?.` chains hiding null origins)
- NO defensive fallbacks masking the bug (`|| default` without understanding
  why the value is missing)
- NO `any` / `@ts-ignore` / equivalent type escapes
- If behavior changes for other callers, document it explicitly
- Non-obvious fix → add comment: `// Fix: [mechanism in one line]`

---

## Phase 5 — VERIFY

**Goal**: Confirm the fix is correct, not just that the symptom disappeared.

"It works now" ≠ "it is fixed." A suppressed error also makes symptoms vanish.
Verification must confirm the MECHANISM is addressed.

**Mandatory checks**:
1. Original failure from Phase 1 → confirm it passes
2. Two adjacent cases (boundary values, the "other branch" of your fix)
3. Existing tests (or manual check of normal behavior if no tests)
4. Call-site audit: other callers affected by the behavior change?

```
VERIFICATION
Original case  : PASS / FAIL
Adjacent case 1: PASS / FAIL — [what]
Adjacent case 2: PASS / FAIL — [what]
Existing tests : PASS / FAIL / NOT AVAILABLE
Other callers  : UNAFFECTED / AFFECTED — [details]
VERDICT: PASS / FAIL
```

FAIL → return to Phase 2, not Phase 4. Failed verification means your
understanding is wrong, not just your fix.

---

## Failure Recovery

### After 2 failed fixes on the same hypothesis

Your hypothesis is wrong. The most common trap: you found a real problem, but
it's not THE problem. The thing you're fixing is genuinely imperfect, but it
doesn't cause this specific symptom. This is the "real but irrelevant bug" trap.

**Required**: abandon the hypothesis entirely.
```
HYPOTHESIS INVALIDATED
Tried:         [what you attempted]
Why wrong:     [why it didn't fix the symptom]
New direction: [hypothesis from a DIFFERENT root cause category]
```

### After 3 cumulative failures

**Stop all edits.** Three failures means: missing context (runtime state you
can't see), wrong layer (build system, bundler, environment), or fundamentally
wrong mental model of the system.

**Required**: revert all changes, report:
```
BLOCKED — 3 attempts failed
  1. [approach] → [result]
  2. [approach] → [result]
  3. [approach] → [result]
What I know:      [confirmed facts]
What I'm missing: [specific unknowns]
To proceed:       [concrete ask]
```

---

## Few-Shot Reference

### Example: "User profile updates are lost intermittently"

**❌ Weak model**: reads `updateProfile`, sees `db.save(user)` (already
awaited), adds error logging, declares fixed. Bug persists.

**✅ This workflow**:

**Phase 1**: Update returns 200 with correct data, but old data reappears on
refresh. ~1 in 3 updates lost. API response is correct. Deterministic: NO.

**Phase 2**: GET returns stale data. Trace: GET reads from `userCache.get(id)`
first, falls back to DB. `updateProfile` writes to DB then invalidates cache.
But a `refreshCache` background job runs every 5s. The DB write uses a deferred
transaction — commits AFTER the handler returns. So the sequence is: (1) write
to DB buffer, (2) invalidate cache, (3) transaction commits. If `refreshCache`
fires between steps 2 and 3, it reads uncommitted (old) state and populates
cache with stale data.

```
LOCATION
Symptom:     GET /api/user/:id returns stale cached data
Root cause:  cache invalidation runs BEFORE transaction commit
Chain:       write DB buffer → invalidate cache → refreshCache reads
             uncommitted old data → repopulates cache → commit (too late)
```

**Phase 3**: Cache invalidation fires before DB commit; the background refresh
job can read uncommitted state during this window. Explains intermittency
(depends on refreshCache timing) and correct API response (reads write buffer,
not cache). Confidence: HIGH.

**Phase 4**: Move cache invalidation into the transaction's `afterCommit` hook.
One line moved, one hook added.

**Phase 5**: 50 rapid updates, 0 lost. Concurrent sessions: both reflected.
Server restart mid-update: cache rebuilt correctly. Tests: PASS. VERDICT: PASS.

**Why weak models fail here**: `updateProfile` looks correct in isolation — it
writes and invalidates properly. The bug lives in the *interaction* between
three components (handler, transaction middleware, background job). You only
find it by tracing across module boundaries.
