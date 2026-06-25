---
name: cyber-penetration-loop
description: Use when a full, deep, multi-layer penetration test is requested — where each confirmed access gain triggers a fresh recon→exploit→validate cycle from the new vantage point to find how deep penetration goes (reverse shell, RCE, lateral movement, cred harvest, domain compromise). Triggers include full pentest, deep chain, genetic loop, how deep can we get, lateral movement, pivot, post-exploitation, reverse shell, privilege escalation chain, kill chain, multi-layer attack, recursive exploitation. This is the full-activation orchestrator — it drives the other cyber-* skills in a recursive loop with stop rules.
---

# Cyber Penetration Loop (Recursive / Genetic)

## Overview

Real penetration isn't flat. An initial foothold unlocks a new vantage point, from which new attack surfaces appear, which yield deeper access, and so on. This skill is the **recursive deepening loop** that turns a single-layer scan into a full kill chain: every confirmed access gain spawns a fresh recon → exploit → validate cycle from the new position.

**Core principle:** Exploitation is a tree, not a list. Each node is a gained position; each generation explores what that position unlocks. The loop deepens until a stop rule fires.

**"Genetic" framing:** each generation's successful techniques seed the next; capability combinations unlock new attack classes (file-read + cred-leak → lateral move); dead branches are pruned; the capability genome accumulates across the tree.

## The Iron Law (Scope Re-check at EVERY Layer)

```
EVERY GENERATION RE-VERIFIES SCOPE BEFORE ACTING.
```

A recursive loop's #1 failure mode is auto-pivoting into out-of-scope systems. A reverse shell on host A can reach host B; host B may be out of scope. The loop MUST halt at scope boundaries.

- Re-read `ROE.md` at the start of every generation.
- A newly-reachable host/credential/service is **out of scope by default** until explicitly confirmed in-scope.
- "It was reachable from the foothold" is NOT authorization. Pivoting into an unauthorized system is the same violation as attacking it directly.
- Violating the letter of scope at layer N is violating the spirit of the whole engagement.

## When to Use

- User asks for a "full" / "deep" / "multi-layer" pentest, "how deep can we get," lateral movement, kill chain, or a recursive/genetic loop.
- A confirmed finding exposes a new position worth exploring (RCE → host internals; cred leak → other accounts; SQLi dump → reused creds).
- Objective-driven: "get a reverse shell," "reach host X," "exfiltrate the DB," "achieve domain admin."

Do NOT use for: single-finding validation (use `cyber-exploit-validation`), flat scans (use `cyber-recon` + `cyber-web-exploitation` linearly), or anything out of scope.

## Two Modes

| Mode | Behavior | Stop |
|---|---|---|
| **Objective-driven** | Runs until the objective is achieved or dead-end. | Objective met (reverse shell established, RCE confirmed, target host reached, DB exfiltrated) OR no-progress stop rule. |
| **Exploration-driven** | Maps maximum reachable depth and capability set. | All stop rules below; no objective shortcut. |

State the mode at invocation. Default: exploration-driven with a depth cap.

## The Position Model

A **position** is a vantage point in the attack tree:

```
Position {
  host           # the system we're acting from/against
  access_level   # none | unauth-app | authed-user | app-context-exec | host-shell | host-root | domain
  capabilities   # set: {read, write, exec, cred_leak, pivot, shell, persistence}
  credentials    # creds harvested/usable from this position
  source_vector  # the finding/PoC that got us here
  depth          # generation number
}
```

Generation 0 = the initial external position (no access, target as given).


## Genesis Gate (before P0)

P0 is built from the user's stated target. NEVER assume it. Before genesis, restate the exact target — host/domain/IP/port/path/repo — to the user via `ask` and receive explicit confirmation, AND confirm ownership/authorization for every system that will be touched. If the request leaves any ambiguity about which system is in scope ("my app", "the server", "test it", "the usual one"), STOP and ask — do not seed P0 from an inferred target. Out-of-scope-by-default applies to every later generation; the same confirmation bar applies to any newly-reachable host before it becomes a child position.

## Loop Architecture

```
GENESIS (position P0 from ROE)
  │
  ▼
┌─────────────────────────────────────────┐
│ GENERATION LOOP (per position P)        │
│                                         │
│  1. SCOPE CHECK — re-verify ROE         │
│  2. RECON from P  (cyber-recon)         │
│  3. ENUMERATE + SWEEP (see Gen 0 Gate)  │
│  4. FAN OUT exploit attempts            │
│     (cyber-web-exploitation,            │
│      cyber-tool-playbooks, per class)   │
│  5. VALIDATE each candidate             │
│     (cyber-exploit-validation: no PoC   │
│      = no finding, rejected)            │
│  6. ASSESS each confirmed hit's GAIN    │
│     → new capability? new position?     │
│  7. UPDATE capability genome            │
│  8. For each new position/capability:   │
│     → spawn CHILD generation (recurse)  │
│  9. PRUNE: dedupe equivalent positions; │
│     record failed techniques to skip    │
│ 10. STOP CHECK (see Stop Rules)         │
└─────────────────────────────────────────┘
  │
  ▼
SYNTHESIS: depth map + capability genome + chain report
```

