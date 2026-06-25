---
name: cyber-full-spectrum-loop
description: The maximum-effort skill — combines cyber-penetration-loop's recursive deepening with the exploit-researcher's full toolkit (CVE research, binary RE, fuzzing, exploit dev, CVE reproduction). Use for "give it everything," "maximum effort," "full spectrum," "all tools," or when you want the deepest possible assessment using every capability at your disposal. Activates ALL cyber-* skills in a unified recursive loop: pentest recon → web exploitation → vuln research → CVE lookup → binary analysis → fuzzing → exploit development → CVE reproduction → post-exploitation → reporting. This is the apex skill — use when nothing less than full depth is acceptable.
---

# Cyber Full-Spectrum Loop (Maximum Effort)

## What this skill is

This is the **apex skill** — it unifies the recursive penetration loop (`cyber-penetration-loop`) with the exploit-researcher toolkit (`cyber-vuln-research`, `cyber-cve-reproduction`, `cyber-reverse-engineering`, `cyber-fuzzing`, `cyber-exploit-development`, etc.) into a single recursive loop that uses **every tool and technique available** at each position.

**The insight from AIxCC:** the winning CRS (Team Atlanta) won by running two complementary pipelines in parallel — traditional pentest/fuzzing AND LLM-driven vuln research — where each pipeline's outputs feed the other. Failed exploit attempts become fuzzer seeds; fuzzer coverage guides exploit dev; CVE research identifies known-buggy components; binary analysis finds sinks in closed-source targets. This skill implements that combined architecture.

**Relationship to `cyber-penetration-loop`:** This skill is a strict superset. It inherits the position model, depth ladder, stop rules, Gen 0 Completion Gate, reporting gates, and multi-agent fan-out from `cyber-penetration-loop`. It adds the exploit-researcher's phases, agents, and tools at each generation. If you invoke this skill, you do NOT also invoke `cyber-penetration-loop` — this one drives it.

## When to use

- "Maximum effort," "full spectrum," "use everything," "all tools," "go all out"
- "Combine pentest and exploit research"
- When the target has both web surfaces AND binary components (e.g., a web app backed by a custom binary service)
- When a prior pentest found the surface but couldn't go deep (WAF block, auth wall, missing CVE research)
- When you want the deepest possible assessment — not just "what's exposed" but "what's exploitable and how deep can we chain it"

Do NOT use for: single-finding validation (`cyber-exploit-validation`), flat scans (`cyber-recon` + `cyber-web-exploitation`), known-CVE-only reproduction (`cyber-cve-reproduction` alone), or anything out of scope.

## Authorization gate (non-negotiable)

Same as `cyber-penetration-loop`: confirm ownership/authorization for every system that will be touched before P0. Re-verify scope at every generation. Out-of-scope = stop, not "explore."

**Additional constraint for exploit research:** actively exploiting memory-corruption CVEs (heap overflow, UAF, etc.) against a target is potentially destructive (crash, RCE). The ROE must explicitly permit this, or memory-corruption findings are flagged as "potential — version verification required" without active exploitation. Non-destructive testing still applies unless the ROE says otherwise.

## The Extended Depth Ladder

The penetration-loop's depth ladder tracks access gains. This skill extends it with exploit-research rungs:

| Depth | Position | What it means |
|---|---|---|
| L0 | external | Recon only, no access. |
| L1 | unauth-app | Unauthenticated access to app/data (IDOR, info disclosure, unauth endpoint). |
| L2 | authed-user | Authenticated, user-level data access. |
| L3 | app-context-exec | Code execution in the app's context (RCE, SSTI, deserialization, command injection). |
| L4 | host-shell | Interactive shell on the host (reverse shell via L3). |
| L5 | host-root / cred-harvest / pivot | Root on host OR harvested creds enabling lateral movement. |
| L6 | domain/infra compromise | AD admin, cloud account takeover, full infra control. |
| **L7** | **binary-exploit** | A memory-corruption exploit (heap overflow, UAF, type confusion) achieves code execution in a target binary — extends L3/L4 to binary services. |
| **L8** | **cve-chain** | A reproduced/weaponized CVE (N-day or 0-day) is chained into the attack tree — extends any rung with known-vuln exploitation. |

Report the **maximum depth achieved** and the **full chain** including both web-exploitation and binary/exploit-dev paths.

## The Extended Capability Genome

Inherits the penetration-loop's genome and adds:

