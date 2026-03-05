---
name: distill-session
version: "2.0.0"
user-invocable: true
description: >
  Structured extraction of implicit reasoning from top-tier model sessions
  into explicit, reusable rules for weaker models. Use when a weaker model
  fails a task, when you want to mine a successful session for transferable
  patterns, or when you notice a gap between what you did and what you could
  explain. Trigger: "distill", "extract pattern", "why did opus do that",
  "learn from", "what did I do differently".
---

# Distill Session — Extract What You Can't Yet Explain

> The most valuable knowledge in a top-tier model's output is the knowledge
> it applied without mentioning. This skill makes that invisible reasoning
> visible, testable, and transferable.

## The Core Insight

When a weaker model fails, the gap is almost never "it didn't try hard
enough." The gap is that the top-tier model executed steps it doesn't
consciously report — constraint checks it ran silently, orderings it chose
without deliberation, failure modes it avoided by reflex. These implicit
behaviors are the extraction target.

**The hard part is not getting the top-tier model to succeed. It's getting
it to notice what it did that was non-obvious.**

---

## When to Use

- A weaker model produced wrong or shallow output on a task you handle well
- You completed a complex task and want to mine it for transferable rules
- A skill (coding-workflow, debug-workflow, task-router) needs strengthening
- You notice yourself doing something you can't fully articulate yet

**Distill immediately after completing a complex task** — don't wait for a
failure to trigger this. Your reasoning is still warm.

---

## Phase 1 — CAPTURE

**Goal**: Preserve exact failure and success before analysis distorts them.

Save to `.omc/distill-sessions/YYYY-MM-DD-[short-title].md`:

```markdown
# Distill: [short title]
Date: YYYY-MM-DD | Task type: code-change / bug-fix / refactor / review

## The Task
[Exact prompt — verbatim]

## Weak Model Output
[Exact output — do NOT paraphrase. Preserve reasoning chain if visible.]

## What Went Wrong (Observable)
[Concrete defects: wrong file, missing call site, incorrect assumption.]

## Top-Tier Model Output
[Your actual output.]
```

**Critical**: Paste the weak model's FULL output. Phase 3 requires
comparing actual text, not your memory of it.

---

## Phase 2 — THE EXTRACTION (Core of This Skill)

**Goal**: Surface the implicit reasoning that made the difference.

This is where most distillation fails. Generic "what steps did you take?"
gets cleaned-up narratives, not actual reasoning. The questions below
bypass post-hoc rationalization to reach real decision points.

### The Extraction Prompt

Answer with ruthless honesty. Do not clean up your reasoning or make it
sound more systematic than it was.

```
<extraction>

## 1. What did I look at before I started doing anything?
[Specific files, symbols, docs you read BEFORE any change. Include
things you glanced at and decided weren't relevant. Weaker models
start acting before this step is complete.]

## 2. What did I almost do wrong, then correct?
[Any moment you began one approach, noticed a problem, pivoted.
These near-misses reveal constraints you check implicitly. A weaker
model would have followed through on the wrong approach.]

## 3. What information was I holding in my head simultaneously?
[Facts, constraints, relationships tracked at the same time. Example:
"function X called from 3 places, return type used as discriminated
union downstream, one call site in a hot path." Weaker models handle
these serially or drop some.]

## 4. Where did I choose to NOT do something?
[Restraint is invisible. Skipped refactors? Edge cases not worth
handling? Suppressed "while I'm here" changes? Weaker models often
fail by doing too much, not too little.]

## 5. What ordering did I choose and why?
[Dependency reason? Safety reason? Would a different order cause
problems? Weaker models edit in prompt-order rather than
dependency-order.]

## 6. What would break if I removed any single step?
[Steps where removal causes failure are essential. Steps where
removal doesn't matter were optional.]

## 7. What is the simplest incorrect version of my output?
[The most plausible wrong answer — ~80% understanding of the task.
Usually what the weak model produced. Name the specific 20% gap.]

## 8. Write the instruction set (3-7 rules)
[Each rule must be:
- Actionable in a single step (no "think carefully about X")
- Verifiable by a third party (someone can check if it was done)
- Triggered by an observable condition (not "when appropriate")]

</extraction>
```

### Why These Questions Work

| Question | Surfaces | Generic prompts miss |
|----------|----------|---------------------|
| What I looked at first | Exploration scope | Models report actions, not reads |
| What I almost did wrong | Live constraint checking | Post-hoc narratives erase near-misses |
| Info held simultaneously | Working memory load | Serial descriptions hide parallel reasoning |
| Chose NOT to act | Restraint, scope control | Success stories omit inaction |
| Ordering chosen | Dependency awareness | "I did A then B" without why |
| What breaks without step | Essential vs. optional | Models pad with extra steps |
| Simplest wrong version | The actual failure mode | "What could go wrong" too open-ended |