## Generation 0 Completion Gate (Breadth Before Depth)

The recursive deepening's #1 failure mode is going deep on the first interesting service while other services sit unprobed. A Kafka UI on :8090 or a credentials endpoint on :8083 missed because you were busy exploiting :8083 is a failed engagement.

```
HARD RULE: No child generation (depth >0) may spawn until the Gen 0 gate passes.
```

The following must ALL be complete before any branch recurses from P0:

1. **Port sweep complete.** Every open port has received at least one HTTP probe. Non-HTTP ports confirmed via banner grab or `nmap -sC`. No port from the scan sits unprobed.
2. **Endpoint sweep per HTTP service.** Every HTTP service probed with the standard endpoint pattern set (see Per-Service Endpoint Exhaustion below). No service fingerprinted but not enumerated.
3. **Security header + CORS audit.** Every HTTP service checked: `curl -s -I` for missing CSP, HSTS, X-Frame-Options, X-Content-Type-Options. CORS tested with `Origin: https://evil.com`. Missing headers = LOW finding. Reflected origin + credentials = MEDIUM/HIGH.
4. **Default credential testing.** Every service with an auth surface tested: `admin:admin`, `admin:password`, `admin:<service>`, `admin:<org>`. Found defaults = immediate finding.
5. **Nuclei sweep.** If available, run against every HTTP service. Nuclei output is CANDIDATE, not confirmed — manually verify each hit (see Triage Rules).
6. **Infrastructure exposure audit.** Every database port (5432, 3306, 27017, 9200, 6379, 5433, 9042), message bus UI (8090, 15672, 18083), and monitoring port (9090, 3001, 8088) found open is recorded as an infrastructure finding. Network exposure itself is the vulnerability — exploitation is not required.
7. **Journal updated.** `journal.md` has a Generation 0 entry listing every port probed, every response code, every endpoint tested, every result. Mandatory.
8. **HTTP operations matrix completed.** Every HTTP(S) service probed with the operational endpoint set (see HTTP Operations Matrix below). No service may skip this regardless of framework fingerprint.
9. **Auth-wall adjacency sweep completed.** Every service that rejected anonymous/auth access has been cross-searched for credential-bearing config on all other reachable HTTP services (see Auth-Wall Adjacency Sweep below). A blocked service may be marked dead-ended ONLY after this sweep is journaled.
10. **Port-to-outcome accounting completed.** Every open port is classified as `verified finding`, `benign exposed service`, `intended public service`, or `out-of-scope with reason`. No discovered service remains unclassified.
11. **Scanner hits adjudicated.** Every nuclei/scanner hit has a verdict of `verified`, `false_positive`, or `inconclusive` in `scanner-validation.json`. No scanner-only result enters findings without manual reproduction.
12. **Credential ledger created.** All recovered secrets entered into `credential-ledger.json` with validation status. Every credential whose target service is reachable has been validated or marked `untestable-with-reason`.
13. **Report lint prepared.** `findings.json` is the authoritative source for all counts, severities, CWE, and evidence paths. Manual totals are prohibited.
The gate is checked ONCE at P0. Later generations inherit the completed surface and run recon-from-a-position (below).

### Per-Service Endpoint Exhaustion

Before deepening on any HTTP service, exhaust its endpoint surface. Probe these patterns (non-404 = candidate):

**Generic (every HTTP service):** `/`, `/api`, `/api/v1`, `/api/v2`, `/health`, `/ready`, `/metrics`, `/config`, `/settings`, `/admin`, `/admin/config`, `/debug`, `/status`, `/info`, `/version`, `/docs`, `/swagger`, `/openapi.json`, `/.env`, `/.git/config`

**API servers:** `/api/v1/health`, `/api/v1/config`, `/api/v1/settings/*`, `/api/v1/admin/*`, `/api/v1/users`, `/api/v1/chat/*`, `/docs`, `/redoc`

**Data stores & message buses:**
- Elasticsearch: `/_cat/indices?v`, `/_cluster/health`, `/_search`, `/_count`
- Kafka UI: `/api/clusters`, `/api/clusters/*/topics`, `/api/clusters/*/topics/*/messages`
- Grafana: `/api/health`, `/api/search`, `/api/datasources`, `/api/org`, `/api/admin/*`, `/api/users`
- Redis: `INFO`, `CONFIG GET *`

**Admin panels & monitoring:**
- Grafana: test `admin:admin` against `/api/health`
- Prometheus: `/api/v1/targets`, `/api/v1/status/config`, `/api/v1/rules`
- cAdvisor: `/api/v1.3/containers`
- Keycloak: `/admin/realms/*/console/`, `/realms/*/.well-known/openid-configuration`

**Development servers:**
- Vite: `/vite.config.ts`, `/package.json`, `/src/`, `/@fs/`
- Webpack: `/webpack-dev-server`

