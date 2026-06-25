---
name: cyber-defensive-ops
description: Use when performing blue-team / defensive cybersecurity work — alert triage, threat hunting, log analysis, forensics, incident response, detection engineering, hardening, or post-breach investigation. Triggers include SOC, triage, alert, SIEM, threat hunt, IOC, forensics, incident response, IR, containment, detection rule, hardening, malware analysis, root cause of a breach. This is the defensive counterpart to offensive testing — coverage Strix lacks.
---

# Defensive Operations (Blue Team)

## Overview

Defensive work is the mirror of offensive: instead of finding the path in, you detect the path in, contain it, and harden so it can't recur. The agent advantage here is the same as offense — scale and correlation across logs/events that a human triager can't hold in head.

**Core principle:** Hypothesis-driven. Every defensive action starts from a question ("is host X compromised?", "what did this alert actually mean?") and ends in evidence, not a vibe.

## When to Use

- User reports a breach / suspicious activity / "is this malicious?"
- Alert triage (SIEM/EDR alert → verdict).
- Proactive threat hunting.
- Forensics on an image/logs/system.
- Hardening / detection-rule authoring.
- Post-engagement: turn red-team findings into detections.

## Workflows

### Alert Triage
1. **Understand the detection** — what rule fired, what it asserts (e.g., "powershell encoded command from Word").
2. **Enrich** — host, user, process lineage, parent process, network connections, file writes. Pivot across log sources.
3. **Contextualize** — is this expected for the asset/role? Baseline vs anomaly.
4. **Verdict** → Benign-true-positive / False-positive / True-positive-malicious. Justify with evidence.
5. **Escalate** true-malicious to IR; tune false-positives into the detection.

### Threat Hunting (hypothesis-driven)
1. **Form a hypothesis** — "attacker X uses living-off-the-land binaries; check for `wmic`/`certutil` from unusual parents."
2. **Query** logs/EDR/SIEM via `bash` (journalctl, auditd, ELK API, Splunk) or parse exported logs with `eval`.
3. **Find anomalies** — statistical baselines, rare-event, frequency.
4. **Confirm/deny** — does the evidence support the hypothesis?
5. **Outcome** → new detection rule OR documented negative.

### Forensics
1. **Preserve** — work on copies, never originals. Note chain of custody if it'll matter.
2. **Timeline** — order events across sources (filesystem mtime, logs, registry, browser history).
3. **Artifacts** — persistence (cron, LaunchAgents, systemd, run keys, startup), lateral movement (auth logs, SMB), exfil (netflow/DNS volume anomalies).
4. **Scope** — which hosts/users/timeframe affected.
5. **Root cause** — initial access vector (the gap to close).

### Incident Response (NIST lifecycle)
1. **Preparation** (tooling, contacts) → 2. **Detection & analysis** (triage/forensics) → 3. **Containment** (isolate host, revoke creds, block C2) → 4. **Eradication** (remove persistence, patch) → 5. **Recovery** (restore from known-good, monitor) → 6. **Lessons learned** (write the post-mortem + new detections).

### Detection Engineering
- Write rules in the target's language (Sigma, Splunk SPL, Elastic EQL/KQL, YARA for files, Surata/Snort for net).
- **Test for both directions** — fires on the malicious sample AND does not fire on benign baseline. A detection that only proves the positive is half-built.
- Map to MITRE ATT&CK techniques (T-ID) for coverage tracking.

### Hardening
- Least privilege, patch the known CVEs recon fingerprinted, disable unused services, enforce MFA, network segmentation, secrets rotation, input validation at sources (the white-box sinks you'd exploit — fix them).

## Tool Mapping (defensive)

| Task | My tool |
|---|---|
| Query/parse logs | `bash` (journalctl/auditd/grep) + `eval` (parse JSON/CSV/PCAP with Python) |
| PCAP analysis | `eval` (scapy/pyshark) or `bash` (`tshark`, `tcpdump`) |
| Malware static | `eval` (pefile, strings, capstone), `bash` (`strings`, `file`, `yara`) |
| Malware dynamic | recommend an isolated sandbox; never detonate on the host you run on |
| Detection rule authoring/test | `write` rules; `eval` to test against sample + benign sets |
| Correlation at scale | `task` — one subagent per log source, synthesize timeline |

## Multi-Agent Defensive Orchestration

Fan out via `task`:
- **log-source-agent(s)** — one per source (EDR, proxy, auth, DNS), each extracts IOCs/events for the window.
- **timeline-agent** — merges into a single ordered timeline.
- **correlation-agent** — links events across sources (process→network→file).
- **verdict-agent** — proposes verdict + root cause from the timeline.

Each subagent returns evidence (raw log lines), not conclusions. The verdict agent's claim must cite the timeline entries.

## Common Mistakes

- **Acting on the alert headline.** Read the detection logic; headlines mislead.
- **Working on originals.** Forensics on the live/only copy destroys evidence and mtime.
- **Detonating malware on the analysis host.** Always isolated sandbox.
- **Containment before scoping.** Isolating one host while the actor is on three others extends the incident.
- **Untuned noisy detections.** A rule firing 1000×/day gets ignored; test against benign baseline.
- **No post-mortem.** An incident without lessons-learned + new detections recurs.

## Ethics

Defensive work is on systems you're authorized to defend. IR may involve real user data — handle per policy, minimize exposure, and preserve evidence integrity. Don't "clean up" before scoping — it destroys the root-cause trail.