| Have | Enables |
|---|---|
| `read` (source code) | Static analysis → `cyber-bug-identification`: dangerous functions, taint traces, variant analysis |
| `read` (binary) | `cyber-reverse-engineering`: Ghidra decompile, input→sink tracing, patch-diffing with Diaphora |
| `binary_read` | ROPgadget/ropper → gadget catalog; capstone disassembly → sink analysis |
| `fuzzer_coverage` | AFL++/libFuzzer coverage maps → guide LLM PoV generation to uncovered paths |
| `crash_input` | `cyber-crash-analysis`: ASAN/MSAN triage, exploitability assessment, root-cause ID |
| `cve_match` | `cyber-cve-reproduction`: EAGER pipeline to rebuild vulnerable env + generate PoC + verifier |
| `cve_match` + `binary_read` | Patch-diff the fix → variant analysis (same bug pattern elsewhere) |
| `exploit_primitive` | `cyber-exploit-development`: turn crash → reliable PoC (ROP, ret2libc, shellcode) |
| `exploit_primitive` + `mitigations_map` | `cyber-mitigations`: plan bypass (DEP→ROP, ASLR→info-leak, CFG→indirect-call) |

## The Extended Loop Architecture

Inherits the penetration-loop's loop and adds three new phases per generation:

```
GENESIS (position P0 from ROE)
  │
  ▼
┌──────────────────────────────────────────────────┐
│ GENERATION LOOP (per position P)                 │
│                                                  │
│  1. SCOPE CHECK — re-verify ROE                  │
│  2. RECON from P  (cyber-recon)                 │
│  3. ENUMERATE + SWEEP (Gen 0 Gate if P0)        │
│                                                  │
│  ── PENTEST FAN-OUT (existing) ──                │
│  4a. WEB EXPLOITATION (cyber-web-exploitation)   │
│  4b. TOOL PLAYBOOKS (cyber-tool-playbooks)       │
│  4c. VALIDATE (cyber-exploit-validation)         │
│                                                  │
│  ── EXPLOIT RESEARCH FAN-OUT (new) ──            │
│  5a. STACK FINGERPRINT → CVE RESEARCH             │
│      (identify server/framework/lib versions,    │
│       search NVD/ExploitDB/GHSA/CISA KEV for     │
│       matching CVEs)                             │
│  5b. BINARY ANALYSIS (if binary targets found)    │
│      (cyber-reverse-engineering: Ghidra headless,│
│       decompile, input→sink, patch-diff)         │
│  5c. FUZZING (if source/binaries/harnesses avail) │
│      (cyber-fuzzing: AFL++/libFuzzer, LLM-seeded,│
│       crash → cyber-crash-analysis)              │
│  5d. EXPLOIT DEVELOPMENT (if crash/primitive)    │
│      (cyber-exploit-development: pwntools, ROP,  │
│       shellcode, mitigation bypass)              │
│  5e. CVE REPRODUCTION (if known CVE matched)      │
│      (cyber-cve-reproduction: EAGER pipeline —   │
│       Processor→Builder→Exploiter→Verifier)      │
│                                                  │
│  6. CROSS-PIPELINE FEEDBACK                      │
│     • fuzz coverage → guide exploit dev          │
│     • failed exploit inputs → fuzzer seeds       │
│     • CVE research → new exploit targets         │
│     • crash triage → root cause → variant search │
│     • binary analysis sinks → targeted PoV gen   │
│                                                  │
│  7. ASSESS each confirmed hit's GAIN             │
│     → new capability? new position? new depth?   │
│  8. UPDATE capability genome + attack tree        │
│  9. For each new position/capability:            │
│     → spawn CHILD generation (recurse)           │
│ 10. PRUNE: dedupe; record failed techniques      │
│ 11. STOP CHECK (see Stop Rules)                  │
└──────────────────────────────────────────────────┘
  │
  ▼
SYNTHESIS: depth map + capability genome + chain report
            + CVE catalog + exploit inventory
```

## Phase Details (the new phases)

### 5a. Stack Fingerprint → CVE Research

**Trigger:** every service fingerprinted in phase 2/3 (nmap banners, HTTP `Server` header, framework fingerprints like ASP.NET ViewState, jQuery version, openresty/nginx version).