If `ffuf` is available, run endpoint fuzz against known patterns. If not, `curl` each pattern in a loop. Every non-404 response is a candidate for the exploit fan-out.
### HTTP Operations Matrix
For every HTTP(S) service on every open port, request the standard operational endpoint set before coverage is considered complete. This runs on **every** HTTP service regardless of framework identification — do not skip because a service was fingerprinted as a specific product.
**Mandatory operational endpoints (probe on every HTTP service):**
`/ready`, `/readyz`, `/health`, `/healthz`, `/live`, `/livez`, `/status`, `/info`, `/version`, `/metrics`, `/actuator`, `/actuator/health`, `/actuator/env`
**Mandatory config/debug leak endpoints (probe on every HTTP service):**
`/v1/config`, `/config`, `/api/config`, `/api/v1/config`, `/settings`, `/env`, `/.env`, `/debug/config`, `/actuator/env`, `/actuator/configprops`, `/swagger`, `/openapi.json`
For each response, record: status code, content type, response length, and whether the body discloses internal URLs, service names, pool statistics, queue depth, build metadata, cloud metadata, or dependency topology. If any operational endpoint leaks internal topology or sensitive runtime detail, file it as an information disclosure finding and attach raw evidence.
### Auth-Wall Adjacency Sweep
When a service is confirmed present but rejects anonymous access or direct login (auth wall), do NOT mark it exhausted. The credentials for that service are often exposed on a different, unauthenticated HTTP service's config endpoint.
**Trigger:** any service that returns 401/403, rejects anonymous login, or is confirmed present but inaccessible.
**Action:** Derive pivot tokens from the blocked service: `{protocol, product name, hostname, port, default port, env-var names, URL scheme, topic/queue/database labels}`. Search every reachable HTTP(S) service for those tokens AND for secret-bearing keys: `password`, `token`, `key`, `dsn`, `url`, `username`, `broker`, `mqtt`, `amqp`, `redis`, `postgres`, `kafka`, `bedrock`, `aws`.
Minimum HTTP config/debug paths to request on every app port during the sweep: `/v1/config`, `/config`, `/api/config`, `/settings`, `/env`, `/.env`, `/debug/config`, `/actuator/env`, `/actuator/configprops`, `/openapi.json`, `/swagger`, and any referenced JS bundles.
**A blocked service may be marked dead-ended ONLY after the adjacency sweep is complete and journaled.** This is how MQTT credentials hidden in a fetcher's `/v1/config` endpoint on a different port are found even when the MQTT broker itself rejected anonymous access.
### Capability Pivot Rule
When a capability is discovered or blocked — message broker, database, object storage, AI tools, admin console, tracing, search — propagate that capability as a pivot token across ALL other discovered surfaces. Search for config references, credentials, URLs, health endpoints, docs, JS bundles, and indirect control planes that expose or manage that capability.
The loop is capability-centric, not service-centric. A credential found on port A that unlocks port B is the same finding chain as a direct exploit on port B. Track these cross-service relationships explicitly in the attack tree.
### Port-to-Outcome Accounting
Every open port MUST terminate in exactly one of the following states by report time:
- `verified finding` — a confirmed vulnerability or exposure
- `benign exposed service` — exposed but not exploitable, with justification
- `intended public service` — meant to be public, with justification
- `out-of-scope with reason` — not tested, with reason
No discovered service may remain unclassified. Unclassified services fail the discovery gate. This prevents low-severity services (geocoding APIs, map tiles, exporters) from being silently dropped during synthesis.
### Attack Surface Accounting
Do not discard a discovered exposure because it is low severity or not currently chainable. If it expands reachable surface, exposes utility capability, or increases attacker optionality, classify it explicitly as a finding or benign note. Auxiliary services (Nominatim/geocoding, map tiles, tracing UIs, exporters, package registries) must be explicitly classified.

### Recon-from-a-position is different from external recon

Once you have a position, recon changes:
- **app-context-exec (L3):** enumerate the process env, filesystem reachable by the app user, internal network the app can see, secrets in env/config, cloud metadata if cloud-hosted.
- **host-shell (L4):** internal host recon — `id`, `whoami`, `uname -a`, `ip a`, `ss -tlnp`, `ps aux`, cron, sudo perms, SUID bins, readable `/etc/shadow`, SSH keys, browser/cookie stores, cloud CLI creds (`~/.aws`, `~/.config/gcloud`), container escape surface.
- **cred_leak:** test harvested creds against every reachable service (SSH, DB, admin panels, other apps) — reuse is the most common lateral vector.
- **pivot:** the newly-reachable internal network is a new attack surface — run `cyber-recon` against it (ports, services) *subject to scope re-check*.

## Capability Genome (what unlocks what)

Track the accumulated capability set. Combinations enable new attack classes — the loop checks this table each generation:

| Have | Enables |
|---|---|
| `read` (app files) | Source review → find more vulns; config/secret extraction. |
| `read` + `write` (app) | Modify app state, plant webshells, backdoor auth (per ROE). |
| `exec` (app-context) | Internal recon, outbound callbacks, cloud metadata fetch. |
| `exec` + `cred_leak` | Lateral movement: try creds on every reachable service. |
| `exec` + outbound net | Reverse shell upgrade (stabilize the foothold). |
| `shell` (host) | Host-level recon, priv-esc, persistence (per ROE), cred harvest. |
| `shell` + `cred_leak` | Pivot to other hosts via SSH/SMB/WinRM; domain recon. |
| `host-root` | Everything on host; dump all creds; kernel escape to host if containerized. |
| `host-root` + domain creds | AD/domain compromise path. |

When a combination newly becomes available, explicitly trigger the attack classes it unlocks in the next generation.

## Depth Ladder (the "how deep" metric)

| Depth | Position | What it means |
|---|---|---|
| L0 | external | Recon only, no access. |
| L1 | unauth-app | Unauthenticated access to app/data (IDOR, info disclosure, unauth endpoint). |
| L2 | authed-user | Authenticated, user-level data access. |
| L3 | app-context-exec | Code execution in the app's context (RCE, SSTI, deserialization, command injection). |
| L4 | host-shell | Interactive shell on the host (reverse shell via L3). |
| L5 | host-root / cred-harvest / pivot | Root on host OR harvested creds enabling lateral movement. |
| L6 | domain/infra compromise | AD admin, cloud account takeover, full infra control. |

Report the **maximum depth achieved** and the **chain** that got there. This is the headline result of an exploration-driven run.

## Post-Exploitation Sub-phase (L3+)

When `exec` or `shell` is achieved, the loop enters post-exploitation before recursing:

