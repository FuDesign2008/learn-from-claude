---
name: coding-workflow
version: "2.0.0"
user-invocable: true
description: >
  Four-phase gated coding workflow (Explore → Plan → Execute → Verify).
  Encodes the actual reasoning discipline of top-tier models, not the
  idealized version. Trigger: any task involving code creation, modification,
  or refactoring. Also invoked automatically by task-router.
---

# Coding Workflow — Four-Phase Gate

> The gap between good and bad code changes is almost never about writing
> skill. It is about what you read before you write, and what you check
> after. This workflow makes the invisible discipline visible.

## The Core Rules

1. **No file edits before Phase 3.** Not even "quick fixes."
2. **Each phase produces an explicit output.** Thinking it is not enough — state it.
3. **Backwards movement is expected.** Discovering in Phase 2 that you need more from Phase 1 is a sign of good judgment, not failure.

---

## Phase 1 — EXPLORE (Read-Only)

**Goal**: Understand the actual code, not the code you imagine exists.

### The Three Things You Always Check First

1. **The code you will change** — read the full function/module, not just the line. Context above and below the target is where the constraints hide.
2. **Every caller** — use LSP references or grep. The number of call sites determines whether your change is a simple edit or a migration. This is the single most-skipped step by weaker models: they change a function signature without knowing who calls it.
3. **The test file** — if it exists. Tests reveal the original author's contract assumptions. If there are no tests, that itself is critical information (your change has no safety net).

### What Weaker Models Fail to Look Up

**The return type contract.** Weaker models read the function body but not how callers consume the return value. If you change what a function returns — even adding a field to an object — you must know what callers destructure, what they pass downstream, and what shape they expect. Grep for the function name, then read 3-5 lines *after* each call site.

### What "Enough Exploration" Looks Like

You are done exploring when you can answer: "If I make this change, what will break?" If you cannot answer that concretely, you have not read enough.

**Output** (state before moving to Phase 2):
```
EXPLORE COMPLETE
Files to modify: [list]
Call sites: [N total — list with file:line]
Tests: [exist / do not exist / partial]
Key constraint: [the one thing that most limits how you can make this change]
Risk: [what could break]
```

**Hard constraints**:
- NO edits. NO "let me just fix this typo while I'm here."
- NO assumptions about code you have not read. "It probably works like X" is not exploration.
- If you find the codebase uses a pattern you did not expect (e.g., dependency injection, event bus, plugin system), stop and understand the pattern before proceeding.

---

## Phase 2 — PLAN (Read-Only)

**Goal**: Produce a change list specific enough that you could hand it to someone else to execute.

### What Makes a Plan "Good Enough"

A plan is executable when every item answers three questions: **what file**, **what change**, and **why this order**. A plan that says "update the component" is a wishlist. A plan that says "in `UserCard.tsx`, add an `isActive` prop with default `true`, threading it through the existing `className` conditional on line 34" is executable.

### The Modification Order Matters

Change leaf dependencies before their consumers. If you edit a utility function and its caller in the wrong order, you create a window where the code is inconsistent — and if diagnostics run between edits, you get false failures that waste your attention.

### When to Return to Phase 1

