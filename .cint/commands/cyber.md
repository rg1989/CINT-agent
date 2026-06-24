# /cyber — CINT Cyber Intelligence Operations Entry Point

Launches a cyber engagement against the provided target or scope. Walks the
agent through authorization → skill selection → setup → execution → reporting.

**Arguments:** `$ARGUMENTS` — a target URL, IP/CIDR, domain, scope
description, or CVE identifier.

**Non-destructive testing only.** No payload may delete, modify, or corrupt
data, or cause denial of service. Active testing begins only after the
authorization gate is passed.

---

## Workflow

Follow these phases in order. Do not skip the authorization gate.

### Phase 0 — Parse the target

Parse `$ARGUMENTS` to determine the engagement type:

- **URL / domain / IP** → penetration testing (deployed system assessment).
- **Source path / binary path** → exploit research (vulnerability discovery).
- **CVE-YYYY-NNNNN** → CVE reproduction (known vulnerability).
- **"maximum effort" / "full spectrum" / "all tools"** → apex skill.

Record the parsed target and type. If `$ARGUMENTS` is empty, ask the user
for the target and scope before proceeding.

### Phase 1 — Authorization Gate (MANDATORY)

Before any active testing, confirm and record authorization:

1. Ask the user to confirm they have written authorization for the target.
2. Ask for the scope: which assets are in-scope, which are explicitly
   out-of-scope, any time windows, any constraints.
3. Create the engagement directory and write `ROE.md` (template below)
   *before* running any tool that sends traffic to the target.

If authorization is not confirmed, STOP. Do not proceed to Phase 2. Record
the request and the blocker in the journal.

### Phase 2 — Skill Selection

Based on the engagement type and target, select the appropriate skill from
the **CINT Cyber Intelligence Suite** (`cyber-suite` skill). Reference that
skill for the full capability map and trigger routing.

**Routing guide:**

| Engagement type | Primary skill |
|---|---|
| Pentest of a deployed system | `cyber-penetration-loop` (recursive deepening) or `pentest` (simple entry) |
| Single finding / flat assessment | `cybersec-operations` lifecycle |
| Vulnerability discovery (source/binary) | `cyber-vuln-research` |
| Reproduce a known CVE | `cyber-cve-reproduction` |
| Closed-source binary analysis | `cyber-reverse-engineering` |
| Fuzzing a parser/target | `cyber-fuzzing` |
| Web vuln testing | `cyber-web-exploitation` |
| Recon / attack-surface mapping | `cyber-recon` |
| Validate a candidate finding (PoC) | `cyber-exploit-validation` |
| Defensive analysis / hardening | `cyber-defensive-ops` |
| Tool usage syntax | `cyber-tool-playbooks` |
| Maximum effort / everything | `cyber-full-spectrum-loop` (apex) |

State which skill(s) you are loading and why.

### Phase 3 — Engagement Setup

Create the engagement directory and skeleton files:

```
cyber-runs/<run-name>/
├── ROE.md          # Rules of engagement (from Phase 1)
├── surface.md      # Attack surface map (populated during recon)
├── findings.md     # Confirmed findings (worst-case-first)
├── findings.html    # Rendered report (generated at close)
├── journal.md      # Timestamped log of every action
└── poc/            # Proof-of-concept scripts & artifacts
```

Choose `<run-name>` as a short kebab-case identifier derived from the target
and date (e.g. `acme-web-20260624`). Record the directory path in the
journal.

Verify tools are available before depending on them:

```
cint --install-cyber-tools --check
```