**Actions:**
1. Extract version identifiers from all captured evidence (headers, HTML, banners, cookies).
2. For each identified component + version, search:
   - NVD API 2.0: `services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=<product>+<version>`
   - ExploitDB: `searchsploit <product> <version>` (local mirror)
   - GitHub Security Advisories: `github.com/advisories?query=<product>`
   - CISA KEV: `cisa.gov/known-exploited-vulnerabilities-catalog`
   - Vendor security advisories (openresty changelog, nginx security advisories, Microsoft blog, etc.)
3. For each matching CVE: assess exploitability (is the vulnerable code path reachable? are the preconditions met? is a PoC public?), record as `cve_match` capability.
4. For high-severity matches: flag for phase 5e (CVE reproduction) if the ROE permits active exploitation, or as "potential — version verification required" if not.

**The pointernet lesson:** this phase is what found CVE-2026-9256 (openresty heap overflow, CVSS 9.2) from the captured `Server: openresty` header — a finding the original pentest missed because it was WAF-blocked before reaching vulnerability research. This phase runs on **captured evidence**, not live requests, so it works even when the WAF blocks active probing.

### 5b. Binary Analysis

**Trigger:** a target service is a binary (no source available), OR a binary is retrieved from the target (firmware, uploaded executable, compiled service).

**Actions:**
1. Triage: `file`, `checksec` (mitigations), `strings` (version banners, debug strings).
2. Ghidra headless analysis: `analyzeHeadless` (project dir MUST pre-exist), auto-analyze, decompile functions.
3. Input→sink tracing: find dangerous functions (`strcpy`, `memcpy`, `sprintf`, `system`, `free`+use, format-string funcs), walk cross-references backward to entry points.
4. Patch-diffing (if a patched version exists): analyze both versions in Ghidra, export to Diaphora databases, diff → the changed function is the fix → root cause localized.
5. Variant analysis: search for the same bug pattern (identified via patch-diff) in other functions of the same binary.

**Tool constraint:** pwntools/ROPgadget operate on ELF/PE only (reject macOS Mach-O). Build/analyze Linux ELF or Windows PE targets. Use Docker containers for Linux-target building and crash reproduction. Ghidra headless works on any architecture.

### 5c. Fuzzing

**Trigger:** the target has a parser, protocol handler, or input-processing function that can be fuzzed. Source or binary available. Fuzzing harness exists (OSS-Fuzz) or can be written.

**Actions:**
1. Select fuzzer: AFL++ (greybox, coverage-guided), libFuzzer (in-process, fast), Honggfuzz, Boofuzz (protocol), syzkaller (kernel syscalls).
2. Write or obtain a fuzzing harness (LLM can generate Python input-generators or C harnesses).
3. LLM-guided seed generation: analyze the input format, generate semantically-valid seeds (not random bytes) — this is the AIxCC-winning technique (Trail of Bits, Shellphish "Grammar Guy").
4. Run fuzzing campaign (time-budgeted). Collect crashes.
5. Crash triage: feed crashes to `cyber-crash-analysis` (ASAN/MSAN output, stack trace, exploitability assessment).
6. Minimize crashing inputs (testcase reduction).
7. Feed coverage data to phase 5d (exploit dev) and failed inputs back to the fuzzer corpus.

**Cross-pipeline feedback:** LLM-generated PoV attempts that fail to trigger a crash become fuzzer seeds. Fuzzer coverage maps guide the LLM to uncovered code paths. This bidirectional feedback is the key architectural insight from AIxCC.

### 5d. Exploit Development

**Trigger:** a crash or vulnerability primitive is confirmed (from fuzzing, binary analysis, or CVE research). The ROE permits exploit development.

**Actions:**
1. Root-cause analysis: isolate the exact code location + violated invariant (from `cyber-crash-analysis`).
2. Mitigation assessment: `checksec` / `dumpbin` → what protections are active? (DEP, ASLR, canaries, CFI, CFG, CET, MTE). Load `cyber-mitigations` for bypass catalog.
3. Primitive development: turn the crash into a reliable primitive:
   - PC/IP control (stack overflow → ROP)
   - Arbitrary read/write (heap corruption → overlapping chunks)
   - Logic bypass (type confusion, auth bypass)
4. Mitigation bypass: ROP chain for DEP, info-leak for ASLR, JOP for CFI, etc.
5. Reliability: target ≥80% over 100 runs; ≥90% trigger reproducibility.
6. Payload: generate shellcode/payload (pwntools `asm()`, ROPgadget `--ropchain`), respecting bad characters.

