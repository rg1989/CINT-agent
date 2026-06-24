# CINT — Cyber Intelligence

**By [Roman Grinevich](https://www.linkedin.com/in/roman-grinevich-03b13bab/)**

CINT is a coding agent with the IDE wired in, rebranded and extended with a full cyber security and exploit development toolchain. Works best with open-weight, unrestricted models — tested and optimized for Z-AI GLM-5.2.

Memory is managed by the Mnemosyne backend — automatic semantic recall and retention. No vault files needed.

## Cyber Security Suite

CINT ships with a complete offensive and defensive cyber capability bundle. Before ANY response or action involving security work, check: might a cyber skill apply? Even 1% chance → invoke the relevant skill.

**Core cyber workflow**: `/cyber-recon` → `/cyber-web-exploitation` → `/cyber-exploit-validation` → `/cyber-reporting`

**Apex skill**: `cyber-full-spectrum-loop` — combines pentest + exploit research + CVE research + binary analysis + fuzzing + exploit dev in a single recursive loop. Use for "give it everything," "full spectrum," "all tools."

### Penetration Testing Skills (9)
- `pentest` — Full-stack pentest entry: 5-phase methodology, 26 tools
- `cybersec-operations` — Router for full cyber assessment lifecycle
- `cyber-recon` — Reconnaissance & attack-surface mapping
- `cyber-web-exploitation` — Web vuln testing: SQLi, XSS, SSRF, RCE, auth bypass
- `cyber-exploit-validation` — Validates findings with PoCs (non-destructive)
- `cyber-defensive-ops` — Defensive analysis, hardening, detection engineering
- `cyber-tool-playbooks` — Tool-specific usage guides (nmap, nuclei, ffuf, sqlmap, semgrep)
- `cyber-penetration-loop` — The recursive agentic loop for deep multi-layer pentest
- `cyber-reporting` — Worst-case-first vulnerability reports (.md + .html)

### Exploit Research Skills (13)
- `cyber-vuln-research` — Exploit-researcher entry/orchestrator
- `cyber-cve-reproduction` — Reproduce known CVEs via EAGER pipeline
- `cyber-reverse-engineering` — RE for closed-source binaries: Ghidra, lldb/gdb+pwndbg
- `cyber-fuzzing` — Offensive fuzzing: AFL++/libFuzzer/Honggfuzz/Boofuzz
- `cyber-bug-identification` — Source-review bug hunting: dangerous-function grep, taint
- `cyber-vuln-classes` — Vulnerability-class taxonomy with CVE case studies
- `cyber-crash-analysis` — Crash triage & exploitability: ASAN/MSAN, WinDbg/GDB/lldb
- `cyber-exploit-development` — Exploit-dev ops: pwntools, heap exploitation, weaponization
- `cyber-basic-exploitation` — Foundational: EIP/RIP control, ROP, ret2libc, shellcode
- `cyber-mitigations` — Mitigation reference + bypass: ASLR, DEP/NX, RELRO, canaries, CFI
- `cyber-toctou` — TOCTOU race exploitation across binary/kernel/fs/web/container
- `cyber-exploit-dev-course` — Exploit-dev curriculum roadmap
- `cyber-fuzzing-course` — Fuzzing methodology curriculum

### Installed Cyber Tools
subfinder, naabu, nmap, masscan, httpx, katana, ffuf, nuclei, sqlmap, arjun, dirsearch, wafw00f, semgrep, ast-grep, bandit, trivy, trufflehog, gitleaks, jwt_tool, interactsh, hydra, john, hashcat, python3, docker, Ghidra, AFL++, pwntools, ROPgadget, ropper, capstone, lldb, gdb, pwndbg.

**Routing rule**: For "full"/"deep"/"multi-layer" pentest → `cyber-penetration-loop`. For flat/single-finding → `cybersec-operations`. For "find/discover a new bug" → `cyber-vuln-research`. For "reproduce this known CVE" → `cyber-cve-reproduction`.

**Mandatory**: authorization gate first, worst-case-first reporting, non-destructive testing only, one directory per engagement: `cyber-runs/<run-name>/` with `ROE.md`, `surface.md`, `findings.md`, `journal.md`, `poc/`.

**Tool installation**: Run `cint --install-cyber-tools` to install the full toolchain. Run `cint --install-cyber-tools --check` to verify what's installed.

## Development Rules

This repo contains multiple packages, but **`packages/coding-agent/`** is the primary focus. Unless otherwise specified, assume work refers to this package.

**Terminology**: When the user says "agent" or asks "why is agent doing X", they mean the **coding-agent package implementation**, not you (the assistant). The coding-agent is a CLI tool (`cint`) — questions about its behavior refer to code in `packages/coding-agent/`, not your current session.

### Package Structure

| Package                 | Description                                          |
| ----------------------- | ---------------------------------------------------- |
| `packages/ai`           | Multi-provider LLM client with streaming support     |
| `packages/catalog`      | Model catalog: bundled models.json, provider descriptors |
| `packages/agent`        | Agent runtime with tool calling and state management |
| `packages/coding-agent` | Main CLI application (primary focus)                 |
| `packages/tui`          | Terminal UI library with differential rendering      |
| `packages/natives`      | Bindings for native text/image/grep operations       |
| `packages/stats`        | Local observability dashboard (`cint stats`)          |
| `packages/utils`        | Shared utilities (logger, streams, temp files)       |
| `crates/pi-natives`     | Rust crate for performance-critical text/grep ops    |

**Catalog import convention**: code in this repo imports catalog *values* from `@incrt/cint-catalog/<module>`.