Go back to Explore if:
- You cannot specify the exact change for a file (you don't understand it well enough)
- You realize the dependency graph is deeper than you thought
- You discover a pattern (factory, registry, etc.) that your planned approach would violate

This is not failure. This is the plan telling you it needs more information.

**Output** (state before moving to Phase 3):
```
PLAN COMPLETE
Changes (in order):
  1. [file:line-range] — [exact change] — [why]
  2. [file:line-range] — [exact change] — [why]
Ordering rationale: [why this sequence]
Out of scope: [things you noticed but will NOT change]
```

**Hard constraints**:
- NO edits in this phase.
- The plan must explicitly state what is OUT of scope. This is your defense against scope creep in Phase 3.
- If the plan has more than ~8 steps, consider whether you are doing too much at once. Ask the user if the change should be split.

---

## Phase 3 — EXECUTE (Read-Write)

**Goal**: Implement the plan. When you discover something unexpected, decide: adjust the plan or flag it for later. Do not silently expand scope.

### Scope Discipline

The hardest discipline here is resisting "while I'm here" edits. You will see adjacent code that could be improved — a variable with a bad name, a missing null check, a comment that is wrong. **Do not fix it** unless it is in your plan. Add it to the "Out of scope" list. The reason is not ideological purity; it is that unplanned edits are unverified edits, and unverified edits are where bugs come from.

### When You Discover Something Unexpected

Three possible responses, in order of preference:
1. **It fits within the plan's intent** — minor adaptation, continue. Example: a call site uses a slightly different argument pattern than you expected, but the fix is obvious.
2. **It changes the plan materially** — STOP. State what you found. Return to Phase 2 and amend the plan. Example: you discover the function is also called via dynamic dispatch and your grep missed it.
3. **It is a separate problem** — note it, continue with your plan. Example: you find a pre-existing bug unrelated to your change.

### Execution Mechanics

- Follow the plan's order.
- After each file edit: run LSP diagnostics on that file if available. Fix errors immediately — do not accumulate them.
- Match existing code style exactly. If the codebase uses `snake_case`, you use `snake_case`. If it uses explicit `return` in single-line arrows, you do too. Your edit should be invisible in a `git blame`.

**Hard constraints**:
- NO changes outside the plan scope.
- NO `any`, `@ts-ignore`, `eslint-disable`, or equivalent to silence errors your change introduced.
- NO empty catch blocks.
- If an edit tool fails, apply the `file-operation-fallback` skill.

---

## Phase 4 — VERIFY (Read-Only)

**Goal**: Produce evidence that the change is correct. "I re-read my code and it looks right" is not verification.

### What Verification Actually Means

Verification is checking your work against something external to your own reasoning:
- **Type checker output** — not your mental model of types
- **Test results** — not your belief that tests would pass
- **Actual call site behavior** — not your assumption that callers are fine

### The Minimum Viable Verification

Even under time pressure, you must do ALL of these:
1. **Run diagnostics** (`tsc --noEmit`, `lsp_diagnostics`, or equivalent) on every changed file. Read the output.
2. **Re-read each changed file** — not to admire your work, but to check that the diff does what the plan said.
3. **Verify call site consistency** — re-check that every caller of modified functions/types still works. This catches the most common class of bug: you changed a contract and missed a consumer.

### Full Verification (When Available)

- Run the test suite. Read failures, do not just count them.
- Trace one concrete execution path through the changed code with a realistic input.
- Check edge cases: what happens with empty input, null, the zero case?

**Output** (required before declaring done):
```
VERIFICATION REPORT
─────────────────────────────────────
Diagnostics        : PASS / FAIL — [ran on N files, 0 errors]
Diff matches plan  : YES / NO — [any deviations noted]
Call sites          : [N] checked, all consistent
Tests              : PASS / FAIL / NOT RUN — [reason]
Edge cases checked : [list 2-3]
─────────────────────────────────────
VERDICT: PASS / FAIL / PARTIAL
```

If VERDICT is FAIL or PARTIAL: return to Phase 3 with specific fixes, then re-run Phase 4. Do not declare done.

---

## Few-Shot Reference: What Goes Wrong Without This Workflow

### Example: Renaming a TypeScript interface field

**Task**: Rename `UserProfile.userName` to `UserProfile.displayName` across the codebase.

**❌ What actually goes wrong without the workflow**

The model greps for `userName`, finds 12 matches, renames them all. Ships it.

The bug: 3 of those 12 matches were `userName` on a *different* interface (`AuthPayload.userName`). The model renamed those too, breaking authentication. It also missed 2 call sites that accessed the field via bracket notation (`profile["userName"]`) because grep for `.userName` does not match bracket access. And it missed 1 site that destructured with aliasing: `const { userName: name } = profile`.

**✅ What this workflow catches**

*Phase 1 — Explore*: Uses LSP "find references" on the `userName` field of the `UserProfile` interface specifically (not a text grep). Finds 9 true references. Separately notes that `AuthPayload` has its own `userName` field — this must NOT be renamed. Checks for bracket access patterns: finds `profile["userName"]` in `legacy-adapter.ts:47`. Checks for destructuring: finds `const { userName: name }` in `format-user.ts:12`.

```
EXPLORE COMPLETE
Files to modify: UserProfile.ts, dashboard.tsx, settings.tsx, api-client.ts,
                 legacy-adapter.ts, format-user.ts, user-card.tsx, profile-page.tsx, user.test.ts
Call sites: 9 total (7 dot access, 1 bracket access, 1 destructuring alias)
Tests: exist in user.test.ts — 4 tests reference userName
Key constraint: AuthPayload.userName must NOT be touched
Risk: bracket notation and destructured aliases are invisible to naive grep
```

*Phase 2 — Plan*: Orders changes interface-first (change the definition, then let LSP errors guide remaining sites). Explicitly lists the bracket-access and destructuring cases. States out-of-scope: AuthPayload.userName.

*Phase 3 — Execute*: Renames the interface field first. Runs diagnostics — TypeScript reports 8 errors across 7 files (the 9th site used an alias so no TS error). Fixes all 8 reported errors. Manually fixes the destructured alias in `format-user.ts`. Runs diagnostics again: 0 errors.

*Phase 4 — Verify*: Diagnostics clean. All 9 call sites confirmed renamed. `AuthPayload.userName` confirmed untouched. Tests: runs `user.test.ts` — all pass after updating test assertions. Searches for any remaining string literal `"userName"` — finds none related to UserProfile. VERDICT: PASS.

**The insight**: text-based grep for renames is fundamentally broken. It over-matches (different types with the same field name) and under-matches (bracket access, destructuring, string interpolation). LSP references are type-aware and catch exactly the right set. The Explore phase is where you make this choice, and it determines whether the entire change succeeds or fails.

---

## Refactoring-Specific Rules

When the task is a refactor (not a bug fix, not a feature):

1. **One concern at a time** — rename in one pass, restructure in another, never both
2. **Behavior must be identical** — if behavior changes, stop and flag it. It is no longer a refactor.
3. **Tests must pass before AND after** — if tests do not exist, state this as a risk to the user before proceeding
4. **Preserve git blame utility** — avoid reformatting lines you did not semantically change
