---
name: cyber-reverse-engineering
description: Reverse-engineering methodology for closed-source binaries — Ghidra headless + GUI workflow, lldb/gdb/pwndbg debugging, decompilation, function identification, cross-referencing untrusted input to sinks, and patch-diffing with Diaphora. Use when the target is a binary (no source), when analyzing stripped firmware/binaries, when diffing patches to find the vulnerability, or when tracing execution in a debugger. Triggers include reverse engineering, RE, decompile, disassemble, Ghidra, lldb, gdb, pwndbg, stripped binary, firmware analysis, patch diffing, Diaphora, binary audit.
---

# Reverse Engineering

## When to use

The target is a binary (ELF/Mach-O/PE), firmware, or you need to diff a patch against an unpatched binary to localize a vulnerability. RE bridges `cyber-bug-identification` (which assumes source) and `cyber-exploit-development` (which needs to know *where* and *how* to trigger).

## Toolchain on this machine (macOS arm64)

| Purpose | Tool | Invocation |
|---|---|---|
| Disassembly + decompilation | **Ghidra** (12.1.2) | GUI: `ghidraRun`; headless: `analyzeHeadless <project> <projname> -import <bin>` |
| Patch-diffing | **Diaphora** | Ghidra plugin at `/tmp/diaphora/`; export both versions to SQLite, then Diff |
| Native debugger (macOS) | **lldb** | `lldb <bin>` (ships with Xcode) |
| Debugger (Linux targets) | **gdb + pwndbg** | install pwndbg inside the Linux VM where the target runs |
| Gadget hunting | **ROPgadget** / **ropper** | `ROPgadget --binary <bin> --ropchain` |
| Disassembly lib | **capstone** (Python) | `from capstone import *` |
| Assembly lib | **keystone** | ⚠️ arm64 dylib load fails on this host; use pwntools `asm()` with GNU as backend, or run inside a Linux VM |
| Exploit framework | **pwntools** | `from pwn import *` |

## Ghidra headless workflow (scriptable RE)

```bash
# 1. Create a project and auto-analyze a binary (one shot)
analyzeHeadless /tmp/ghidra_proj proj -import /path/to/binary \
  -postScript /path/to/your_script.java -scriptPath /path/to/scripts \
  -deleteProject   # ephemeral; drop to keep the project

# 2. Export decompiled C to a file for review
analyzeHeadless /tmp/ghidra_proj proj -import /path/to/binary \
  -postScript DecompileAllFunctions.java -scriptPath /tmp/scripts \
  -deleteProject > decompiled.c 2>/dev/null
```

Useful Ghidra scripts to keep in a `scripts/` dir: `DecompileAllFunctions`, `FindDangerousFuncs` (custom — grep decompiler output for `strcpy`/`memcpy`/`sprintf`/`system`/`exec`), and a cross-reference dumper that, for each call to a sink, prints the call-chain back to an entry point.

## The RE workflow

### 1. Triage the binary
```bash
file <bin>                 # arch, linkage, stripped?
checksec --file=<bin>      # mitigations: NX, PIE, RELRO, canaries (→ cyber-mitigations)
strings -n 8 <bin> | head  # version banners, debug strings, format hints
```
Record: arch (x86_64/arm64), format (ELF/PE/Mach-O), stripped?, mitigations, linked libs.

### 2. Map functions and data
- Ghidra auto-analysis → list functions. For stripped binaries, rename by signature (FLIRT) or by behavior.
- Identify: `main`, command handlers, parsers, the dispatch table, error-handling paths.
- Build a call graph from each *entry point* (network recv, file read, argv) inward.

### 3. Trace untrusted input to sinks (the bug hunt)
- Find sinks: `strcpy`, `strcat`, `sprintf`, `gets`, `memcpy` with attacker-controlled length, `system`/`exec` with attacker data, `free` followed by use, format-string funcs (`printf` with non-literal), integer-guarded allocations.
- For each sink, walk the cross-references *backward* to an entry point. If attacker-controlled data reaches the sink unchecked → candidate vulnerability.
- Decompile the candidate function, read the logic, form a hypothesis about the trigger.

### 4. Dynamic confirmation (debugger)
- Set a breakpoint at the sink. Feed a crafted input. Confirm the data arrives controllably.
- lldb quickstart:
  ```
  lldb <bin>
  (lldb) b strcpy          # break on symbol
  (lldb) run <crafted_input>
  (lldb) register read     # arg registers (rdi/rsi/rdx on x86_64; x0..x7 on arm64)
  (lldb) bt                # call stack back to entry
  (lldb) memory read $rsi  # inspect the attacker buffer
  ```
- For Linux targets, run gdb+pwndbg inside the target VM for `context` (regs + disasm + stack) views.

### 5. Patch-diffing (N-day / variant analysis)
When a patch exists but you have binaries (not source):
1. Analyze both patched and unpatched binaries in Ghidra, export to Diaphora databases.
2. Diaphora "Diff" → best-match functions; the changed functions are the fix.
3. Diff the decompiled C of the changed functions → the root cause + the check that was added.
4. Now craft the PoC against the *unpatched* version, and hunt for the same pattern in *other* functions (variant analysis).

## Output

- `re_notes.md` — triage, function map, candidate sinks with call-chains, hypotheses.
- Decompiled snippets of candidate functions (annotated).
- Debugger traces proving controllable data reaches the sink.
- Hand off confirmed candidates to `cyber-exploit-development` for PoC weaponization.

## Routing

- Binary target, no source → this skill, then `cyber-exploit-development`.
- Source available → `cyber-bug-identification` (cheaper than RE).
- Reproduce a *known* patched CVE from binaries → this skill (patch-diff) → `cyber-cve-reproduction`.
