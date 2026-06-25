# Security Tool Deep Reference

Per-tool: purpose, default-good command, flags that matter, pitfalls. Load the section you need.

## nmap {#nmap}

Purpose: port/service/version/OS discovery + NSE scripting.

```
# Default-good (owned target)
nmap -sS -sV -sC -p- --open -T4 -oA cyber-runs/<run>/raw/nmap <host>

# Fast top-1000 first, then full
nmap -sS -sV --top-ports 1000 -T4 <host>        # quick
nmap -sS -sV -sC -p- --open -T4 <host>          # full follow-up

# UDP (slow; key ports only)
nmap -sU --top-ports 50 -T3 <host>

# Targeted NSE
nmap -p 445 --script smb-enum-shares,smb-vuln* <host>
nmap -p 80,443 --script http-enum,http-headers,http-methods <host>
```

Flags: `-sS` SYN (needs `sudo` — raw sockets; `-sT` connect otherwise), `-sV` version, `-sC` default NSE, `-O` OS (noisy), `-p-` all ports, `--open` show open only, `-T0-5` timing (3 default, 4 good, 5 unreliable), `-oA` all output formats, `--reason` show why port marked, `-v`.

Pitfalls: `-T5` drops packets → false "closed". `-p-` is slow; do top-1000 first then full. SYN (`-sS`) needs `sudo`; without root nmap silently falls back to connect scan (`-sT` — slower, logged on target). NSE scripts can be noisy/DoS-y (`-script` selectively). WAF/IPS will block aggressive scans; `-T2`/`-T3` with `--max-retries 2` for stealth.
Timeouts: `--top-ports 1000` on one host finishes in 10–30s (`timeout: 120`). `-p-` on one host takes 5–15 min (`async: true`). `-p-` on a /24 takes 30–90 min (`async: true`, split ranges). Always pass `-oA` so partial output survives a kill.

## naabu {#naabu}

Purpose: fast port scanning (projectdiscovery). Lighter than nmap for first-pass.

```
naabu -host <host> -p - -rate 1000 -verify -silent -o cyber-runs/<run>/raw/naabu.txt
naabu -list hosts.txt -p 1-10000 -rate 2000 -verify
```

Flags: `-p -` all ports (or `-top-ports 1000`), `-rate` packets/sec, `-verify` re-check open ports (cuts false open), `-stream` for live output.

Pitfalls: without `-verify` naabu over-reports open on flaky links. SYN scan needs `sudo` (raw sockets); without root naabu falls back to connect scan (slower, logged on target). Pair with `nmap -sV -sC` on naabu's open list for version/scripts.
Timeouts: `-top-ports 1000` on one host finishes in 5–15s (`timeout: 120`). `-p -` (all ports) takes 1–5 min (`timeout: 600` or `async: true`). Pair with `-stream` for live output so partial results are visible even if killed.

## subfinder {#subfinder}

Purpose: passive subdomain enumeration from many sources.

```
subfinder -d <dom> -silent -recursive -o cyber-runs/<run>/raw/subs.txt
subfinder -d <dom> -all -silent          # all configured sources
```

Flags: `-recursive` resolve nested, `-all` use all sources (needs API keys in config for full power), `-silent` clean output.

Pitfalls: passive only — won't find internal/VPN-only subdomains. Cross-check with `crt.sh` (`curl -s 'https://crt.sh/?q=%25.<dom>&output=json'`). Filter results against ROE before probing.

## httpx {#httpx}

Purpose: probe hosts for live HTTP(S), status, title, tech, follow redirects.

```
httpx -l hosts.txt -status-code -title -tech-detect -follow-redirects -silent -o cyber-runs/<run>/raw/httpx.txt
httpx -u <url> -status-code -title -tech-detect -ip -cdn -server
```

Flags: `-status-code`, `-title`, `-tech-detect` (Wappalyzer-style), `-follow-redirects`, `-ip`, `-cdn`, `-server`, `-threads`, `-rate-limit`.

Pitfalls: `-follow-redirects` can hop off-scope — check redirect chains. `-tech-detect` is heuristic; confirm with headers/JS.

## katana {#katana}

Purpose: crawler that extracts endpoints + JS-known-files.

```
katana -u <url> -jc -d 3 -kf all -o cyber-runs/<run>/raw/katana.txt
katana -u <url> -jc -d 5 -nc              # -nc no-color, deeper
```

Flags: `-jc` JS crawl + parse, `-d N` depth, `-kf all` known files (robots/sitemap), `-nc` no color, `-proxy` for routing through mitmproxy.

Pitfalls: deep crawl on a big app explodes; cap `-d`. JS parsing is the high-signal part — feed extracted endpoints into `ffuf`/`surface.md`. **String literals ≠ routes** — katana extracts paths from JS source, but not all JS strings are real endpoints (examples, test fixtures, error messages, comments). Cross-reference extracted endpoints against actual network requests or router definitions before probing; a `curl -s -o /dev/null -w "%{http_code}"` probe filters phantom routes cheaply.