---

## Phase 3 — DELTA ANALYSIS (Most Error-Prone Phase)

**Goal**: Identify which behaviors CAUSED the quality difference.

The common mistake: attributing success to the most impressive-looking step
rather than the step that actually mattered.

### The Attribution Test

For each behavior from Phase 2:

1. **If the weak model did THIS ONE THING, would it have succeeded?**
   Yes → candidate root cause. No → contributing factor at best.

2. **Did the weak model lack ABILITY or PROMPTING?**
   Ability gap → needs a tool, not a rule. Prompt gap → extractable.

3. **Specific to this task, or generalizable?**
   Specific → useful as example. General → candidate pattern.

### Common Mistakes

| Mistake | Fix |
|---------|-----|
| "I understood better" | What SPECIFIC thing did you read that the weak model didn't? |
| Sequence ≠ causation | Would swapping the order alone have fixed it? |
| Overgeneralizing ("read everything") | WHICH files? What was the selection criterion? |
| Undergeneralizing ("check discriminated unions") | General principle: "check downstream consumers of modified types" |
| Survivorship bias | Remove each step mentally. Which removals cause failure? |

### Output

```markdown
## Delta Analysis
Root cause: the weak model failed because it ___
Minimum fix: [single most impactful rule]
Contributing factors: 1. [behavior] — [impact] 2. [behavior] — [impact]
Non-essential steps I took: [prevents rule bloat]
```

---

## Phase 4 — DISTILL INTO RULES

Every rule must pass ALL FIVE criteria:

| Criterion | Bad | Good |
|-----------|-----|------|
| **Actionable** (one step) | "Be thorough" | "Grep for all call sites before modifying" |
| **Verifiable** (checkable) | "Consider edge cases" | "List 3 edge cases, trace each through code" |
| **Triggered** (when exactly) | "When modifying code" | "When adding a parameter to an exported function" |
| **Minimal** (no extra words) | Paragraph with examples | One sentence, one action |
| **Causal** (addresses root cause) | "Read more code" | "Read all files that import the module you're changing" |

**The causality check**: "If the weak model followed ONLY this rule and
changed nothing else, would the output improve?" Yes → keep. No → delete.
Maybe → make more specific.

Save to `.omc/distill-sessions/patterns/[task-type].md`:

```markdown
### Rule [N]: [short name]
**Trigger**: [Observable condition]
**Action**: [Single concrete instruction]
**Because**: [What goes wrong without it]
**Test**: [How to verify it was followed]
```

---

## Phase 5 — INTEGRATE

Propagate rules into the skills that govern the behavior:

| Rule targets... | Update... |
|---|---|
| What to read before coding | coding-workflow Phase 1 |
| Change ordering | coding-workflow Phase 2 |
| Implementation discipline | coding-workflow Phase 3 |
| Verification | coding-workflow Phase 4 |
| Root cause identification | debug-workflow / systematic-debugging |
| Task classification | task-router |

Bump target skill version (patch: 1.0.0 → 1.0.1).

---

## Phase 6 — VALIDATE

**The real question**: Does this rule produce CORRECT output, or just
BETTER-LOOKING output?

"Explain your reasoning before acting" makes outputs look thoughtful
without improving correctness. "Grep for all call sites before modifying
a function signature" produces measurably different output. Target the
latter.

1. Re-run EXACT original task with weaker model + updated skill
2. Compare on the specific dimension that failed, not overall quality

```markdown
## Validation
Original failure: [what was wrong]
After distillation: [is that specific thing correct now?]
VERDICT: FIXED / BETTER BUT STILL WRONG / NO CHANGE / REGRESSION

If not FIXED — was Phase 3 wrong? Re-examine root cause.
```

**BETTER BUT STILL WRONG** → rule addresses symptom, not cause. Redo Phase 3.
**NO CHANGE** → rule not triggered, or action beyond model capability.

---

## Quick Reference: Copy-Paste Extraction Prompt

The single most important artifact. Use immediately after completing a task.

```
You just completed a task. Before moving on, fill in this extraction
honestly — especially the parts that feel embarrassing or obvious.

<extraction>
## What I looked at before acting
## What I almost did wrong, then corrected
## What I was holding in my head simultaneously
## What I chose NOT to do
## What ordering I chose and why it mattered
## What would break if I skipped any single step
## The simplest plausible wrong answer to this task
## Rules for a weaker model (3-7, each one sentence, each verifiable)
</extraction>
```
