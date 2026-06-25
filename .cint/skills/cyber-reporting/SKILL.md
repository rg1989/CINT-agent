---
name: cyber-reporting
description: Use when writing up security findings, a penetration test report, a remediation plan, or a vulnerability disclosure. Triggers include report, findings, write-up, disclosure, CVSS, severity, remediation, fix recommendation, executive summary, pentest report. Load for the reporting/remediation phase of an engagement.
---

# Security Reporting & Remediation

## Overview

A report is the deliverable a stakeholder acts on. A finding they can't reproduce or fix is noise. Reports must be precise, evidence-backed, severity-calibrated, and actionable — written for the engineer who has to fix it and the exec who has to prioritize it.

**Core principle:** Every finding carries its own reproduction. A reader following your steps reproduces the bug without you.

## Directory Layout (one dir per engagement)

Create `cyber-runs/<run-name>/` containing:

```
cyber-runs/<run-name>/
├── ROE.md                 — scope, target confirmation, exclusions, depth, rules of engagement
├── surface.md             — attack surface map
├── findings.json          — AUTHORITATIVE source for all finding IDs, severities, CWE, CVSS,
│                            evidence paths, status. Every count in the report derives from this file.
│                            Hand-counting totals is prohibited.
├── service-matrix.json    — every port: fingerprint, type, classification
│                            (verified finding / benign / intended public / out-of-scope)
├── credential-ledger.json — recovered secrets with source, target service, type,
│                            validation_status (candidate/verified/invalid/untestable-with-reason),
│                            validation evidence
├── scanner-validation.json — every scanner hit with verdict (verified/false_positive/inconclusive)
│                             + manual reproduction notes
├── depth-map.md           — text depth map + capability genome + chains + out-of-scope observations
├── journal.md             — every port probed (response code), every endpoint tested (result),
│                            every technique tried (outcome). A generation is NOT complete until journaled.
├── evidence/raw/          — untouched raw artifacts
├── evidence/redacted/     — redacted copies; DRAFT THE REPORT FROM THESE, never from raw
├── poc/<finding-id>/      — full PoC transcripts per finding
├── report.md              — markdown source (deliverable)
├── report.html            — self-contained HTML (deliverable)
└── report-lint.json       — quality-gate results (blocks finalization)
```

**Loop-only artifacts** (write these ONLY if the engagement ran the recursive deepening loop; omit entirely for linear/single-layer runs):
- `run-metrics.json` — target, mode, max_depth_achieved, total_generations, positions_by_outcome, total_findings, findings_by_severity, capability_genome, deepest_chain, stop_reason
- `attack-tree.json` — nodes (id, label, depth, depth_label, outcome, service, generation, vector, capabilities_gained, finding_id, severity, is_deepest) + edges + generations

## Evidence Redaction (mandatory, before drafting)

Create redacted copies of all evidence. Draft the report from `evidence/redacted/`, never from `evidence/raw/`.

Mask direct identifiers unless the exact value is essential to reproduction:
- Phone/IMSI/IMEI/user-IDs: partial mask (e.g., `05XXXXXXXX`, `4250303XXXXXXXX`)
- GPS coordinates: reduce precision to minimum needed for the finding
- API keys/access keys: always mask (e.g., `AKIA...NU5P`)
- Email/user IDs: partial mask

Raw values stay in `evidence/raw/` only; never in the main report unless explicitly required and approved.

## Finding Record (the atomic unit — every finding is self-contained)

```
## [ID] <Title>  — Severity: <Critical|High|Medium|Low|Info>

**Summary:** one sentence — what + where + impact.
**Affected:** host/app/file:line/endpoint.
**Preconditions:** auth, privileges, input conditions required.
**PoC:** exact steps/requests/commands, raw — don't paraphrase.
**Observed result:** paste the REAL response/output proving the vuln.
**Impact:** what an attacker gains (concrete, not "could be bad").
**CVSS 3.1:** <vector> → <score>.
**Remediation:** concrete fix (file:line + corrected code); list every other instance
                of the same anti-pattern; rank by effort × impact. NOT "sanitize inputs."
**References:** CWE (REQUIRED — every finding needs primary_cwe mapping root cause),
               OWASP, CVE if applicable.
```

### Rejection Rule (non-negotiable)

A finding missing PoC or observed result is **REJECTED**, not published. Scanner-only results (nuclei/nikto/nmap NSE/ffuf) are **CANDIDATES**, not findings — manually reproduce before counting. A 693-byte SPA `index.html` fallback is not a source map, no matter what nuclei says. If the response is a generic fallback page, SPA shell, 404 wrapper, or wrong content type, mark `false_positive` and suppress.

## Severity Calibration (CVSS 3.1, not vibes)

Score on CVSS 3.1 vector. Key axes: Attack Vector (N/A/L/P), Complexity (L/H), Privileges (N/L/H), User Interaction (N/R), Scope (U/C), Confidentiality/Integrity/Availability (H/L/N).

- **Critical (9.0+):** Unauth RCE, auth bypass, DB dump, cloud credential leak.
- **High (7.0–8.9):** Auth SQLi, stored XSS on admin, SSRF to metadata creds, IDOR to sensitive data at scale.
- **Medium (4.0–6.9):** Reflected XSS, CSRF on non-critical state, open redirect (non-OAuth), info disclosure of internals.
- **Low (0.1–3.9):** Version banner leak, verbose errors without exploit path, missing security headers.
- **Info:** Best-practice gaps with no direct exploit.

