---
name: running-agentic-loops
description: Use when automating work that needs an agent to iterate rather than answer in one shot — designing, initiating, or running an agentic loop; deciding whether a task needs a loop versus a single call or fixed workflow; or when a running loop won't terminate, repeats the same action, drifts off-task, or burns unexpected cost.
---

# Running Agentic Loops

## Overview

An agentic loop repeats **act → observe ground truth → verify → decide → repeat** until a goal holds. It buys adaptivity at the price of cost, latency, and compounding errors. **A loop without an explicit termination contract is a runaway, not an agent.** This skill is how you decide whether to loop, pick the loop's shape, make it robust, and launch it with the right primitive.

## Step 0 — Do you even need a loop?

Climb only as high as the task forces you. Most work stops at rung 1 or 2.

1. **One augmented call** (model + tools + retrieval). Try this first.
2. **Fixed workflow** — prompt-chain, route, parallelize, or orchestrator→workers — when the steps are predictable and you can hardcode the path. Reliable, testable, cheap.
3. **Autonomous loop** — only when you genuinely *cannot* predict the step count or hardcode the path.

> If you can write the steps down in advance, build a workflow, not a loop.

## The loop contract (non-negotiable)

Declare all five before the first iteration. Skipping any one is how loops go runaway.

1. **Goal + done-condition** — an *observable, ideally executable* predicate. "Done = tests green / file matches X / N items processed" — never "done = looks good."
2. **Termination guards, layered cheap→expensive** so you fail fast:
   - hard **iteration cap** (15–25 typical) — always, from day one;
   - **token/cost budget** — cost is *super-linear* (step 10 re-reads steps 1–9);
   - **oscillation detection** — hash `(tool, args[, result])`; bail if a fingerprint repeats ≥3×;
   - **no-progress detection** — if observable state is unchanged for K steps, stop.
   - *A max-iteration cap alone is a circuit breaker, not a strategy — without progress/oscillation checks a loop repeats the same useless action dozens of times before the cap fires.*
3. **External verification** — check against ground truth (tool result, test, compiler, a *separate* critic), never the model's own confidence. **Separate who DOES the work from who decides it's DONE** — a model grading itself is two optimists agreeing.
4. **Recovery** — retry only *idempotent* calls (backoff + jitter, per-tool not global); human checkpoint before irreversible actions (payments, deletes, sends); sandbox real write access.
5. **Inspectable exit** — every termination path returns `{result, reason}` where reason ∈ `complete | budget | stuck | stalled | max_steps | error`. Never a silent stall or crash.

## Pick the loop's shape

Three axes drive the choice: **(a)** how predictable the steps are, **(b)** whether a verifiable signal exists, **(c)** token/latency budget.

| Pattern | Loop shape | Reach for it when | Main failure mode |
|---|---|---|---|
| **ReAct** | think → call tool → read result → repeat | steps unpredictable; next step depends on last result (the default autonomous loop) | drifts/repeats without stop conditions; cost scales with steps |
| **Plan-and-Execute** | plan all steps → run each (cheap model) → replan | steps mostly knowable; want to cut cost vs ReAct | bad initial plan propagates; less reactive to surprises |
| **ReWOO** | plan full DAG w/ variable refs → batch-execute → solve | multi-hop, token-sensitive, structure known upfront | brittle if an early result should change the plan |
| **Self-Refine** | draft → self-critique → revise | improving ONE artifact, no external oracle | bounded by model's own blind spots; can degrade output |
| **Evaluator-Optimizer** | generate → *separate* critic scores → revise | clear criteria AND refinement measurably helps | same-model critic rubber-stamps; needs iteration cap |
| **Reflexion** | run episode → score → write verbal lesson → retry | retryable task + real success signal (tests/reward) | needs the signal + replay; reflections can mislead |
| **LATS** | tree-search (MCTS) over trajectories | high-stakes, evaluable state, compute to burn | most expensive by far; complex; needs a value function |

