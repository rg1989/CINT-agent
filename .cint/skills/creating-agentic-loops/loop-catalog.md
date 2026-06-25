# Loop Catalog — 42 proven agentic loops

Match your goal to a named loop, then adapt its shape with the template in [SKILL.md](SKILL.md). Each row gives the **purpose** and the **exact stop condition** (the part agents most often get wrong). Adapted from the Forward Future / grinevich.cc Loop Library.

## Engineering (21)

| Loop | Purpose | Stop condition |
|---|---|---|
| **Fresh-Clone** | Repeat clean onboarding from the README until no hidden setup assumptions remain | One uninterrupted fresh clone reaches the documented ready state |
| **Five-Minute Repository Maintainer** | Recurring bounded triage across repos (scheduled `*/5 * * * *`) | Every item reaches a proven handoff or terminal state |
| **Docs Sweep** | Keep docs aligned with the current codebase; open a PR | All docs reflect current implementation |
| **Architecture Satisfaction** | Refactor architecture in tested, reviewed checkpoints | Architecture satisfies goals; each checkpoint has live-test proof |
| **Sub-50 ms Page-Load** | Optimize every page until it consistently loads < 50 ms | Every page < 50 ms under repeatable test conditions |
| **Production Error Sweep** | Find, fix, verify actionable errors in production | All actionable errors fixed with PRs, or none exist |
| **100% Test Coverage** | Add meaningful tests until the suite hits 100% | Coverage 100% with meaningful paths covered |
| **Logging Coverage** | Add useful, tested logs to every important path | Every important path produces useful, tested logs |
| **Nightly Changelog** | Keep the changelog current (scheduled `0 2 * * *`) | Changelog reflects all meaningful changes from the prior day |
| **Test-Suite Speed** | Speed up the suite without weakening coverage/assertions/isolation | Suite as fast as possible; coverage & isolation preserved |
| **Repository Cleanup** | Recover valuable work, safely remove proven stale state | Repo current and organized; stale state removed |
| **Ticket-to-PR-Ready** | Turn a ticket/complaint into a verified, reviewer-ready PR | Fix verified, regression-tested, PR ready — OR honestly unreproducible |
| **Clodex Adversarial-Review** | Claude builds; Codex reviews until blocking findings resolved | Codex approves, or only accepted findings remain |
| **Loop Harness Verification** | A second session independently verifies the first's output before shipping | Only independently verified output ships |
| **Autonomy-Loop Builder-Reviewer** | Builder & reviewer in separate worktrees; reviewer proves tests via revert/mutate | Every accepted wave passes a proof-of-test gate |
| **Codex Completion-Contract** | Define completion up front; require evidence for every reported result | All goal requirements have current, adequate proof |
| **Recent-Feedback Sweep** | Turn recent user corrections into a project-wide audit + verified fixes | Audit finds no remaining instance of the failure patterns |
| **Propagation Compliance** | Check a value copied across a project for stale copies | No unintended copy of the old value remains |
| **Goal Forge** | Interview the user; write what to build in SPEC.md | Planning files specify what to build with observable completion checks |
| **Cold-Load Trimmer** | Reduce data downloaded before the first screen | First screen downloads less data; tests pass, screenshots identical |
| **Housekeeper** | Conservative cleanup proving one small opportunity safe at a time | No confirmed low-risk cleanup remains; behavior intact |

## Evaluation (9)

| Loop | Purpose | Stop condition |
|---|---|---|
| **Full Product Evaluation** | Test every major capability; fix outcomes below the bar | Every scenario meets the defined quality bar |
| **Quality Streak** | Fix failures until a streak of realistic tests passes | N successful test cases in a row |
| **Self-Improving Champion** | Promote a prompt/policy change only if it wins on fresh holdout cases | Best holdout-tested champion returned |
| **Devil's-Advocate** | Challenge a design until every high-impact objection is resolved or accepted | No high-impact objection remains open |
| **Revolve Versioned-Experiment** | Improve prompts/code/config via comparable, checkpointed experiments | Best checkpoint wins within one evaluation revision |
| **Promise-to-Proof** | Compare marketing/docs/demo claims against current evidence | Every high-risk customer promise is supported or narrowed |
| **Multi-LLM Convergence** | Alternate two providers until both approve the exact same version | Two different model families approve the same unchanged version |
| **Easy Onboarding** | First-time-user test starting with no saved account/browser state | First-time user completes onboarding in one clean session |
| **Axelrod Subagent Arena** | Tournament where two agents repeatedly cooperate/defect | All 18 matches / 180 rounds reproducible from recorded moves |

## Operations (4)

| Loop | Purpose | Stop condition |
|---|---|---|
| **Stale-Safe Batch Release** | Batch valid changes; release complete artifacts from latest integrated main | Valid changes batched and released; stale work excluded |
| **Production Data Cleanup** | Remove disallowed production data; prevent the same classification errors | Disallowed records removed; classification logic improved |
| **Post-Release Baseline** | Benchmark each completed release; record a reproducible baseline (on-release) | Standard benchmarks run and recorded as the new baseline |
| **Customer AI Deployment** | Move one customer AI priority through validation, rollout, monitoring | Priority deployed through approved stages with monitoring |

## Content (2)

| Loop | Purpose | Stop condition |
|---|---|---|
| **SEO/GEO Visibility** | Fix the highest-impact search & AI-answer visibility gaps | No critical technical issues remain; every priority query maps to an answer-ready page |
| **Product Update Podcast** | Turn meaningful updates into a short, source-grounded episode (scheduled `0 3 * * *`) | Draft episode with sources delivered, OR nothing meaningful shipped |

## Design (6)

| Loop | Purpose | Stop condition |
|---|---|---|
| **Boeing 747 Benchmark** | Build/improve a Three.js 747 across nine repeatable views | 747 meets the visual bar from all nine angles, OR stagnation reported |
| **War Loops: Frontend Reconstruction** | Reconstruct a real UI; repair its weakest visual/motion mismatches | Every gate passes across desktop/tablet/mobile, OR progress stalls |
| **Infinite Clickbait Thumbnail** | Iterate thumbnail concepts until one clears the bar without misleading | Strongest concept clears the threshold, OR budget ends |
| **UI/UX Score** | Browser review: complete a real task, score each meaningful screen | Task scores better without harming other screens |
| **Pixel-Safe CSS Trim** | Remove one piece of unused CSS at a time | Stylesheet smaller while every tested screen stays pixel-identical |
| **Accessibility Repair** | Confirm barriers, fix the greatest-impact issue first | No confirmed accessibility barrier remains in agreed scope |

## Three execution categories

- **One-shot session** (~30 loops) — run once until the stop fires; no scheduler. Needs file access, the ability to run tests/build/lint, and the measurement tool.
- **Recurring / scheduled** (~6) — run on a cadence; need cron or `/schedule` **and** a persistent working dir so state files (`LOOP-STATE.md`, changelogs, checkpoints) survive between runs. Schedules above: Five-Minute Maintainer `*/5 * * * *`, Nightly Changelog `0 2 * * *`, Product Update Podcast `0 3 * * *`, Post-Release Baseline / Customer AI Deployment on event (webhook, not time-based).
- **Tool-specific** (~8) — reference named harnesses that must be pre-installed: Clodex, Autonomy-Loop, Codex Goal Planner, Revolve, Jellypod MCP, Pencil/Forge, Loop Harness.