Chain bugs = one finding at the chain's effective severity (often Critical), with the chain as the PoC.

## Report Structure (worst-case-first)

1. **(Loop only) Metrics banner + attack-tree infographic** — include ONLY if `run-metrics.json` AND `attack-tree.json` exist; otherwise OMIT entirely — do not stub, do not placeholder.
2. **Executive summary** — scope, method, top risks in plain language, overall risk rating. (Execs read only this.)
3. **Scope & ROE** — what was tested, how, when, exclusions.
4. **Methodology** — recon → discovery → validation; tools used. For loop engagements, include the depth ladder and capability genome.
5. **Findings** — sorted by severity, each the self-contained record above.
6. **Risk register / summary table** — ID, title, severity, status.
7. **Remediation roadmap** — prioritized fixes (Critical now, High next sprint…).
8. **Appendix** — full PoC transcripts, raw outputs, scan artifacts, depth map, attack tree JSON.

### Loop-Only Opener (recursive engagements only)

Include ONLY if `run-metrics.json` AND `attack-tree.json` exist; otherwise omit entirely.

**Metrics banner** — stat cards at the top of the report:
- Max depth (colored: red L3+, orange L2, yellow L1, green L0)
- Generations (iteration count)
- Positions by outcome (exploited / dead-end / out-of-scope / pruned)
- Findings by severity (critical / high / medium / low)
- Stop reason

**Attack-tree infographic** — self-contained inline SVG/CSS/JS, no external deps:
- Left-to-right tree, generation = column.
- Node colors: green = `exploited`, red = `dead_end`, yellow = `infra_finding`, gold border = `is_deepest`, gray = `out_of_scope`/`pruned`, blue = `root`.
- Edges labeled with exploit vector.
- Hover expands to: vector, capabilities gained, finding ID, severity, PoC link.
- If >20 nodes, collapse dead-end/out-of-scope into summary counts with expand-on-click.
- For the `.md` report, include a text-tree approximation + a note pointing to the HTML for the interactive view.

Example text approximation:
```
         Gen 0: Recon & Sweep          Gen 1: Exploit Fan-Out
         ─────────────────────          ────────────────────────
  L2 ─┐                                   ┌── [DEEPEST] P1: AI Assistant :8083 ── L2
      │                                   │   [EXPLOITED] run_read_sql → 20 assets
  L1 ─┤    P0: External ─────────────────┼── P2: Elasticsearch :9200 ────────── L1
      │    [ROOT] target                  │   [EXPLOITED] 5,508 PII records
  L0 ─┘                                   ├── P3: C2 Framework :8000 ─────────── L1
                                          │   [EXPLOITED] admin:F00b4r, video
                                          ├── P4: Kafka UI :8090 ────────────── L1
                                          │   [EXPLOITED] readOnly:false
                                          ├── P5: Keycloak :8180 ────────────── L0
                                          │   [DEAD END] default creds failed
                                          ├── P6: PostgreSQL :5432 ──────────── L0
                                          │   [INFRA] exposed DB port
                                          └── P7: 100.102.32.65 ─────────────── L0
                                              [OUT OF SCOPE]
```

## Deliverables (always both, regardless of loop or linear)

- **`report.md`** — markdown source.
- **`report.html`** — dark-themed, SELF-CONTAINED (inline CSS/SVG/JS, no external requests), persistent sidebar nav, worst-case-first.
- Optional: `how-the-hack-works.html` — beginner-friendly walkthrough.

## Quality Gates (block finalization — save to `report-lint.json`)

No report ships until lint passes with zero inconsistencies:
- Severity counts in banner == findings list counts (derive from `findings.json` only — manual totals are prohibited).
- Banner total == unique finding count.
- Risk register entries map 1:1 to finding IDs.
- Every finding has: severity + evidence path + `primary_cwe` + status.
- PII redaction reviewed.

## Remediation Quality

Bad: "Sanitize inputs." / "Use parameterized queries." (vague)

Good: "In `src/api/users.ts:42`, replace the string-concatenated query with a parameterized query using the existing `db.query(sql, [params])` helper. The same pattern exists in `orders.ts:88` and `auth.ts:31` — fix all three."

- Point to the exact file/line.
- Show the corrected code.
- List every other instance of the same anti-pattern (search the codebase — `ast_grep`/`search`).
- For config issues, give the exact config block.
- Rank by effort × impact.

## Post-Engagement (turn red into blue)

For each confirmed finding, ship a detection so it doesn't recur unnoticed — see `cyber-defensive-ops` (Detection Engineering). Offense → fix → detect is the full loop.

## Common Mistakes

- **Findings without reproduction.** Rejected. Always.
- **Vague remediation.** "Sanitize inputs" helps no one.
- **Severity by gut.** Use CVSS; document the vector so it's debatable.
- **Burying the lede.** Exec summary must lead with the worst risks.
- **Inflating counts.** One bug across three endpoints = one finding with three instances, not three findings.
- **No chain documentation.** High-impact chains must show the full path as one finding.
- **Drafting from raw evidence.** Draft from `evidence/redacted/` — raw PII never enters the report.
- **Missing CWE.** Every finding needs `primary_cwe` mapping the root cause. Reports with missing CWE fail the gate.
- **Hand-counting findings for the banner.** If the banner total doesn't match the findings list, the report fails lint. Derive all counts from `findings.json`.
- **Stubbing loop-only sections.** If `run-metrics.json` doesn't exist, omit the metrics banner entirely — don't write "N/A" or "not applicable" placeholders.