If a required tool is missing, note it in the journal and either install it
(with the user's permission) or proceed with an alternative.

### Phase 4 — Execution

Execute the engagement following the selected skill's methodology. Log every
action and observation in `journal.md` with timestamps. Populate
`surface.md` as the attack surface is mapped.

**Non-destructive constraints:**
- No payloads that delete, modify, or corrupt data.
- No credential extraction from production stores.
- No denial-of-service techniques.
- Stop immediately on any sign of unintended impact; record in journal.

**Finding discipline:**
- A finding requires a reproducing PoC. No PoC → it is a *lead*, not a
  finding. Leads are tracked but not reported as confirmed.
- Score each finding worst-case-first: the most severe credible impact.
- Store PoCs under `poc/` with reproducible commands.

### Phase 5 — Reporting

At engagement close, produce both deliverables:
- `findings.md` — full findings with CVSS, reproduction steps, remediation.
- `findings.html` — rendered HTML for stakeholder distribution.

Summarize in the journal: findings count by severity, tools used, scope
covered, any open leads for follow-up.

---

## Rules of Engagement (ROE) Template

Copy the following into `ROE.md` and fill in every field before any active
testing begins. Unfilled fields block execution.

```markdown
# Rules of Engagement

## Engagement
- **Run name:** <run-name>
- **Date opened:** <YYYY-MM-DD>
- **Operator:** <name / agent id>
- **Sponsor / authorizing party:** <name & relationship to target>

## 1. Authorization

- [ ] Written authorization obtained (reference: <document / program / ticket>)
- [ ] Authorization covers all in-scope assets listed below
- [ ] Authorization verified by operator on <YYYY-MM-DD>

Authorization source / reference:
<Where authorization is recorded — signed SOW, bug bounty program scope,
internal ticket, explicit email, etc.>

## 2. Scope

### In-scope assets
<Explicit list: IPs, CIDRs, domains, URLs, applications, binaries, source
repos. One per line.>

- 
- 
- 

### Out-of-scope assets (explicit)
<Assets that must not be touched, even if reachable from in-scope systems.>

- 
- 
- 

### Engagement type
<pentest | exploit research | CVE reproduction | defensive | full-spectrum>

## 3. Constraints

### Permitted techniques
- [ ] Passive reconnaissance (no target interaction)
- [ ] Active scanning (port/service/version detection)
- [ ] Vulnerability exploitation (non-destructive PoC only)
- [ ] Web application testing
- [ ] Source code review
- [ ] Binary reverse engineering
- [ ] Fuzzing
- [ ] OOB interaction testing (interactsh)

### Prohibited techniques
- [ ] Data deletion, modification, or corruption
- [ ] Credential dumping from production stores
- [ ] Denial of service
- [ ] Privilege escalation beyond demonstration (no persistent access)
- [ ] Lateral movement to out-of-scope systems
- [ ] Social engineering
- [ ] Physical access attempts

### Time window
- **Start:** <YYYY-MM-DD HH:MM TZ>
- **End:**   <YYYY-MM-DD HH:MM TZ>
- Testing outside this window is prohibited.

## 4. Handling of findings

- Findings scored worst-case-first (most severe credible impact).
- Every confirmed finding has a reproducing PoC under `poc/`.
- No PoC = lead, not finding.
- Sensitive findings (e.g. live credentials, critical RCE) reported
  immediately to the sponsor; not held to engagement close.

## 5. Non-destructive testing commitment

The operator confirms that all testing is non-destructive. No payload will
delete, modify, or corrupt data, or cause denial of service. On any sign of
unintended impact, testing stops immediately and the event is recorded in
`journal.md`.

## 6. Incident / impact handling

If unintended impact occurs:
1. Stop all testing immediately.
2. Record the event in `journal.md` with timestamp.
3. Notify the sponsor.
4. Do not resume until cleared.

## 7. Sign-off

- **Operator:** ____________________  Date: __________
- **Sponsor:**   ____________________  Date: __________
```

---

## Reminders

- Reference the `cyber-suite` skill for the full capability map, tool
  inventory, and skill trigger routing.
- Authorization gate is mandatory and non-negotiable.
- One directory per engagement under `cyber-runs/<run-name>/`.
- Worst-case-first reporting; both `.md` and `.html` required.
- Non-destructive testing only.