**Exit criteria:** control achieved (PC hijack / arbitrary R-W / logic bypass), mitigation strategy documented, payload verified against bad-chars + size limits, reliability ≥80%.

### 5e. CVE Reproduction (EAGER pipeline)

**Trigger:** phase 5a identified a matching CVE for the target's stack, AND the ROE permits active exploitation, AND a vulnerable version can be rebuilt.

**Actions:** run the `cyber-cve-reproduction` EAGER pipeline:
1. **Processor**: fetch CVE record (description, CWE, patch commits, advisories, PoCs), build knowledge base.
2. **Builder**: rebuild the vulnerable environment (Docker/VM with the vulnerable version).
3. **Exploiter**: generate PoC (replicate published PoC or craft new one from patch-diff + CWE guidance). Developer + critic agents in ReAct loop.
4. **CTF Verifier**: build independent verifier (flag-based confirmation that the exploit triggers the vuln).

**Exit criteria (EAGER):** Exploit generated, Assessed (verifier confirms), Generalizable (documented for the CWE), End-to-end automated, Rebuilt environment.

## Cross-Pipeline Feedback (the AIxCC lesson)

The two pipelines (pentest + exploit research) reinforce each other. This is not optional — it is the core architectural advantage of the combined skill:

| From | To | What flows |
|---|---|---|
| Pentest recon | CVE research | Service fingerprints → version identifiers → CVE lookup |
| CVE research | Exploit dev | Matching CVE → known vulnerability class → targeted exploit attempt |
| Fuzzing | Exploit dev | Crash inputs → root-cause → primitive → weaponization |
| Exploit dev | Fuzzing | Failed PoV attempts → fuzzer seeds (near-misses are valuable) |
| Fuzzing | CVE research | Coverage maps → uncovered paths → check if uncovered path matches a known CVE pattern |
| Binary analysis | Exploit dev | Sink locations → targeted PoV generation (not blind fuzzing) |
| Binary analysis | CVE research | Patch-diff → root cause → variant analysis (same pattern elsewhere) |
| Crash triage | All | Root-cause classification → informs which pipeline to prioritize |
| Pentest findings | CVE reproduction | A web finding (e.g., ViewState exposed) → check if the framework version has a known CVE → EAGER pipeline |

## Extended Multi-Agent Fan-Out

Inherits all agents from `cyber-penetration-loop` and adds:

- **cve-researcher-agent** — takes all fingerprinted components from recon, searches NVD/ExploitDB/GHSA/CISA KEV/vendor advisories for matching CVEs. Returns `CVE_MATCH <id> <cve> <exploitability>` or `NO MATCH`. Runs on captured evidence (works even when WAF-blocked).
- **binary-analyst-agent** — when a binary target is identified, runs Ghidra headless analysis, decompilation, input→sink tracing, patch-diffing. Returns `CANDIDATE <sink> <call-chain> <hypothesis>` or `NO CANDIDATE`.
- **fuzzer-agent** — writes/obtains fuzzing harness, generates LLM seeds, runs AFL++/libFuzzer campaign (time-budgeted). Returns `CRASH <input> <sanitizer_output> <exploitability>` or `NO CRASH <coverage_summary>`.
- **exploit-dev-agent** — takes a confirmed crash/primitive, develops reliable exploit (ROP, ret2libc, shellcode). Returns `EXPLOIT <poc_script> <reliability> <mitigations_bypassed>` or `NO EXPLOIT <reason>`.
- **cve-repro-agent** — takes a CVE match, runs the EAGER pipeline (Processor→Builder→Exploiter→Verifier). Returns `REPRODUCED <cve> <poc> <verifier>` or `FAILED <cve> <reason>`.
- **cross-pipeline-agent** — monitors all other agents' outputs, routes feedback between pipelines (failed exploit → fuzzer seeds, coverage → exploit dev, CVE → exploit dev, etc.). This is the coordination layer that makes the combined skill more than the sum of its parts.

## Extended Stop Rules

Inherits all stop rules from `cyber-penetration-loop` and adds:

8. **No new CVEs found** in a generation where CVE research was run → the stack is either fully patched or unidentifiable; stop the CVE-research branch.
9. **Fuzzing budget exhausted** — the time/compute budget for fuzzing (set at invocation) is spent; stop the fuzzing branch.
10. **No new crashes** after N fuzzing hours (default 4) with coverage plateau → the fuzzer has hit diminishing returns; stop.
11. **Exploit reliability ceiling** — after 3 failed attempts to weaponize a crash into a reliable exploit, stop the exploit-dev branch for that crash (the crash is still a DoS finding).