1. **Stabilize** the foothold per ROE (on owned test systems: upgrade to a proper reverse shell; on systems you don't own: do NOT persist — validate and move on).
2. **Internal recon** from the new position (above).
3. **Privilege escalation** on the host (`sudo -l`, SUID, kernel CVEs, misconfigured services, container escape).
4. **Credential harvest** (memory, disk, key stores, cloud CLI, browser).
5. **Assess lateral targets** — what other hosts/services are now reachable? *Scope-check each before probing.*
6. **Spawn child generations** for each viable new position.

### Reverse shell specifics

When RCE is confirmed and a reverse shell is in-scope and on an owned system:
- Use a benign, observable listener (`eval` HTTP/netcat server on a port you control, or `webhook.site`).
- Preferred upgrade path: `sh` → `bash` (pty) → stable session. Use Python/`socat`/`rlwrap` for a usable TTY.
- Log the full chain (payload → callback → shell commands → outputs) to `cyber-runs/<run>/poc/<finding-id>/`.
- Reverse proxy / port-forward for pivoting: `ssh -L`/`-R`, `chisel`, `ligolo-ng` if available — detect with `command -v`, else Python sockets via `eval`.

## Stop Rules

A generation stops (and the branch terminates) when ANY fires:

1. **No new capability or position gained** in this generation → dead end, prune.
2. **Max depth reached** (default 5; configurable at invocation).
3. **Scope boundary hit (HARD STOP).** A newly-reachable host/cred/service is out of scope. Do NOT pivot into it. Record it as an out-of-scope observation and stop the branch.
4. **Diminishing returns.** N consecutive generations (default 2) with no new capability — branch is exhausted.
5. **Resource/time budget exhausted** (set at invocation; check each generation).
6. **Objective achieved** (objective-driven mode only) — e.g., reverse shell established, RCE confirmed, target host reached.
7. **Authorization withdrawn** — if at any point the user halts or scope is revoked, stop immediately.

The *overall loop* terminates when every branch has stopped OR the user halts.

## Pruning & Dedup

- Two positions with the same `{host, access_level, capability_set}` are equivalent — don't re-explore. Dedup by this key.
- Record failed techniques per position so child generations don't retry them.
- If a child generation's surface is a subset of an already-explored position, prune.

## Multi-Agent Fan-Out (per generation)

Use `task` to parallelize each generation:

- **recon-agent** — attack surface visible from this position → `surface.md` entry.
- **exploit-agent(s)** — one per enabled attack class; each returns `FINDING <id>` + full Validation Contract, or `NO FINDING`.
- **infra-sweep-agent** — runs the infrastructure exposure audit in parallel with exploit agents: DB ports exposed, message bus UIs unauthenticated, monitoring ports open, missing security headers, CORS misconfigurations, default credentials. Returns `FINDING <id>` per exposed service/misconfiguration. This ensures infrastructure findings don't fall through the cracks of depth-first exploitation.
- **pivot-agent** — given new creds/access, maps newly-reachable hosts/services (subject to scope check).
- **capability-assessor** — classifies each confirmed finding's gain (new capability? new position? what depth?) and updates the genome.
- **triage-agent** — dedupes, ranks, rejects any claim lacking a PoC. **Scanner output (nuclei, nikto, nmap NSE, ffuf) is a CANDIDATE, not a confirmed finding.** Manually reproduce the scanner's claim — send the exact request, check the response. If the response doesn't match the claim (wrong content type, SPA fallback, empty body), it's a false positive. Record as `VERIFIED FALSE POSITIVE`, not silently dropped.
- **secret-pivot-agent** — when auth fails on one service, hunts adjacent secrets/config on all other reachable HTTP services. Searches config endpoints, debug endpoints, env leaks, JS bundles, and openapi docs for credential material referencing the blocked service. Returns recovered credentials with source artifact.
- **proof-execution-agent** — executes least-impact benign actions on exposed control planes, agent runtimes, and tool registries. When tools/actions are listed as accessible without auth, this agent invokes at least one read-only action (list, search, describe, read) and captures the response. If the primary invocation path fails, retries through alternate paths. Returns `PROOF <tool> <result>` with evidence, or `NO PROOF <reason>`.
- **false-positive-verifier-agent** — independently reproduces or disproves every scanner hit. For each nuclei/nikto/nmap NSE/ffuf result, sends the exact request, checks status code, content type, body length, and content. If the response is a generic fallback page, SPA shell, 404 wrapper, or incorrect content type, marks as `false_positive`. Returns adjudication with manual verification notes to `scanner-validation.json`.
- **report-qa-agent** — runs before final output. Validates count consistency (banner vs findings list vs risk register), finding ID integrity, CWE presence, evidence path references, redaction status, and scenario/risk-table completeness. Blocks report finalization until all checks pass. Saves result to `report-lint.json`.

Hard rule (same as router): a subagent claiming a vulnerability or a new position MUST include a reproducing PoC. Triage rejects unvalidated claims. This is what keeps a deep loop from becoming a false-positive generator.

**Journaling (mandatory):** After each generation, append to `journal.md`: every port probed (with response code), every endpoint tested (with result), every technique tried (with outcome), every finding confirmed or rejected. A generation is NOT complete until its journal entry is written. This is how interrupted runs resume and how coverage gaps are diagnosed post-engagement.
## Verification Gates (Blocking)
Completion gates are proof-based, not task-based. "Did endpoint sweep" is not proof of coverage. "Did default creds" is not proof of testing. Each gate below blocks progression until its artifact-backed conditions are met.
### Proof State Model
Track capability and finding state using five states — do not collapse these into a boolean:
- `observed` — service/endpoint seen but not probed
- `candidate` — probed, looks vulnerable, PoC not yet confirmed
- `verified` — PoC executed, data returned or access confirmed, evidence saved
- `rejected` — probed and confirmed not vulnerable (false positive, dead end)
- `untestable-with-reason` — cannot validate (out of scope, no client, service down)
Any claim of access, execution, or credential validity requires `verified` state with supporting evidence. Findings in `candidate` state may appear in the report as "unconfirmed" but MUST NOT be counted in the verified findings total.
### Action Surface Proof Gate
When a control plane, orchestration API, chat API, agent runtime, or tool registry is reachable without proper authorization, do NOT close the finding at "tool enumeration." Enumerate the exposed actions and successfully invoke at least one benign read-only action. Prefer `list`, `search`, `describe`, `read`, or metadata-only operations.
If the primary invocation path fails (e.g., upstream provider error), retry through at least one alternate path supported by the target surface (e.g., a different endpoint, a different API version, the OpenAI-compatible endpoint, direct tool invocation).
The finding remains `unproven` until a real response, real data, or side-effect-free success artifact is captured. Save request/response evidence and note which invocation path succeeded.
**Example:** AI Assistant with `auth_enabled=false` exposes `run_read_sql`. Listing the tool is `candidate`. Sending a chat message that triggers `run_read_sql` and getting back query results is `verified`. If the primary chat endpoint errors in the Bedrock bridge, retry via the Agent Control OpenAI-compatible endpoint or direct tool invocation.
### Admin Console Default Credential Matrix
Anonymous or guest access does NOT satisfy authentication testing for administrative platforms. For every exposed admin console or admin API, test the product-specific default credential matrix before severity is finalized.
**Minimum required default credential tests per admin platform:**
- Grafana: `admin:admin`, `admin:password`, `admin:grafana`
- Keycloak: `admin:admin`, `admin:password`, `admin:keycloak`, `admin:<org>`
- EMQX: `admin:public`
- Kafka UI: check if auth is configured at all
- Any admin panel: `admin:admin`, `admin:password`, `admin:<service>`, `admin:<org>`
Record each credential pair tested and its result. If any default credential succeeds, escalate the finding to full administrative compromise and update all dependent attack chains. Anonymous viewer access to Grafana is a different severity than `admin:admin` working — test both.
### Secret Validation Rule
Any password, token, API key, DSN, or credential material recovered from source, config, logs, or APIs is a **lead**, not completed proof. Enter it into `credential-ledger.json` with fields: `source_artifact`, `target_service`, `credential_type`, `username_or_id`, `validation_status`, `validation_evidence`.
Allowed statuses: `candidate`, `verified`, `invalid`, `untestable-with-reason`.
When the target service is reachable, perform the least-impact validation available:
- Message brokers/queues (MQTT, Kafka, RabbitMQ): authenticated connection is sufficient proof. Do NOT publish/write unless explicitly authorized.
- Databases: authenticated connection + `SELECT 1` or equivalent. Do NOT read data.
- APIs: authenticated request to a read-only endpoint.
- Cloud credentials: `sts:GetCallerIdentity` or equivalent read-only call.
Findings that imply working access MUST NOT be marked verified until the credential has been validated or explicitly justified as untestable.
### Scanner Hit Verification Rule
No scanner-only result (nuclei, nikto, nmap NSE, ffuf) may enter the findings list without independent manual confirmation. For each scanner hit, capture manual proof: the exact target, method, status, headers, content type, body excerpt, and the reasoning that confirms or disproves the template claim.
If the response is a generic fallback page, SPA shell, 404 wrapper, or incorrect content type for the claimed artifact, mark the hit as `false_positive` and suppress it from findings.
Save all adjudications to `scanner-validation.json` with status `verified`, `false_positive`, or `inconclusive`. A 693-byte SPA `index.html` fallback is not a source map, no matter what nuclei says.

## Output: Run Metrics + Depth Map + Attack Tree Data + Chain Report + Quality Artifacts
At loop termination, synthesize the following artifacts to `cyber-runs/<run>/`. The first three are the core report inputs; the rest are quality-gate artifacts that the report-qa-agent validates before final output:
**Core report artifacts:**

### 1. Run Metrics (`run-metrics.json`)

A machine-readable metrics file consumed by the report generator for the infographic banner:

```json
{
  "target": "http://100.90.183.19:3000/",
  "mode": "exploration-driven",
  "max_depth_configured": 5,
  "max_depth_achieved": 2,
  "max_depth_label": "L2 — authed-user",
  "total_generations": 2,
  "total_positions_explored": 14,
  "positions_by_outcome": {
    "exploited": 6,
    "dead_end": 5,
    "out_of_scope": 2,
    "pruned": 1
  },
  "total_findings": 12,
  "findings_by_severity": { "critical": 3, "high": 4, "medium": 3, "low": 2 },
  "capability_genome": ["read", "cred_leak", "exec"],
  "deepest_chain": "Unauth → AI Assistant → run_read_sql → 20 assets",
  "stop_reason": "2 consecutive generations with no new capability",
  "duration_note": "Gen 0 breadth sweep + Gen 1 deepening"
}
```

### 2. Depth Map (`depth-map.md`)

The text depth map (same as before, enriched with outcome tags):

```
## Maximum Depth Achieved: L2 (authed-user)

## Capability Genome (final)
{read, cred_leak, exec (via AI agent tools)}

## Attack Tree
- P0 (external, L0)
  ├─ [AI Assistant auth_enabled=false] → P1 (L2, EXPLOITED)
  │    ├─ run_read_sql executed (ok=true)
  │    └─ 20 assets returned
  ├─ [Elasticsearch unauth :9200] → P2 (L1, EXPLOITED)
  │    └─ 5508 PII records
  ├─ [C2 framework unauth :8000] → P3 (L1, EXPLOITED, cred_leak)
  │    └─ admin:F00b4r, live video
  ├─ [Kafka UI unauth :8090] → P4 (L1, EXPLOITED)
  │    └─ readOnly:false, TOPIC_DELETION
  ├─ [Keycloak admin console] → P5 (L0, DEAD_END)
  │    └─ Default creds failed
  ├─ [PostgreSQL :5432 exposed] → P6 (L0, INFRA_FINDING)
  └─ [100.102.32.65] → (OUT_OF_SCOPE, not probed)

## Chains
Chain 1 (deepest, L2): Unauth → AI Assistant → run_read_sql → assets
Chain 2 (L1, most PII): Unauth → Elasticsearch → 5508 records

## Out-of-Scope Observations (NOT exploited)
- 100.102.32.65:1234 — NOT in ROE scope, not probed.
```

### 3. Attack Tree Data (`attack-tree.json`)

A structured graph the HTML report renders as an interactive infographic:

```json
{
  "nodes": [
    {
      "id": "P0", "label": "External", "depth": 0, "depth_label": "L0",
      "outcome": "root", "service": "target", "generation": 0
    },
    {
      "id": "P1", "label": "AI Assistant", "depth": 2, "depth_label": "L2",
      "outcome": "exploited", "service": ":8083", "generation": 1,
      "vector": "auth_enabled=false → run_read_sql",
      "capabilities_gained": ["read", "exec"],
      "finding_id": "F-01", "severity": "critical",
      "is_deepest": true
    },
    {
      "id": "P2", "label": "Elasticsearch", "depth": 1, "depth_label": "L1",
      "outcome": "exploited", "service": ":9200", "generation": 1,
      "vector": "unauthenticated REST API",
      "capabilities_gained": ["read"],
      "finding_id": "F-02", "severity": "critical"
    },
    {
      "id": "P5", "label": "Keycloak", "depth": 0, "depth_label": "L0",
      "outcome": "dead_end", "service": ":8180", "generation": 1,
      "vector": "admin console — default creds failed",
      "capabilities_gained": []
    },
    {
      "id": "P7", "label": "100.102.32.65", "depth": 0, "depth_label": "L0",
      "outcome": "out_of_scope", "service": "internal host", "generation": 1,
      "vector": "reachable from P1 but out of ROE"
    }
  ],
  "edges": [
    { "from": "P0", "to": "P1", "label": "auth_enabled=false" },
    { "from": "P0", "to": "P2", "label": "no auth on :9200" },
    { "from": "P0", "to": "P5", "label": "admin console" }
  ],
  "generations": [
    { "gen": 0, "label": "Recon & Sweep", "description": "Port scan, HTTP probe every port, endpoint sweep, nuclei, header/CORS audit" },
    { "gen": 1, "label": "Exploit Fan-Out", "description": "10 services probed, 6 exploited, 3 dead ends, 1 out of scope" }
  ]
}
```

**Node `outcome` values:** `root` (P0), `exploited` (yielded access/capability), `dead_end` (probed but no gain), `out_of_scope` (reachable but ROE-blocked), `pruned` (subset of another position), `infra_finding` (exposure without exploitation).

**`is_deepest: true`** marks the node(s) on the deepest chain — the infographic highlights these.

Then `cyber-reporting` turns these three artifacts into the final report. The metrics + attack tree infographic is the report's opening centerpiece (see Reporting section).
**Quality-gate artifacts (required before report finalization):**
- `findings.json` — authoritative source for all finding IDs, severities, CWE, CVSS, evidence paths, and status. All report counts derive from this file.
- `service-matrix.json` — every port, fingerprint, service type, classification (`verified finding` / `benign` / `intended public` / `out-of-scope`), and related finding ID.
- `credential-ledger.json` — recovered secrets with source, target service, credential type, validation status (`candidate` / `verified` / `invalid` / `untestable-with-reason`), and validation evidence.
- `scanner-validation.json` — every scanner hit with verdict (`verified` / `false_positive` / `inconclusive`) and manual verification notes.
- `tool-proof.json` — action surfaces found, attempted actions, success/failure, invocation path used, and evidence.
- `evidence-index.json` — finding ID to artifact path mappings. Every finding must have at least one evidence path.
- `report-lint.json` — count consistency, missing-field check, cross-reference integrity, redaction review status. Report is not final until this passes.
## Reporting Quality Gates (Blocking)
Reporting hygiene is not optional polish — it is part of the methodology core. PII leakage, missing CWE, inconsistent totals, and missing evidence are process misses, not operator mistakes. The report-qa-agent enforces these gates before final output.
### Single Source of Truth Reporting
`findings.json` is the authoritative source for finding IDs, severities, CWE, CVSS, evidence paths, and status. ALL banners, severity summaries, risk registers, and appendices MUST be generated from `findings.json` only. Manual totals are prohibited.
If the banner says 5 Critical / 6 High / 4 Medium / 3 Low = 18, but the findings list contains 3 Critical / 5 High / 5 Medium / 4 Low = 17, the report FAILS the lint gate. Derive counts from the data, never hand-count.
### Report Lint Gate
Block report finalization if ANY of the following are true:
- Severity counts in the banner do not equal the findings list counts
- Banner total does not equal unique finding count
- Risk register entries do not map one-to-one to finding IDs
- A finding has no severity, no evidence path, no CWE, or no status
- PII redaction has not been reviewed
Save the lint result to `report-lint.json`. The report is not final until lint passes with zero inconsistencies.
### Redaction-First Reporting
Before narrative drafting begins, create redacted copies of all evidence intended for the report. Draft the report from `evidence/redacted/`, not from raw artifacts.
Mask direct identifiers unless exact values are essential to reproducing the issue:
- Phone numbers: partial mask (e.g., `05XXXXXXXX`)
- IMSI/IMEI/subscriber identifiers: partial mask (e.g., `4250303XXXXXXXX`)
- Email/user IDs: partial mask
- GPS coordinates: reduce precision to the minimum needed for the finding
- API keys/access keys: always mask (e.g., `AKIA...NU5P`)
Raw values may remain in operator-private evidence files under `evidence/raw/` but MUST NOT appear in the main report unless explicitly required and approved.
### CWE Required Field
Every finding MUST include a `primary_cwe` before it may be marked complete. Add `secondary_cwe` when useful. Map the **root cause**, not only the symptom.
Common mappings for reference:
- Missing authentication: CWE-306
- Exposure of sensitive information: CWE-200
- Use of hard-coded credentials: CWE-798
- Information exposure through source code: CWE-540
- Missing security headers: CWE-693
Reports with missing CWE fields fail the reporting gate.
### Evidence Minimum
Every finding MUST reference at least one saved artifact path in `evidence-index.json`. Accepted artifact types: raw HTTP response, screenshot, downloaded source/config file, structured JSON output, or command transcript. Findings without an evidence path fail the report gate.
Save leaked source files, config files, and response bodies as evidence. When a Vite dev server exposes source code, download and save the key files (vite.config.ts, AuthContext.tsx, package.json). When Elasticsearch leaks PII, save the index listing and a sample search response (redacted).
### Attack Scenario Synthesis
After verification, generate 5 to 10 ranked attack scenarios using **verified findings only**. Each scenario must include: `entry point`, `prerequisites`, `step chain`, `privilege gained`, `data exposed`, `blast radius`, `detection opportunities`, and `supporting finding IDs`. Rank scenarios by combined likelihood and impact.
### Risk Dimensions Table
For each finding and each ranked attack scenario, score the following eight dimensions:
- External reachability (can an outsider reach this?)
- Authentication bypassability (can auth be circumvented?)
- Exploit complexity (how hard is it to exploit?)
- Privilege gained (what level of access results?)
- Data sensitivity (what data is exposed?)
- Chainability/pivot value (does this unlock deeper attacks?)
- Detectability (will the defender notice?)
- Operational impact (what happens to the business?)
Include the resulting table in the report and use it to justify severity and remediation priority.

## Invocation (the "full activation" path)

This is what "run a full deep pentest" invokes. Example:

```
Run a full deep pentest against http://192.168.1.50:8080 — I own
the machine and the app. Exploration-driven, max depth 5. Map how
deep we can get. Save under cyber-runs/machine-50/.
```

Or objective-driven:

```
Full pentest on http://192.168.1.50:8080 — I own it. Objective:
achieve a reverse shell and show me the chain. Stop on success.
```

The router (`cybersec-operations`) dispatches to this skill when "full," "deep," "how deep," "lateral," "kill chain," or "genetic loop" appear in the request. For flat/single-finding requests it stays linear.

## Common Mistakes

- **Pivoting out of scope.** The #1 risk. Re-check ROE every generation; out-of-scope = stop, not "explore."
- **Treating candidates as positions.** Only *confirmed* (PoC-backed) gains become positions. Unvalidated candidates are journal leads.
- **No dedup.** Re-exploring equivalent positions wastes the budget; the tree explodes.
- **Persisting on systems you don't own.** Post-exploitation footholds on non-owned systems are backdoors — forbidden. On owned test systems, per ROE.
- **Skipping post-exploitation.** Reaching L3/L4 and not doing internal recon + cred harvest misses the entire lateral movement phase — that's where the deepest chains live.
- **No depth tracking.** Without the position model and depth ladder, "how deep" is a vibe, not a result. Track it every generation.
- **Letting the loop run unbounded.** Always set max depth + time budget at invocation. An unbounded recursive loop will run until the heat death of the session.
- **Deepening before sweeping.** The #2 failure mode: going deep on the first interesting service while others sit unprobed. The Gen 0 Completion Gate exists to prevent this. Never skip it. A Kafka UI on :8090 or a Bedrock credentials endpoint on :8083 missed because you were busy exploiting :8083 is a failed engagement.
- **Treating scanner output as findings.** Nuclei/nikto/nmap NSE output is a candidate. Manually reproduce before reporting. A 693-byte SPA fallback is not a source map, no matter what nuclei says.
- **No journal.** A blank journal means the run happened in-context and is unauditable. Every generation writes what it probed, found, and rejected. This is how gaps are diagnosed and runs are resumed.
- **Missing infrastructure findings.** A database port exposed to the network is a finding even if you can't exploit it. The infra-sweep-agent catches what the depth-first exploit fan-out misses.
- **Marking a service dead-ended without cross-service credential search.** When MQTT rejects anonymous auth, the credentials may be in a fetcher's `/v1/config` on a different port. The Auth-Wall Adjacency Sweep exists to prevent this. A service is dead-ended ONLY after the sweep is journaled.
- **Listing tools without executing one.** Finding `auth_enabled=false` with 29 agent tools is a candidate, not a finding. Invoke at least one read-only tool and capture the response. If the primary path fails, retry through an alternate path. The Action Surface Proof Gate exists to enforce this.
- **Stopping at anonymous access for admin panels.** Anonymous viewer on Grafana is a different severity than `admin:admin` working. Test the default credential matrix for every admin platform. Anonymous access does not satisfy authentication testing.
- **Reporting credentials without validating them.** A password found in a config response is a lead. Connect to the target service and verify it works before claiming the credential is valid. The Secret Validation Rule exists to enforce this.
- **Hand-counting findings for the banner.** If the banner total doesn't match the findings list, the report fails lint. Derive all counts from `findings.json`. Manual totals are prohibited.
- **Including raw PII in the report.** Phone numbers, IMSI identifiers, and GPS coordinates must be masked. Draft from redacted evidence, not raw. Redaction-first reporting is mandatory.
- **Omitting CWE classification.** Every finding needs a `primary_cwe` mapping the root cause. Reports with missing CWE fail the reporting gate.
- **Dropping low-severity services during synthesis.** A geocoding API or map tile server may be low severity, but it expands the attack surface. Port-to-Outcome Accounting ensures every discovered service is classified.
