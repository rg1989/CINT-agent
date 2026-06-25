---
name: cyber-tool-playbooks
description: Use when running security CLI tools during recon, scanning, or exploitation — need exact high-signal command syntax for nmap, nuclei, ffuf, sqlmap, httpx, subfinder, naabu, katana, semgrep, curl, or mitmproxy. Triggers include port scan, run nmap, nuclei scan, fuzz with ffuf, sqlmap, httpx probe, subdomain enum, content discovery, run semgrep, intercept proxy. Load when invoking sandbox/CLI security tools.
---

# Security Tool Playbooks

## Overview

High-signal invocations for the canonical pentest CLI tools. Each tool: what it's for, the default-good command, the flags that matter, and the pitfalls. Load the relevant section from [tools.md](tools.md) on demand.

**Core principle:** Use the right tool for the phase, tune rate/scope to the target, and read the output — tools report; you interpret.

## Before You Run

`command -v <tool>` to detect availability. If absent, fall back: no `nmap` → `bash` with `/dev/tcp` or Python sockets via `eval`; no `ffuf` → Python wordlist loop via `eval`; no `sqlmap` → manual injection per `cyber-web-exploitation`. Never assume a tool is installed.

**Target must be confirmed first.** These commands send traffic to a host. Never run any of them against a target you assumed or inferred — the exact target must have been explicitly confirmed with the user this engagement (via `ask`; see `pentest` rule 1 / `cybersec-operations` step 1). If you reached this skill without a confirmed target, STOP and confirm before invoking any tool below.

## Quick Reference — Tool → Phase → Command

| Tool | Phase | Default-good |
|---|---|---|
| `nmap` | Net recon | `nmap -sS -sV -sC -p- --open -T4 <host>` |
| `naabu` | Fast port scan | `naabu -host <h> -p - -rate 1000 -verify` |
| `subfinder` | Subdomain enum | `subfinder -d <dom> -silent -recursive` |
| `httpx` | HTTP probe/fingerprint | `httpx -l hosts.txt -status-code -title -tech-detect -follow-redirects` |
| `katana` | Crawl/JS extract | `katana -u <url> -jc -d 3 -kf all` |
| `ffuf` | Content/param fuzz | `ffuf -u <url>/FUZZ -w <wordlist> -mc 200,301,401,403 -fs <filter>` |
| `nuclei` | Vuln templates | `nuclei -u <url> -severity high,critical -rl 50` |
| `sqlmap` | SQLi | `sqlmap -u <url> --batch --level 3 --risk 2 --random-agent` |
| `semgrep` | Static triage | `semgrep --config p/owasp-top-ten --config p/sql-injection <path>` |
| `curl` | HTTP by hand | `curl -sS -i -k -L -A <ua> <url>` |
| `mitmproxy` | Intercept proxy | `mitmproxy --mode regular@8080` (set as system/browser upstream) |

Full syntax, flag rationale, and pitfalls per tool: see **[tools.md](tools.md)**.

## Rate & Noise Discipline

- Start low-rate (`-T3` nmap, `-rl 50` nuclei, `-rate 1000` naabu); raise only against robust owned targets.
- Filter ffuf output by response size/words to cut noise: `-fs <bytes>` or `-fw <words>` after a baseline.
- Scope nuclei: `-severity high,critical` first pass; add `medium` only if time. Use `-tags` to target (`-tags cve,exposure`).
- Always log raw output to `cyber-runs/<run>/raw/<tool>.txt` for the report.

## Fallback Strategy

No tool installed ≠ blocked. The Python runtime (`eval`) and `curl`/`browser` cover most of what these tools do, slower:
- Port scan → Python `socket` connect loop.
- Content discovery → `requests` over a wordlist with status/size filter.
- SQLi → manual boolean/time/UNION per `cyber-web-exploitation`.
- Subdomain enum → `crt.sh` JSON via `curl`, parse with `eval`.

Prefer native tools when present (faster, richer output); fall back deliberately when not.

## Common Mistakes

- **Full-range scan with `-T5`.** Inaccurate + noisy; `-T4` is the practical max.
- **ffuf without size/word filter.** Wall of 200s you can't triage.
- **nuclei at default rate on a fragile target.** Rate-limit (`-rl`) it.
- **sqlmap `--level 5 --risk 3` first.** Noisy and slow; start level 3 risk 2, escalate.
- **Trusting tool "vulnerable" verdicts.** Validate per `cyber-exploit-validation`; tools false-positive too.

## Command Execution Discipline

How you structure tool invocations determines whether an engagement survives interruption. These rules prevent lost work from cancelled or timed-out commands:

- **Scanner runs are long — set generous timeouts or go async.** nuclei, nmap `-p-`, and ffuf against a large wordlist can run minutes to tens of minutes. A short default timeout kills a nuclei sweep mid-scan with no output saved. Use the timeout table below — set the bash `timeout` parameter to the "min timeout" value at minimum, or use `async: true` for anything exceeding 300s.
- **One CVE/test per bash command.** Never combine multiple CVE vectors or multiple independent tests in a single bash call. If the command is cancelled or times out, you lose ALL results. Each CVE test is typically a single HTTP request — run them individually so cancellation costs only one test.
- **Batch endpoint enumeration in `eval`, not bash.** The Per-Service Endpoint Exhaustion list (see `cyber-penetration-loop`) has 15+ patterns per service. Don't `curl` them in one giant bash command — it'll timeout or cancel. Use an `eval` cell with a Python `requests` loop that probes each endpoint, records status/length/body, and returns a structured table. State persists across `eval` calls, so an interrupted sweep resumes cleanly.
- **Don't over-parallelize bash.** Multiple parallel bash calls (nmap + nuclei + ffuf simultaneously) all get cancelled when the session advances to the next turn. If you need multiple long scans, run them sequentially via `async: true` and `job poll`, or inside a single `eval` cell with `asyncio`/`subprocess`.
- **CVE tests are standalone and early.** After fingerprinting the tech stack (recon step 1), immediately check for version-specific CVEs via `web_search` (`"<component> <version> CVE"`). Test each CVE individually — they're high-signal, single-request tests that should run early, not buried in the nuclei sweep.

## Timeout Heuristics

Concrete timeout guidance per tool/scope. When a bash call's `timeout` parameter is below the "min timeout" for the operation, the scan WILL be killed mid-run with no output saved. Default to `async: true` for anything ≥ 300s.

| Tool | Scope | Expected duration | Min `timeout` | Strategy |
|---|---|---|---|---|
| `nmap -sS --top-ports 1000` | single host | 10–30s | 120s | bash with `timeout: 120` |
| `nmap -sS -sV -sC -p-` | single host | 5–15 min | 900s | `async: true` + `job poll` |
| `nmap -sS -p-` | /24 subnet | 30–90 min | 3600s | `async: true` + `job poll`; split into smaller ranges if possible |
| `nmap -sU --top-ports 50` | single host | 2–5 min | 600s | `async: true` + `job poll` |
| `naabu -host <h> -top-ports 1000` | single host | 5–15s | 120s | bash with `timeout: 120` |
| `naabu -host <h> -p -` | single host (all ports) | 1–5 min | 600s | bash with `timeout: 600` or `async: true` |
| `nuclei -u <url> -severity high,critical` | 1–5 targets | 2–10 min | 600s | `async: true` + `job poll`; split by severity |
| `nuclei -l hosts.txt -severity medium,high,critical` | 10+ targets | 15–60 min | 1800s | `async: true` + `job poll`; split target list into batches of 5 |
| `nuclei -u <url>` (all templates) | single target | 10–30 min | 1200s | `async: true` + `job poll` |
| `ffuf` with `common.txt` (~4600 words) | single target | 30s–2 min | 300s | bash with `timeout: 300` |
| `ffuf` with `raft-medium-files.txt` (~17000 words) | single target | 2–8 min | 600s | `async: true` + `job poll` |
| `ffuf` with full SecLists directory | single target | 5–20 min | 1200s | `async: true` + `job poll` |
| `sqlmap --batch --level 3 --risk 2` | single param | 1–10 min | 600s | `async: true` + `job poll`; use `--output-dir` so partial results survive |
| `katana -u <url> -jc -d 3` | single target | 30s–3 min | 300s | bash with `timeout: 300` |
| `katana -u <url> -jc -d 5` | single target (deep) | 2–10 min | 600s | `async: true` + `job poll` |
| `subfinder -d <dom> -all` | single domain | 30–90s | 300s | bash with `timeout: 300` |
| `httpx -l hosts.txt` | 10–50 hosts | 10–60s | 180s | bash with `timeout: 180` |
| `dirsearch -u <url>` | single target | 2–5 min | 300s | bash with `timeout: 300` |
| endpoint sweep (15–20 `curl` probes) | single service | 10–30s | 120s | `eval` cell with Python `requests` loop (not bash) |
| CVE test (single HTTP request) | single target | 1–5s | 30s | bash with `timeout: 30` — run individually |

**Rules derived from the table:**

1. **Anything ≥ 300s → `async: true`.** Never block the session on a long scan. Fire it async, note the job ID, continue with other work, `job poll` for results.
2. **Split large target lists.** nuclei against 50 hosts is not one command — split into batches of 5, run sequentially via `async: true` + `job poll`.
3. **Always use `-o`/`--output` flags.** If a scan is killed or the session advances, the partial output is saved to disk. A nuclei run that wrote nothing because it was interrupted mid-scan is wasted work.
4. **CVE tests are 30s commands, not 600s commands.** A single CVE test is one HTTP request — `curl` in bash with `timeout: 30`. Don't bundle multiple CVEs into one long-running command.
5. **`eval` for batch endpoint sweeps.** The Per-Service Endpoint Exhaustion list (15–20 endpoints × N services) belongs in an `eval` Python cell with `requests.Session()`, not a bash `curl` loop. State persists across `eval` calls, so interrupted sweeps resume cleanly.