## Extended Output

Inherits all output artifacts from `cyber-penetration-loop` (`run-metrics.json`, `depth-map.md`, `attack-tree.json`, `findings.json`, `service-matrix.json`, `credential-ledger.json`, `scanner-validation.json`, `report-lint.json`) and adds:

### CVE Catalog (`cve-catalog.json`)

```json
{
  "target_components": [
    {"component": "openresty", "version": "unknown", "source": "Server header", "cves_found": 12}
  ],
  "cve_matches": [
    {
      "cve": "CVE-2026-9256",
      "component": "openresty/nginx",
      "cvss": 9.2,
      "exploitability": "potential — version unconfirmed, RCE requires ASLR bypass",
      "status": "potential_finding",
      "reproduced": false,
      "finding_id": "F-11",
      "reference": "https://www.cve.org/CVERecord?id=CVE-2026-9256"
    }
  ],
  "reproduced_cves": [],
  "cves_by_severity": {"critical": 1, "high": 2, "medium": 5, "low": 4}
}
```

### Exploit Inventory (`exploit-inventory.json`)

```json
{
  "exploits": [
    {
      "id": "X-01",
      "target": "vuln_linux:8080",
      "type": "stack_overflow",
      "primitive": "PC control via ROP",
      "mitigations_bypassed": ["DEP", "ASLR"],
      "reliability": 0.85,
      "poc_path": "pocs/X-01/exploit.py",
      "cve": null,
      "finding_id": "F-07"
    }
  ]
}
```

## Extended Common Mistakes

Inherits all from `cyber-penetration-loop` and adds:

- **Running pentest and exploit research sequentially.** The pointernet lesson: if you pentest first and exploit-research second, the WAF may block you before you reach the research phase. Run both pipelines in parallel from Gen 0.
- **CVE research only on live services.** CVE research works on **captured evidence** — headers, HTML, banners. Even when WAF-blocked, you can research the stack. Always run phase 5a on captured fingerprints.
- **Fuzzing without LLM seeds.** Random-byte fuzzing stalls on complex input formats. Generate semantically-valid seeds (the AIxCC-winning technique). A Python script that produces valid inputs beats 10 hours of blind mutation.
- **Exploit dev without mitigation assessment.** Building a ROP chain then discovering the target has CFI is wasted effort. Run `checksec` first; load `cyber-mitigations`; plan the bypass before writing the chain.
- **Not feeding cross-pipeline.** A failed exploit attempt that almost triggered a crash is a **valuable fuzzer seed**. A fuzzer coverage gap is a **target for LLM PoV generation**. If the pipelines don't feed each other, you lose the combined skill's core advantage.
- **Active CVE exploitation without ROE permission.** Memory-corruption exploitation (heap overflow, UAF) is potentially destructive (crash, RCE). Unless the ROE explicitly permits it, flag as "potential — version verification required" and do NOT actively exploit.
- **Forgetting the binary constraint.** pwntools/ROPgadget work on ELF/PE, not Mach-O. Build Linux targets in Docker. Ghidra works on any arch. keystone-engine may fail on arm64 — use pwntools `asm()` instead.

## Invocation

This is the "give it everything" path. Example:

```
Maximum effort assessment on https://account.pointernet.co.il/ —
I own the system. Use all tools: pentest loop + exploit research + CVE
research + binary analysis + fuzzing if applicable. Exploration-driven,
max depth 8. Save under cyber-runs/pointernet-maxeffort/.
```

Or objective-driven:

```
Full spectrum on http://192.168.1.50:8080 — I own it. Objective:
achieve RCE by any means — web exploitation, CVE, binary exploit,
whatever it takes. Show me the chain. Stop on success.
```

## Routing

- "maximum effort" / "full spectrum" / "all tools" / "give it everything" → this skill
- "full/deep pentest" (pentest only, no exploit research) → `cyber-penetration-loop`
- "find a new bug in this code/binary" (research only, no pentest) → `cyber-vuln-research`
- "reproduce CVE-YYYY-NNNN" (single CVE) → `cyber-cve-reproduction`
- "pentest this deployed system" (pentest only) → `cyber-penetration-loop`
