---
name: cybersec-operations
description: Use when asked to perform security testing, penetration testing, vulnerability assessment, red-team/offensive or blue-team/defensive cybersecurity work, threat hunting, incident response, exploit development, or to find and validate vulnerabilities in an app, API, host, or network. Triggers include pentest, hack, exploit, vuln scan, security audit, CTF, bug bounty, recon, OWASP, SOC, alert triage, forensics, incident response, hardening.
---

# Cybersec Operations

## Overview

Autonomous security engagements run like a real pentester: scope → recon → map → discover → **validate with PoC** → report → remediate. The non-negotiable difference from static scanners: every finding is confirmed by an executable proof-of-concept, never asserted.

**Core principle:** A vulnerability is not a finding until you have reproduced it. False positives are the failure mode.

## The Iron Law (Ethics & Legality)

```
ONLY TEST SYSTEMS YOU OWN OR HAVE EXPLICIT WRITTEN AUTHORIZATION TO TEST.
```

- **NEVER assume the target — always confirm it.** Before any active step in the lifecycle, the orchestrator MUST restate the exact target(s) — host/domain/IP/port/path/repo — back to the user via `ask` and receive an explicit confirmation. Do NOT infer targets from context, prior runs, file names, conversation history, or vague phrases ("my app", "the server", "test it", "the usual one"). If there is ANY ambiguity about which system is in scope, STOP and ask before dispatching recon. A private IP or "my app" is a claim, not authorization — confirm the specific target string AND ownership/authorization. Public/third-party targets require explicit written consent. The ROE in step 1 cannot be written from an assumed target.
- Stay inside scope. Out-of-scope hosts/endpoints are off-limits even if "adjacent."
- Do not exfiltrate real user data, destroy state, or persist backdoors on systems you don't own.
- Violating the letter of authorization is violating the spirit. "It was just a scan" is not a defense.

## My Toolkit ↔ Hacker Toolkit

| Strix-style tool | My equivalent | Notes |
|---|---|---|
| Terminal / shell | `bash` | Run nmap, nuclei, ffuf, sqlmap, curl, etc. Detect availability first (`command -v`). |
| Browser automation | `browser` (Puppeteer) | XSS/CSRF/auth-flow testing, DOM inspection, multi-tab. |
| HTTP proxy (Caido) | `bash` + curl/`mitmproxy`/Python `requests` | No live intercept tool; manipulate requests programmatically. See `cyber-tool-playbooks`. |
| Python runtime | `eval` (py) | Custom exploit scripts, parsing, crypto. |
| Code analysis | `read`/`search`/`ast_grep`/`lsp` | White-box source review — often stronger than Strix (LSP/AST-aware). |
| Recon / OSINT | `web_search` + `bash` + `browser` | Subdomain, tech fingerprint, CVE lookup. |
| Knowledge/notes | `write` | Structured findings + attack journal per run. |
| Reporting | `write` | Markdown/HTML report with PoCs. Use `html-kit` for polished reports. |
| **Graph of agents** | `task` | Specialized subagents in parallel — a real edge over single-agent tools. |
| Web search | `web_search` | Live CVE/CVE-db/OSINT. |

## Engagement Lifecycle

The lifecycle is **linear by default** and **recursive when "full/deep" is requested**.

### Linear lifecycle (default — single layer)

1. **Confirm target, then Scope & ROE** — restate the exact target(s) to the user via `ask`, receive explicit confirmation, confirm ownership/authorization, THEN record targets, exclusions, depth, credentials, rules of engagement. Write to `cyber-runs/<run-name>/ROE.md`. Recon (step 2) is blocked until this completes.
2. **Recon & mapping** — attack surface. → `cyber-recon`.
3. **Discovery** — identify candidate vulns (automated + manual + source review). → `cyber-web-exploitation` (web), `cyber-tool-playbooks` (infra).
4. **Validation** — build a PoC that reproduces the issue. No PoC = no finding. → `cyber-exploit-validation`.
5. **Report** — findings, severity (CVSS), reproduction, remediation. → `cyber-reporting`.
6. **Remediate/fix** — propose or apply patches; re-test the fix.
7. **Defensive flip** — if asked for blue-team work, switch to `cyber-defensive-ops`.

### Recursive lifecycle (full / multi-layer / deep-chain requests)

When the request asks for "full," "deep," "how deep can we get," "lateral movement," "kill chain," "genetic loop," or a multi-layer attack, dispatch to **`cyber-penetration-loop`** instead of running the linear lifecycle once. That skill runs the above lifecycle *recursively*: every confirmed access gain (PoC-backed) becomes a new position from which a fresh recon→exploit→validate cycle spawns, deepening until a stop rule fires (max depth, no new capability, scope boundary, objective met). It orchestrates the phase skills below it. This is the "full activation" path.

## Scan Modes

| Mode | When | Behavior |
|---|---|---|
| Quick | Every PR, smoke test | Obvious/low-hanging vulns only. Minutes. |
| Standard | Routine review, pre-release | Balanced dynamic + static. |
| Deep | Pre-prod audit, bug bounty | Edge cases, chained vulns, broad static triage then dynamic validation. Default for full engagements. |

## Box Color (drives discovery strategy)

- **Black-box** — no source. Recon + dynamic probing + fuzzing.
- **Grey-box** — credentials + maybe partial source. Authenticated testing, business-logic focus.
- **White-box** — full source. Source-aware triage first (`ast_grep`/`lsp`/semgrep), then dynamically validate top candidates. Most efficient.

## Multi-Agent Orchestration (`task`)

For non-trivial targets, fan out specialized subagents in parallel and synthesize:

- **recon-agent** → attack surface map (write to shared `cyber-runs/<run>/surface.md`).
- **source-audit-agent(s)** → per-module static review (one subagent per component).
- **exploit-agent(s)** → one per vuln class or per target asset; each must return a validated PoC or "no finding."
- **triage-agent** → dedupe, rank by severity, reject unvalidated claims.

**Hard rule for subagents:** a subagent claiming a vulnerability MUST include a reproducing PoC (request + response, command + output, or code path). Triage rejects any claim lacking reproduction evidence. This is what kills false positives at scale.

## Run Hygiene

- One directory per engagement: `cyber-runs/<run-name>/` with `ROE.md`, `surface.md`, `findings.md`, `journal.md`, `poc/`.
- Persist progress so an interrupted run resumes with context (mirrors PentestGPT's iteration loop).
- Keep an attack journal of what was tried and the result — avoids repeating dead ends.

## Red Flags — STOP

- Target not explicitly confirmed in this turn, or authorization unconfirmed → halt active steps immediately. No assumed targets, ever.
- Subagent reports a vuln with no PoC → reject, not "probably real."
- Drifting out of scope ("while I'm here…") → stop.
- Storing/exfiltrating real user PII → don't.