## ffuf {#ffuf}

Purpose: content/param/vhost fuzzing.

```
# Dir/content discovery
ffuf -u <url>/FUZZ -w <wordlist> -mc 200,301,401,403 -fs <baseline_bytes> -t 50 -o cyber-runs/<run>/raw/ffuf.json -of json

# Param fuzz
ffuf -u '<url>/?FUZZ=1' -w params.txt -mc 200 -fs <baseline>

# Vhost
ffuf -u <url> -H "Host: FUZZ.<dom>" -w subs.txt -mc 200 -fs <baseline>
```

Flags: `-mc` match codes, `-fc` filter codes, `-fs`/`-fw`/`-fl` filter size/words/lines (run once with no filter to read the baseline), `-t` threads, `-recursion -recursion-depth 2` recurse, `-of json` output.

Wordlists: `SecLists` is the standard — `Discovery/Web-Content/raft-medium-files.txt`, `Discovery/Web-Content/common.txt`, `Discovery/Web-Content/api/api-endpoints.txt`.

Pitfalls: not filtering → 1000 identical 404s. Always baseline first (`-mc all -o` then read sizes). Too many threads → DoS/WAF. Recurse on found dirs. **Verify wordlist path exists before invoking** — a wrong path fails cryptically. SecLists on Homebrew lives at `/opt/homebrew/share/seclists/` (Apple Silicon) or `/usr/local/share/seclists/` (Intel); dirb at `/opt/homebrew/share/wordlists/dirb/`. If no wordlist is present, fall back to a Python `requests` loop over a built-in list in `eval` rather than guessing a path.
Timeouts: `common.txt` (~4600 words) finishes in 30s–2 min (`timeout: 300`). `raft-medium-files.txt` (~17000 words) takes 2–8 min (`async: true`). Full SecLists directory takes 5–20 min (`async: true`). Always pass `-o` + `-of json` so results are saved incrementally.

## nuclei {#nuclei}

Purpose: template-based vuln scanning (CVEs, exposures, misconfigs).

```
nuclei -u <url> -severity high,critical -rl 50 -o cyber-runs/<run>/raw/nuclei.txt
nuclei -l hosts.txt -tags cve,exposure,misconfig -severity medium,high,critical -rl 100
nuclei -u <url> -t <custom.yaml>          # custom template
```

Flags: `-severity` filter, `-tags` category, `-rl` rate limit (REQUESTS/sec), `-c` concurrency, `-t` template path, `-nt` new templates only, `-duc` disable update check (CI).

Pitfalls: noisy at default rate → `-rl 50`. Many templates are info/low — scope with `-severity`. Validate every `nuclei` "hit" per `cyber-exploit-validation`; templates can false-positive on customized apps. Update templates (`-update-templates`) before runs.
Timeouts: 1–5 targets at `-severity high,critical -rl 50` takes 2–10 min (`async: true`). 10+ targets at `-severity medium,high,critical` takes 15–60 min (`async: true`, split into batches of 5). Always pass `-o` so partial results survive. Split by severity (`-severity critical` first, then `high`, then `medium`) so the most important findings surface even if a long run is interrupted.

## sqlmap {#sqlmap}

Purpose: SQL injection detection + exploitation.

```
sqlmap -u '<url>?id=1' --batch --level 3 --risk 2 --random-agent --threads 4 -o --output-dir=cyber-runs/<run>/raw/sqlmap
# POST
sqlmap -u <url> --data='user=1&pass=2' --batch --level 3 --risk 2 -p user
# From a request file (best — captures headers/cookies/auth)
sqlmap -r req.txt --batch --level 3 --risk 2
# Enumerate
sqlmap -r req.txt --batch --current-db --tables --dump -T users
```

Flags: `--batch` non-interactive, `--level` (1-5, higher tests more injection points/techniques), `--risk` (1-3, higher = riskier/time-based), `--random-agent`, `-p` target param, `--dbms` hint, `--technique BEUSTQ` subset, `--tamper` for WAF bypass scripts, `--os-shell` on RCE-capable injection (destructive — owned targets only).

Pitfalls: `--level 5 --risk 3` first run is slow and noisy; start 3/2. `--tamper` scripts must match the WAF (try `between`, `charencode`, `space2comment`). Don't `--dump` real user data on targets you don't own — `--current-db --tables` proves the point. Always validate the injection manually too.

## semgrep {#semgrep}

Purpose: static triage — taint, vuln patterns, supply chain (white-box).

```
semgrep --config p/owasp-top-ten --config p/sql-injection --config p/xss --config p/command-injection <path>
semgrep --config p/secret-detection <path>
semgrep --config p/supply-chain <path>      # dependency CVEs
semgrep --config "r/<custom>" --json -o cyber-runs/<run>/raw/semgrep.json <path>
```