Outer-loop control (ReAct, Plan-and-Execute, ReWOO) and self-correction (Self-Refine, Evaluator-Optimizer, Reflexion, LATS) **compose** — Reflexion and LATS use ReAct as their inner actor.

## Run it here (this environment's primitives)

| You want | Use | Notes |
|---|---|---|
| Iterate until done, this session, self-paced | native agent loop, or `/loop` with no interval | keep the stop predicate in the prompt; `ScheduleWakeup` paces the next tick |
| Poll / repeat on a fixed clock | `/loop <interval> <prompt>` | e.g. `/loop 5m /check-deploy` |
| Unattended recurring on a schedule | `/schedule` (cloud cron routine) | survives session end |
| Deterministic fan-out / N items / verify-each | **`Workflow`** tool | `pipeline()`/`parallel()`; loop-until-dry and loop-until-budget patterns are built in |
| Long external job (CI, build, deploy) | background `Bash`/`Agent` task | the harness re-invokes you on completion — **don't poll** |
| Sub-loop needing isolated context | subagent via `Agent` tool | fresh context window per subagent |

## The contract, in code

One robust ReAct loop — adapt it; every guard maps to a contract item above.

```js
const MAX_STEPS = 20
const BUDGET   = 200_000              // token ceiling
const seen = new Map()                // oscillation fingerprints
let lastState = null, stalls = 0, best = null

for (let step = 1; step <= MAX_STEPS; step++) {
  if (spent() > BUDGET) return done("budget", best)

  const action = decideNextAction(context)          // reason

  const fp = hash(action.tool, action.args)         // oscillation guard
  seen.set(fp, (seen.get(fp) ?? 0) + 1)
  if (seen.get(fp) >= 3) return done("stuck", best)

  const observation = run(action)                   // ground truth from env
  context.push(action, observation)
  best = observation

  if (sameState(observation, lastState)) {          // no-progress guard
    if (++stalls >= 3) return done("stalled", best)
  } else stalls = 0
  lastState = observation

  if (verify(goal)) return done("complete", result) // EXTERNAL check (tests green), not self-judgment
}
return done("max_steps", best)                       // every exit is inspectable
```

## Common mistakes

| Smell | Fix |
|---|---|
| No iteration cap | Add a hard cap from day one (15–25). |
| Loop decides its own "done" | Externalize — tests / tool result / *separate* critic owns termination. |
| Only a max-iter cap | Add oscillation + no-progress detection, or it repeats 50× then stops. |
| Vague goal ("improve the codebase") | Define done as an executable predicate before starting. |
| Retrying writes/payments | Retry only idempotent calls; checkpoint irreversible ones. |
| Same plan regenerated each turn | Persist plan/state — "memory-less replanning" pathology. |
| Context keeps growing | Compact at ~80% of the window, or isolate work in subagents. |
| Cost surprises | Budget tokens; loop cost is super-linear, not step × single-call. |

## Red flags — STOP

- "I'll just raise the iteration limit" → raising 25→1000 buys 1000 *stuck* iterations, not a fix. Find why it's stuck.
- "The model says it's done" → not a stop condition. Verify against the environment.
- "It's a quick task, no caps needed" → caps are cheapest insurance; add them anyway.
- Loop touches money/data/external sends with no human checkpoint → gate it.

## Sources

Anthropic [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) · [Agent SDK loop](https://code.claude.com/docs/en/agent-sdk/agent-loop) · [Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) · ReAct, [Reflexion](https://arxiv.org/abs/2303.11366), [Self-Refine](https://arxiv.org/abs/2303.17651), [ReWOO](https://arxiv.org/abs/2305.18323), [LATS](https://arxiv.org/abs/2310.04406), [CRITIC](https://arxiv.org/abs/2305.11738) · [LangGraph recursion limit](https://docs.langchain.com/oss/python/langgraph/errors/GRAPH_RECURSION_LIMIT) · [OpenAI Agents SDK guardrails](https://openai.github.io/openai-agents-python/guardrails/)
