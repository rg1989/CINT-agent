---
name: cyber-recon
description: Use when mapping an attack surface before exploitation — enumerating subdomains, ports, services, endpoints, parameters, tech stack, or doing OSINT on a target. Triggers include reconnaissance, recon, asset discovery, subdomain enumeration, port scanning, content discovery, directory brute force, fingerprinting, attack surface mapping, OSINT. Load as the first active phase of any offensive engagement.
---

# Recon & Attack Surface Mapping

## Overview

Recon turns a confirmed target string (`./app`, `github.com/org/repo`, `https://host.com`, `10.10.11.23`) into a structured attack surface: hosts, ports, services, endpoints, parameters, technologies, identities. Every later phase consumes this map. Write it to `cyber-runs/<run>/surface.md`.

**Core principle:** Map before you attack. Unmapped surface = missed vulns and wasted exploit effort.

**Precondition (hard gate):** The target string MUST have been explicitly confirmed with the user in this engagement before recon begins (see `cybersec-operations` step 1 / `pentest` rule 1 — confirm via `ask`). If you arrived here without a confirmed target, STOP and confirm it before running any recon command. Never infer the target from context, file names, or prior runs.

## When to Use

Start of every offensive engagement (after ROE). Re-run incrementally as new hosts/endpoints surface during exploitation. White-box skips network recon in favor of source-driven surface.

## Recon Pipeline (by target type)

### Web app / API (black-box)
1. **Resolve & fingerprint** — tech stack, server, framework, CDN, WAF. `curl -sI`, `httpx`, Wappalyzer via `browser` (observe response headers, cookies, JS bundles). **Match fingerprinted versions against known CVEs immediately** — `web_search` for `"<component> <version> CVE"` and test each hit individually (single-request, high-signal). Don't wait for the nuclei sweep to surface CVEs; version-match early.
2. **Subdomain enumeration** — `subfinder` (passive) → `naabu`/`nmap` top ports on results. Cross-check certificate transparency (`crt.sh`).
3. **Content discovery** — `ffuf` against a quality wordlist (`raft`, `SecLists`), match on size/status/words; recurse on found dirs. Check `robots.txt`, `sitemap.xml`, `.git/`, `.env`, backup files.
4. **Crawl** — `katana` for endpoint/JS extraction; parse JS for API routes, secrets, hidden params. **Verify katana-discovered endpoints before probing** — JS string literals (examples, test data, comments, error messages) are not real routes. Cross-reference: if an endpoint only appears in static JS strings but never in network requests or router definitions, verify it exists (single `curl -s -o /dev/null -w "%{http_code}"`) before treating it as a live route.
5. **Parameter discovery** — wordlist-fuzz query params; parse OpenAPI/Swagger if exposed; inspect JS calls.
6. **Auth surface** — login/register/password-reset/MFA flows; enumerate user IDs if scope allows.
7. **Nuclei sweep** — if available (`command -v nuclei`), run `nuclei -u <target> -severity low,medium,high,critical` against every HTTP service. Nuclei output is CANDIDATE — manually verify each hit before reporting (see triage rules in `cyber-penetration-loop`).
8. **Security header audit** — `curl -s -I http://<host>:<port>/` for every HTTP service. Check for: CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy. Missing any = LOW finding candidate.
9. **CORS audit** — `curl -s -I -H "Origin: https://evil.com" http://<host>:<port>/` for every HTTP service. `Access-Control-Allow-Origin: *` + `Access-Control-Allow-Credentials: true` = MEDIUM/HIGH finding candidate. Reflected origin = HIGH.