Flags: `--config` rule pack (p/ = packs, r/ = registry, s/ = local), `--json` output, `--error` exit nonzero on findings (CI gate), `--exclude`/`--include`.

Pitfalls: semgrep reports patterns, not exploitable vulns — every finding is a *candidate* needing validation (`lsp references` to confirm reachability from attacker input). High false-positive on frameworks it doesn't model; tune rules. Use the AST tools (`ast_grep`) for custom sink patterns semgrep misses.

## curl {#curl}

Purpose: manual HTTP — the universal fallback.

```
curl -sS -i -k -L -A 'Mozilla/5.0' <url>                      # GET, headers, follow
curl -sS -i -X POST <url> -H 'Content-Type: application/json' -d '{"a":1}' --cookie 'sid=x'
curl -sS --resolve <host>:443:<ip> https://<host>/            # vhost/host-header pinning
curl -sS -x http://127.0.0.1:8080 -k <url>                    # through mitmproxy
```

Flags: `-i` headers, `-k` ignore cert, `-L` follow redirects, `-A` UA, `-X` method, `-H` header, `-d` body, `--cookie`, `-x` proxy, `--resolve` DNS override, `-v` verbose (trace), `--path-as-is` (disable path normalization — useful for traversal quirks).

Pitfalls: `-L` can hop off-scope. URL-encode payloads (`--data-urlencode`). `curl` normalizes paths by default — use `--path-as-is` for traversal/`..` testing. For multi-step flows, prefer a Python `requests` session in `eval` to hold cookies. **No `*` URL globbing** — curl does NOT expand `*` in remote URLs (sends a literal `*`); use `{}` for enumeration (`http://host/{v1,v2}/users`) or loop explicit URLs in `eval`.

## mitmproxy {#mitmproxy}

Purpose: live intercepting proxy — replaces Strix's Caido where available.

```
mitmproxy --mode regular@8080                  # interactive TUI
mitmdump --mode regular@8080 -w cyber-runs/<run>/raw/flows.mitm   # headless capture
mitmweb --mode regular@8080                     # web UI
```

Use: set system or `browser` upstream proxy to `127.0.0.1:8080`, install the mitm CA (`mitmproxy` prints the cert URL on first run), then observe/modify/replay flows. Scripts (`-s addon.py`) for automated rewrite/replay.

Pitfalls: HTTPS interception needs the CA trusted by the client; `browser` (Chromium) needs `--proxy-server` + the CA in its trust store or `--ignore-certificate-errors`. Headless capture (`mitmdump -w`) is best for unattended runs. If mitmproxy isn't installed, fall back to `curl`/Python `requests` for request manipulation (no live intercept).

## Python fallback (no tools) {#python-fallback}

`eval` (py) covers most of the above when tools are absent:

- Port scan: `socket` connect-except loop over a port range.
- HTTP probe: `requests` with status/title/headers parse.
- Content discovery: `requests` over a wordlist, filter by status + len, threaded.
- Subdomains: `crt.sh` JSON via `requests`.
- SQLi: manual boolean/time/UNION per `vulnerabilities.md`#sqli.
- Fuzzing: `asyncio` + `aiohttp` for high-concurrency request fuzzing.

Slower than native tools but always available. Reach for it when `command -v` says a tool's missing.

## macOS Platform Notes {#macos}

When running on macOS (the default host), several platform quirks affect security tooling:

- **SYN scans need `sudo`.** `nmap -sS` and naabu's SYN mode require root for raw sockets. Without sudo, both silently fall back to connect scans (`-sT` for nmap) — slower and logged on the target. Prefix SYN commands with `sudo` explicitly; if sudo is unavailable (non-interactive), use `-sT` connect scans which need no root.
- **BSD grep, not GNU grep.** macOS ships BSD `grep` which does NOT support Perl-compatible regex (`-P` / `grep -oP` → `invalid option -- P`). Use `-E` (extended POSIX regex) with `-o` instead: `grep -oE 'pattern'`. Do NOT `brew install grep` to work around this — use POSIX-compatible regex.
- **curl has no `*` URL globbing.** `curl http://host/api/*` sends a literal `*` (server sees `*` in the path). Use brace expansion (`http://host/api/{v1,v2}`) or loop explicit URLs in `eval`.
- **Wordlist paths vary.** Homebrew installs SecLists to `/opt/homebrew/share/seclists/` (Apple Silicon) or `/usr/local/share/seclists/` (Intel). dirb wordlists go to `/opt/homebrew/share/wordlists/dirb/`. Verify the path exists (`ls <path>`) before passing to ffuf — a non-existent path produces a confusing error or silent failure.
- **Tools may not be installed.** The pentest skill lists expected tool paths, but verify with `command -v <tool>` before relying on them. If absent, fall back per the Fallback Strategy above (Python/curl/browser via `eval`).
