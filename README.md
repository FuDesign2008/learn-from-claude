# learn-from-claude

Steal behavior patterns from top-tier models (claude-opus-4, etc.) and make them work for weaker models via explicit workflow skills.

## The Problem

Top-tier models like claude-opus-4 implicitly:
- Explore code before touching it
- Plan changes before executing them
- Identify root causes before fixing bugs
- Verify outputs before declaring done

Weaker models skip these steps. This repo closes the gap with structured skills.

## Skills

| Skill | Trigger | What it does |
|---|---|---|
| `task-router` | Always (auto) | Classifies every task, injects the right workflow |
| `coding-workflow` | Code changes | Four-phase gate: Explore → Plan → Execute → Verify |
| `debug-workflow` | Bug fixes | Root-cause-first debugging with failure recovery |
| `distill-session` | "distill" / "偷师" | Mines top-tier model behavior, saves as reusable rules |

## Install

```bash
./install.sh
```

This creates symlinks in `~/.claude/skills/` (claude code) and `~/.config/opencode/open-skills/skills/` (opencode).

```bash
./install.sh --dry-run    # preview without changes
./install.sh --uninstall  # remove symlinks
```

## Auto-Activation

`task-router` runs automatically on every task — no trigger word needed. Add this to your `~/.claude/CLAUDE.md`:

```markdown
## Auto-activated Skills
- task-router: Classifies every task and injects the appropriate workflow scaffold.
  This skill is always active. No trigger word required.
```

The other three skills are invoked by `task-router` automatically based on task type, or can be triggered manually.

## Distill Workflow (The Core Loop)

When a weaker model fails at a task:

1. Save the failure to `failure-cases/YYYY-MM/`
2. Run `distill-session` skill
3. Use the extraction prompt with a top-tier model
4. Save distilled rules to `distilled-patterns/`
5. Update the relevant skill
6. Validate the fix

Over time, the pattern library grows and the weaker model's behavior converges toward the top-tier model's.

## Repository Structure

```
learn-from-claude/
├── skills/
│   ├── task-router/        # Auto-classifier, always active
│   ├── coding-workflow/    # Four-phase coding gate
│   ├── debug-workflow/     # Root-cause debugging
│   └── distill-session/    # Pattern extraction workflow
├── distilled-patterns/     # Rules extracted from top-tier models
│   ├── code-change.md
│   ├── bug-fix.md
│   └── ...
├── failure-cases/          # Logged weak-model failures
│   └── YYYY-MM/
└── install.sh
```
