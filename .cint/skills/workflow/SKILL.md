---
name: workflow
description: Show where you are in the development cycle and suggest the next step. Checks for CONTEXT.md, ADRs, PRDs, issues, tests, and review artifacts to determine what's done and what to do next. Use when the user says "what next", "where am I", "what should I do now", "workflow", "next step", or seems unsure which skill to invoke.
argument-hint: "[optional: what you're trying to do]"
---

# Workflow — Development Cycle Guide

Scan the project for artifacts from the engineering skills and show the user where they are in the development cycle. Recommend the next skill to invoke. **This skill only reads and suggests — it never enforces or blocks.**

## The cycle

```
SETUP  →  ALIGN  →  MAP (brownfield)  →  PROTOTYPE (optional)  →  SPECIFY  →  BREAK DOWN  →  TRIAGE  →  IMPLEMENT  →  REVIEW  →  HANDOFF
                                                                                              ↑              │
                                                                                              └── DIAGNOSE ──┘ (if broken)
```

## Detection

For each phase, check for these artifacts. Order matters — stop at the first incomplete phase and suggest it.

### 0. SETUP — `/setup-matt-pocock-skills`

Check: `docs/agents/issue-tracker.md` OR `docs/agents/triage-labels.md`
If missing → suggest `/setup-matt-pocock-skills`

### 1. ALIGN — `/grill-with-docs`

Check: `CONTEXT.md` at repo root (or `CONTEXT-MAP.md`)
If missing → suggest `/grill-with-docs`

### 2. MAP (brownfield, optional) — `map-codebase`

Check: `docs/codebase/STACK.md` (or the full seven-doc set)
If substantial existing code but no map → suggest `map-codebase` before large planning or refactor work. Skip for greenfield or tiny repos.

### 3. PROTOTYPE (optional) — `/prototype`

This is a judgment call. If the user's description involves uncertain state machines, data models, or UI design, suggest `/prototype` to sanity-check before specifying. If the domain is well-understood, skip this phase.

Check: look for files named `*.prototype.*`, `prototype/`, or recent throwaway branches. If found, mark as done.

### 4. SPECIFY — `/to-prd`

Check for a PRD. Look in order:
1. A GitHub issue labeled `prd` or `spec` (if issue tracker is GitHub)
2. `docs/prd.md`, `docs/spec.md`, `specs/`, `.scratch/prd.md`
3. Ask the user if they have a PRD somewhere else

If no PRD found → suggest `/to-prd`

### 5. BREAK DOWN — `/to-issues`

Check: GitHub/Linked issues that reference the PRD, OR issues in `docs/agents/issue-tracker.md`'s configured tracker with implementation-focused titles.
If no implementation issues found → suggest `/to-issues`

### 6. TRIAGE — `/triage`

Check: Are the implementation issues labeled/prioritized?
Look for issue labels matching the triage label vocabulary in `docs/agents/triage-labels.md`.
If issues exist but aren't labeled → suggest `/triage`

### 7. IMPLEMENT — `/test-driven-development`

Check: Tests exist for the next untriaged/untested issue.
Look for test files that correspond to the issues. Use `git log` to find recent test commits.
If tests are missing for the next issue → suggest `/test-driven-development` with the issue number.

### 8. REVIEW — `code-review`

Check: Unreviewed changes since last review point.
Run `git log --oneline -20` and look for review mentions in commit messages, or review artifacts in `_workspace/review/`.
If recent commits aren't reviewed → suggest the `code-review` skill.

### 9. HANDOFF — `/handoff`

If all phases are complete or the user wants to pass work to another session, suggest `/handoff`.

### ANY POINT — `/diagnose`

If the user mentions something is broken, skip the phase check and suggest `/diagnose`.

### PERIODIC — `/improve-codebase-architecture`

Every few days of active development, suggest `/improve-codebase-architecture` as a health check. Track this by checking the date of the last deepening report (look for `DEEPENING-REPORT.md` or similar).

## Output format

```
## Where you are

✅ SETUP    — docs/agents/issue-tracker.md exists
✅ ALIGN    — CONTEXT.md exists (12 terms, 3 ADRs)
⬚ PROTOTYPE — skipped (domain well-understood)
⬚ SPECIFY  — no PRD found
⬚ BREAK DOWN
⬚ TRIAGE
⬚ IMPLEMENT
⬚ REVIEW

## Next step

Run `/to-prd` to turn the current conversation into a formal PRD.
```

Use `✅` for done, `⬚` for not done, `⏭` for skipped, `⚠` for stale/needs update.

If all phases are done, end with: `All phases complete. Run /handoff to pass to another agent, or start a new cycle with /grill-with-docs.`

## Edge cases

- **Mid-implementation**: If tests exist but aren't passing, the IMPLEMENT phase is in progress. Don't suggest REVIEW yet. Suggest continuing `/test-driven-development`.
- **No repo at all**: If there's no git repo or the directory is empty, suggest starting at SETUP.
- **User provides a goal**: If the user says "I want to build X", check if ALIGN is done first. If not, suggest `/grill-with-docs` before anything else.
- **Multiple issues in progress**: List them. Suggest `/test-driven-development` for the highest-priority untested one.
- **Only some issues have tests**: Mark IMPLEMENT as partially done. Show which issues have tests and which don't.

## What this skill does NOT do

- Does NOT invoke other skills automatically
- Does NOT prevent the user from jumping ahead
- Does NOT require phases to be completed in order
- Does NOT create any files or modify the repo