### Host / network (black-box)
1. **Port scan** — `nmap -sS -sV -O --top-ports 1000 <host>` then full `-p-` on live hosts. UDP `-sU` for key ports (53,161,1900).
2. **Service version + scripts** — `-sC` default NSE; add targeted scripts (`--script smb-*,http-*`).
3. **Web on any open HTTP(S)** — pivot into the web pipeline above.
4. **Credentialed checks** only with explicit ROE.
5. **HTTP probe every port** — for every open port, send `curl -s -o /dev/null -w "%{http_code}" http://<host>:<port>/`. Many services (Kafka UI, Grafana, Elasticsearch, C2 frameworks) run on non-standard ports and are missed if only web ports are probed. No open port should go unprobed.
6. **Endpoint sweep per HTTP service** — probe standard endpoint patterns on every service that responds to HTTP: `/api`, `/health`, `/ready`, `/config`, `/admin`, `/metrics`, `/docs`, `/swagger`, `/settings`. See `cyber-penetration-loop` Per-Service Endpoint Exhaustion for the full pattern list.
7. **Infrastructure exposure audit** — flag every exposed database port (5432, 3306, 27017, 9200, 6379, 5433, 9042), message bus UI (8090, 15672, 18083), and monitoring port (9090, 3001, 8088) as an infrastructure finding candidate. Network exposure of these services is itself a vulnerability, even without exploitation.
8. **Default credential testing** — for every service with an auth surface, test: `admin:admin`, `admin:password`, `admin:<service-name>`. Found defaults = immediate finding.

### Source repo (white-box)
1. **Inventory entrypoints** — `find` routes/handlers; `grep` for `@app.route`, `router.`, `app.get`, controllers, resolvers, GraphQL schema.
2. **Map data flow** — `lsp references`/`ast_grep` from sources (request parsers) to sinks (queries, exec, file, network).
3. **Find sinks by class** — `ast_grep` for SQL string concat, `eval`, `child_process`, `pickle.loads`, `Runtime.exec`, template render with user input, `redirect()`, file path concat.
4. **Secrets/config** — `grep` for keys/tokens, `.env`, config files; check deps for known CVEs (`npm audit`/`pip-audit`/`semgrep --config p/supply-chain`).
5. **Authz** — trace which routes enforce auth/role checks; list routes WITHOUT checks (prime IDOR/BFLA targets).

### OSINT (any)
- `web_search` for the org, domain, leaked creds, CVEs for fingerprinted stack, public repos, employee/tech leaks.
- Certificate transparency (`crt.sh?q=%25.domain`) for subdomains.
- Shodin/Censys-style queries via `web_search` if API keys unavailable.

## Output: `surface.md`

Structured table the exploit agents consume directly:

```
## Hosts
| host | port | service | version | notes |
## Endpoints
| method | path | params | auth? | notes |
## Tech
| component | version | known CVEs |
## Candidate vulns (seed list for discovery)
| class | where | why |
```

## Common Mistakes

- **Scanning out of scope** — subdomain enum can return unrelated assets. Filter against ROE before probing.
- **One wordlist, no recursion** — content discovery misses nested dirs. Recurse 2-3 levels, use multiple wordlists.
- **Trusting `nmap` top-1000 only** — always follow with `-p-`. High ports hide services.
- **Ignoring JS** — modern apps expose their whole API in client bundles. `katana`/`browser` extraction is high-signal.
- **No source-to-sink map in white-box** — recon without data flow = static analysis noise. Trace sinks.
- **Hammering rate** — tune `ffuf`/`nmap` rate to avoid DoSing the target or tripping WAF prematurely (WAF mapping is recon output, not a reason to stop).
- **Not probing every open port for HTTP** — services like Kafka UI (:8090), Grafana (:3001), and Elasticsearch (:9200) run on non-standard ports. A port scan that finds the port but never sends an HTTP request to it is incomplete. Probe every port.
- **No nuclei run** — nuclei catches CVEs, misconfigurations, default logins, and exposed panels automatically. If nuclei is available, run it against every HTTP service. Missing nuclei = missing findings.
- **No security header / CORS check** — these are quick wins (`curl -s -I`) that produce real findings. Skipping them leaves LOW/MEDIUM findings on the table that clients will find with any commercial scanner.
- **Scanner output treated as confirmed findings** — nuclei/nikto/nmap NSE output is a candidate. Manually reproduce each hit before reporting. SPA fallbacks and custom error pages trigger false positives in scanners.

## Tool syntax

See `cyber-tool-playbooks` for exact nmap/nuclei/ffuf/subfinder/naabu/katana/httpx invocations and high-signal flag patterns. Detect tool presence with `command -v <tool>` before relying on it; fall back to `curl`/`browser`/`eval` if absent.
