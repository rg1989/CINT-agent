---
name: creating-agentic-loops
description: Use when setting up a self-running or autonomous agent workflow — an agentic loop, a "keep doing X until Y" / run-until-done task, a recurring or scheduled agent (cron, nightly, every-N-min, /loop, /schedule), or any iterate-until-a-quality-bar automation; also when a long-running agent task risks running forever, drifting, or burning tokens with no clear stop.
---

# Creating Agentic Loops

## Overview

An **agentic loop** is a workflow with four parts: a **defined entry condition**, a **bounded action**, a **verification gate**, and an **explicit stop**. The stop is what makes it a loop and not a runaway: *"a loop without a stop condition is just a hole."*

Capable agents already iterate-and-verify by reflex. This skill adds the parts they *don't* reliably bring: a single canonical shape, the right **execution mode** (and its wiring), and a catalog of **proven loop patterns** to copy instead of reinventing. Reach for [loop-catalog.md](loop-catalog.md) to match a goal to a named loop.

## The five principles (every loop has all five)

1. **Defined stop condition** — explicit halt criteria (bar met, budget gone, streak achieved, reviewer verdict).
2. **Verification gate** — objective proof before accepting an outcome (passing tests, benchmark, approval). Never self-judged.
3. **Bounded action** — one focused change per iteration: auditable and rollback-safe.
4. **Honest terminal state** — reports `done` / `blocked` / `stalled` / `exhausted`, never an errored run as success.
5. **Resumable state** — a persistent state file so interruption ≠ reset.

## The loop template

Fill every slot. A missing **Stop** section makes it a hole, not a loop.

```
GOAL:    <what "done" looks like, as an observable condition>
MEASURE: <the objective tool that proves it — tests, coverage %, Lighthouse,
          pixel-diff, axe, a reviewer verdict>
STATE:   <persistent file holding progress/decisions, e.g. LOOP-STATE.md>

Repeat until a STOP condition fires. ONE bounded change per iteration.

Each iteration:
  1. Measure current state (ground truth — never judge by eye).
  2. Pick the single highest-impact target.
  3. Make one bounded change.
  4. Prove it: re-run MEASURE + full regression. Never weaken the check to pass.
  5. Record before/after in STATE. Commit.

STOP when ANY holds (report the terminal state):
  - Goal met: <bar reached>                         -> done
  - Budget spent: <N iterations / time / tokens>    -> exhausted
  - No progress: <K iterations under X gain, or repeating an action> -> stalled
  - Can't proceed: <tool/build broken, access blocked>             -> blocked
  - (review loops) reviewer approves / only accepted findings remain -> approved

RULES:     <scope guardrails; what it may NOT touch; what needs a human gate>
ON EXIT:   report start state, final state, iterations used, terminal state +
           reason, per-iteration log, skipped/escalated items.
```

## Pick the execution mode (and wire it)

| Mode | When | How to run |
|---|---|---|
| **One-shot session** | run now until done, no cadence | paste the loop to the agent, or `/loop` (omit the interval to self-pace) |
| **Recurring / scheduled** | nightly, every-5-min, on-release | `/schedule` (cron cloud agent) or a cron job. **Must** use a persistent working dir so the STATE file survives between runs |
| **Tool-specific** | uses a named harness (Clodex, Revolve, Autonomy-Loop, Loop Harness…) | install the tool first; the loop references its commands |

State files (`LOOP-STATE.md`, `.fix-log.json`, a `revolve/` dir) are the loop's memory **and** its oscillation guard — for scheduled loops they cannot live in `/tmp` or an ephemeral checkout.

## Before running any loop, confirm

- **Access** — read/write the target and run the commands the loop needs.
- **A measure** — an *objective* tool for the stop condition (pytest-cov, Lighthouse, axe, pixel-diff, a judge). No measure → no honest stop.
- **Bounded scope** — a concrete target + budget ("optimize checkout, ≤3h"), never "optimize everything."
- **State location** — decided up front, persistent for scheduled loops.

## Worked example — a Quality-bar loop (test coverage)

```
GOAL:    line coverage >= 80% on real logic
MEASURE: ./gradlew testDebugUnitTest jacocoTestReport
STATE:   LOOP-STATE.md (per-iteration before/after %, skipped classes)

Each iteration:
  1. Run the coverage report; read it (ground truth).
  2. Pick the lowest-covered class with real logic (skip generated/data classes).
  3. Write focused tests asserting real behavior + edge cases.
  4. Run the full suite; if red, fix/revert the test — never weaken existing tests.
  5. Append before/after % to LOOP-STATE.md; commit.

STOP: coverage >= 80% -> done | 15 iterations -> exhausted |
      3 iterations gaining < 0.5% total -> stalled | build broken, 2 tries -> blocked
RULES: touch test files only; a genuine bug the test exposes is logged separately, not silently fixed.
```

This is the **Quality Streak / 100% Coverage** family in [loop-catalog.md](loop-catalog.md) — scan the catalog before authoring; a proven shape usually exists.

## Common mistakes

| Mistake | Fix |
|---|---|
| No explicit stop | Add the STOP block — bar **and** budget **and** no-progress guards. |
| "Done" judged by the agent | Bind done to an external MEASURE. |
| Whole refactor in one iteration | One bounded change; keep it rollback-safe. |
| Errored/stalled run reported as success | Honest terminal state — `blocked`/`stalled`, with reason. |
| Scheduled loop, state in `/tmp` | Persistent working dir; state survives runs. |
| Auto-merge/deploy/delete with no human gate | Gate irreversible actions; open a PR, don't merge. |

## Reference

[loop-catalog.md](loop-catalog.md) — 42 named, field-tested loops (engineering, evaluation, ops, content, design) with each one's purpose and exact stop condition. Match your goal to one and adapt its shape.
