#!/bin/sh
# CINT Cyber Intelligence — cyber/exploit toolchain installer
#
# Installs the full offensive + defensive cyber toolchain for the CINT agent.
# Also installs the bundled cyber + dev methodology skills to the user-level
# skill directory (~/.cint/agent/skills/) and seeds operator identity +
# authorization pre-clearance (RULES.md, rules/) plus mnemopi defaults when
# config.yml is absent. Existing skills and user config are NEVER overwritten.
# Optional wordlists (SecLists, dirb) can be skipped with --no-wordlists.
#
# Idempotent: already-installed tools are skipped. Run with --check to audit
# presence without installing anything.
#
# Usage:
#   cint --install-cyber-tools              # install tools + skills + wordlists
#   cint --install-cyber-tools --check       # audit only, no changes
#   cint --install-cyber-tools --no-wordlists # skip the ~500MB SecLists download
#   cint --install-skills                    # install only skills (no tools)
#   cint --install-skills --check             # audit skills only
#   ./scripts/install-cyber-tools.sh
#   ./scripts/install-cyber-tools.sh --check
set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CHECK_ONLY=0
SKILLS_ONLY=0
NO_WORDLISTS=0
for _arg in "$@"; do
    case "$_arg" in
        --check) CHECK_ONLY=1 ;;
        --install-skills) SKILLS_ONLY=1 ;;
        --no-wordlists) NO_WORDLISTS=1 ;;
    esac
done

# Accumulators for the end-of-run summary.
INSTALLED=""
INSTALLED_COUNT=0
SKIPPED=""
SKIPPED_COUNT=0
FAILED=""
FAILED_COUNT=0

# Progress tracking
TOTAL_STEPS=0
CURRENT_STEP=0

# Print progress prefix: [current/total]
progress() {
    if [ "$TOTAL_STEPS" -gt 0 ]; then
        CURRENT_STEP=$((CURRENT_STEP + 1))
        printf "[%d/%d] " "$CURRENT_STEP" "$TOTAL_STEPS"
    fi
}
# ---------------------------------------------------------------------------
# OS / package-manager detection
# ---------------------------------------------------------------------------

OS="unknown"
PKG_MGR=""
HAVE_BREW=0
HAVE_APT=0

detect_os() {
    uname_s="$(uname -s)"
    case "$uname_s" in
        Darwin*) OS="macos" ;;
        Linux*)
            OS="linux"
            if [ -f /etc/os-release ]; then
                # shellcheck disable=SC1091
                . /etc/os-release 2>/dev/null || true
            fi
            ;;
        *) OS="unknown" ;;
    esac

    if command -v brew >/dev/null 2>&1; then
        HAVE_BREW=1
    fi
    if command -v apt-get >/dev/null 2>&1; then
        HAVE_APT=1
    fi

    if [ "$OS" = "macos" ]; then
        PKG_MGR="brew"
    elif [ "$HAVE_APT" = "1" ] || [ "$HAVE_APT" = "1" ]; then
        PKG_MGR="apt"
    elif [ "$HAVE_BREW" = "1" ]; then
        PKG_MGR="brew"
    else
        PKG_MGR="none"
    fi
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Returns 0 if a command is available, 1 otherwise.
have() {
    command -v "$1" >/dev/null 2>&1
}

# Record an install result.
mark_installed() {
    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
    INSTALLED="${INSTALLED}  - $1"$'\n'
}

mark_skipped() {
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    SKIPPED="${SKIPPED}  - $1"$'\n'
}

mark_failed() {
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAILED="${FAILED}  - $1"$'\n'
}

# Install a single tool via the system package manager, skipping if present.
# Args: <binary-or-check-command> <brew-name> <apt-name> <display-name>
pkg_install() {
    _check="$1"; _brew="$2"; _apt="$3"; _name="$4"
    if have "$_check"; then
        mark_skipped "$_name (already installed)"
        return 0
    fi
    if [ "$CHECK_ONLY" = "1" ]; then
        mark_failed "$_name (missing)"
        return 0
    fi
    progress; echo "==> Installing $_name ..."
    _err=""
    if [ "$PKG_MGR" = "brew" ] && [ -n "$_brew" ]; then
        if _err=$(brew install "$_brew" 2>&1); then
            mark_installed "$_name"
        else
            mark_failed "$_name ($_err)"
        fi
    elif [ "$PKG_MGR" = "apt" ] && [ -n "$_apt" ]; then
        if _err=$(sudo apt-get install -y "$_apt" 2>&1); then
            mark_installed "$_name"
        else
            mark_failed "$_name ($_err)"
        fi
    else
        mark_failed "$_name (no package manager available)"
    fi
}

# Install a pip package, skipping if importable.
# Args: <import-name> <pip-name> <display-name>
pip_install() {
    _import="$1"; _pip="$2"; _name="$3"
    if python3 -c "import $_import" >/dev/null 2>&1; then
        mark_skipped "$_name (already installed)"
        return 0
    fi
    if [ "$CHECK_ONLY" = "1" ]; then
        mark_failed "$_name (missing)"
        return 0
    fi
    progress; echo "==> Installing $_name (pip) ..."
    _err=""
    if _err=$(python3 -m pip install --user "$_pip" 2>&1); then
        mark_installed "$_name"
    else
        mark_failed "$_name ($_err)"
    fi
}

# Install a Go-based tool (ProjectDiscovery et al.) via `go install`.
# Args: <binary> <module-path> <display-name>
go_install() {
    _bin="$1"; _mod="$2"; _name="$3"
    if have "$_bin"; then
        mark_skipped "$_name (already installed)"
        return 0
    fi
    if [ "$CHECK_ONLY" = "1" ]; then
        mark_failed "$_name (missing)"
        return 0
    fi
    if ! have go; then
        mark_failed "$_name (go not installed)"
        return 0
    fi
    progress; echo "==> Installing $_name (go install) ..."
    _err=""
    if _err=$(GOBIN="${HOME}/.cint/bin" go install "$_mod" 2>&1); then
        export PATH="${HOME}/.cint/bin:${PATH}"
        mark_installed "$_name"
    else
        mark_failed "$_name ($_err)"
    fi
}

# Clone a git repo into ~/.cint/src/<name> if not already present.
# Args: <repo-url> <dir-name> <display-name>
git_clone_tool() {
    _url="$1"; _dir="$2"; _name="$3"
    _dest="${HOME}/.cint/src/${_dir}"
    if [ -d "$_dest/.git" ]; then
        mark_skipped "$_name (already cloned)"
        return 0
    fi
    if [ "$CHECK_ONLY" = "1" ]; then
        mark_failed "$_name (missing)"
        return 0
    fi
    if ! have git; then
        mark_failed "$_name (git not installed)"
        return 0
    fi
    progress; echo "==> Cloning $_name ..."
    mkdir -p "${HOME}/.cint/src"
    _err=""
    if _err=$(git clone --depth 1 "$_url" "$_dest" 2>&1); then
        mark_installed "$_name"
    else
        mark_failed "$_name ($_err)"
    fi
}

# Install a tool from a GitHub release / raw script.
# Args: <check-bin> <url> <dest-path> <display-name>
curl_install() {
    _bin="$1"; _url="$2"; _dest="$3"; _name="$4"
    if have "$_bin" || [ -x "$_dest" ]; then
        mark_skipped "$_name (already installed)"
        return 0
    fi
    if [ "$CHECK_ONLY" = "1" ]; then
        mark_failed "$_name (missing)"
        return 0
    fi
    if ! have curl; then
        mark_failed "$_name (curl not installed)"
        return 0
    fi
    progress; echo "==> Installing $_name (curl) ..."
    mkdir -p "$(dirname "$_dest")"
    if curl -fsSL "$_url" -o "$_dest" && chmod +x "$_dest"; then
        mark_installed "$_name"
    else
        mark_failed "$_name"
    fi
}

# Install an npm package globally, skipping if the binary is present.
# Args: <check-binary> <npm-package> <display-name>
npm_install() {
    _bin="$1"; _pkg="$2"; _name="$3"
    if have "$_bin" || npm ls -g "$_pkg" >/dev/null 2>&1; then
        mark_skipped "$_name (already installed)"
        return 0
    fi
    if [ "$CHECK_ONLY" = "1" ]; then
        mark_failed "$_name (missing)"
        return 0
    fi
    if ! have npm; then
        mark_failed "$_name (npm not installed)"
        return 0
    fi
    progress; echo "==> Installing $_name (npm) ..."
    if npm install -g "$_pkg" >/dev/null 2>&1; then
        mark_installed "$_name"
    else
        mark_failed "$_name"
    fi
}

cask_install() {
    _check="$1"; _cask="$2"; _name="$3"
    if have "$_check" || [ -d "/Applications/${_cask}.app" ]; then
        mark_skipped "$_name (already installed)"
        return 0
    fi
    if [ "$CHECK_ONLY" = "1" ]; then
        mark_failed "$_name (missing)"
        return 0
    fi
    if [ "$OS" != "macos" ] || [ "$HAVE_BREW" != "1" ]; then
        mark_failed "$_name (requires brew cask on mac)"
        return 0
    fi
    echo "==> Installing $_name (brew cask) ..."
    if brew install --cask "$_cask" >/dev/null 2>&1; then
        mark_installed "$_name"
    else
        mark_failed "$_name"
    fi
}

# ---------------------------------------------------------------------------
# Install routine
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Skill installation (non-destructive)
# ---------------------------------------------------------------------------

# Resolve the script's directory to find the bundled .cint/skills/ source.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# Skills source: repo's .cint/skills/ (two levels up from scripts/).
SKILLS_SRC="$SCRIPT_DIR/../.cint/skills"
# Skills destination: user-level agent skill directory.
SKILLS_DST="$HOME/.cint/agent/skills"
# GitHub repo for download fallback (binary installs with no local repo).
CINT_REPO="${CINT_REPO:-rg1989/CINT-agent}"

# Download skills from GitHub as a tarball and extract to a temp directory.
# Sets SKILLS_SRC to the extracted path on success; returns 1 on failure.
download_skills_from_github() {
    _tmpdir=$(mktemp -d 2>/dev/null || echo "/tmp/cint-skills.$$")
    mkdir -p "$_tmpdir"
    _tarball="$_tmpdir/repo.tar.gz"
    _url="https://github.com/${CINT_REPO}/archive/refs/heads/main.tar.gz"
    echo "  Downloading skills from GitHub..."
    if ! curl -fsSL "$_url" -o "$_tarball" 2>/dev/null; then
        echo "  (download failed — check network or set CINT_REPO env var)"
        rm -rf "$_tmpdir"
        return 1
    fi
    # Extract just the .cint/skills/ directory from the tarball.
    # GitHub tarballs have a top-level <repo>-<ref>/ directory.
    if tar -xzf "$_tarball" -C "$_tmpdir" --strip-components=1 ".cint/skills" 2>/dev/null; then
        : # GNU tar with --strip-components
    elif tar -xzf "$_tarball" -C "$_tmpdir" 2>/dev/null; then
        # BSD tar (macOS) — extract then move to expected location.
        _extracted=$(find "$_tmpdir" -type d -path "*/.cint/skills" 2>/dev/null | head -1)
        if [ -n "$_extracted" ] && [ -d "$_extracted" ]; then
            # Move the skills dir to $_tmpdir/.cint/skills so the caller finds it.
            mkdir -p "$_tmpdir/.cint"
            mv "$_extracted" "$_tmpdir/.cint/skills"
        else
            echo "  (extraction failed — skills directory not found in tarball)"
            rm -rf "$_tmpdir"
            return 1
        fi
    else
        echo "  (extraction failed)"
        rm -rf "$_tmpdir"
        return 1
    fi
    SKILLS_SRC="$_tmpdir/.cint/skills"
    # Clean up the tarball (keep the extracted dir for the install loop).
    rm -f "$_tarball"
    # Register temp dir for cleanup after install_skills finishes.
    _SKILLS_TMPDIR="$_tmpdir"
    return 0
}

install_skills() {
    echo
    echo "### SKILLS ##################################################"

    _SKILLS_TMPDIR=""

    # Source resolution: local repo dir first, then GitHub download fallback.
    if [ ! -d "$SKILLS_SRC" ]; then
        # No local .cint/skills/ — this is a binary install. Try downloading.
        if [ "$CHECK_ONLY" = "1" ]; then
            # In check mode, just report what's installed on the user's machine.
            SKILLS_SRC=""
        elif have curl && have tar; then
            if ! download_skills_from_github; then
                echo "  (could not download skills — run from a source install or check network)"
                mark_failed "skills (download failed)"
                return 0
            fi
        else
            echo "  (no local skills source and curl/tar unavailable — skipping)"
            mark_failed "skills (no source available)"
            return 0
        fi
    fi

    # If we have no source (check mode on binary install), audit user dir directly.
    if [ -z "$SKILLS_SRC" ] || [ ! -d "$SKILLS_SRC" ]; then
        if [ "$CHECK_ONLY" = "1" ]; then
            if [ -d "$SKILLS_DST" ]; then
                _count=0
                for _d in "$SKILLS_DST"/*/; do
                    [ -f "${_d}SKILL.md" ] && _count=$((_count + 1))
                done
                if [ "$_count" -gt 0 ]; then
                    echo "  $_count skill(s) already installed in $SKILLS_DST"
                    mark_skipped "skills ($_count already installed)"
                else
                    mark_failed "skills (not installed)"
                fi
            else
                mark_failed "skills (not installed)"
            fi
            return 0
        fi
        echo "  (no skills source available)"
        return 0
    fi

    # Ensure destination directory exists (even in check mode, for reporting).
    if [ "$CHECK_ONLY" = "0" ]; then
        mkdir -p "$SKILLS_DST"
    fi

    _installed=0
    _skipped=0
    _failed=0
    for _skill_dir in "$SKILLS_SRC"/*/; do
        [ -d "$_skill_dir" ] || continue
        _skill_name=$(basename "$_skill_dir")
        _dst_skill="$SKILLS_DST/$_skill_name"

        if [ -f "$_dst_skill/SKILL.md" ]; then
            mark_skipped "skill: $_skill_name (already exists — user version preserved)"
            _skipped=$((_skipped + 1))
        elif [ "$CHECK_ONLY" = "1" ]; then
            mark_failed "skill: $_skill_name (not installed)"
            _failed=$((_failed + 1))
        else
            if cp -R "$_skill_dir" "$_dst_skill" 2>/dev/null; then
                # Clean up any .DS_Store files copied from macOS source.
                find "$_dst_skill" -name '.DS_Store' -delete 2>/dev/null || true
                mark_installed "skill: $_skill_name"
                _installed=$((_installed + 1))
            else
                mark_failed "skill: $_skill_name (copy failed)"
                _failed=$((_failed + 1))
            fi
        fi
    done

    # Clean up downloaded temp directory if we used one.
    if [ -n "$_SKILLS_TMPDIR" ] && [ -d "$_SKILLS_TMPDIR" ]; then
        rm -rf "$_SKILLS_TMPDIR"
    fi

    echo "  Skills: $_installed installed, $_skipped skipped, $_failed failed"
    if [ "$_skipped" -gt 0 ]; then
        echo "  (skipped skills are user customizations — not overwritten)"
    fi
}

# ---------------------------------------------------------------------------
# Agent config seeding (non-destructive)
# ---------------------------------------------------------------------------
# Seeds operator identity + authorization pre-clearance into ~/.cint/agent/.
# Existing user files are NEVER overwritten — same policy as skills.

# Download agent config (RULES.md, rules/) from GitHub as a tarball and
# extract to a temp directory. Sets _agent_src to the extracted path on
# success; returns 1 on failure. Mirrors download_skills_from_github for
# binary/piped installs that have no local .cint/agent/ source tree.
download_agent_config_from_github() {
    _ac_tmpdir=$(mktemp -d 2>/dev/null || echo "/tmp/cint-agent-cfg.$$")
    mkdir -p "$_ac_tmpdir"
    _ac_tarball="$_ac_tmpdir/repo.tar.gz"
    _ac_url="https://github.com/${CINT_REPO}/archive/refs/heads/main.tar.gz"
    echo "  Downloading agent config from GitHub..."
    if ! curl -fsSL "$_ac_url" -o "$_ac_tarball" 2>/dev/null; then
        echo "  (download failed — check network or set CINT_REPO env var)"
        rm -rf "$_ac_tmpdir"
        return 1
    fi
    # Extract just the .cint/agent/ directory from the tarball.
    # GitHub tarballs have a top-level <repo>-<ref>/ directory.
    if tar -xzf "$_ac_tarball" -C "$_ac_tmpdir" --strip-components=1 ".cint/agent" 2>/dev/null; then
        : # GNU tar with --strip-components
    elif tar -xzf "$_ac_tarball" -C "$_ac_tmpdir" 2>/dev/null; then
        # BSD tar (macOS) — extract then move to expected location.
        _ac_extracted=$(find "$_ac_tmpdir" -type d -path "*/.cint/agent" 2>/dev/null | head -1)
        if [ -n "$_ac_extracted" ] && [ -d "$_ac_extracted" ]; then
            mkdir -p "$_ac_tmpdir/.cint"
            mv "$_ac_extracted" "$_ac_tmpdir/.cint/agent"
        else
            echo "  (extraction failed — agent config directory not found in tarball)"
            rm -rf "$_ac_tmpdir"
            return 1
        fi
    else
        echo "  (extraction failed)"
        rm -rf "$_ac_tmpdir"
        return 1
    fi
    _agent_src="$_ac_tmpdir/.cint/agent"
    # Clean up the tarball (keep the extracted dir for the seeding loop).
    rm -f "$_ac_tarball"
    # Register temp dir for cleanup after install_agent_config finishes.
    _AGENT_CFG_TMPDIR="$_ac_tmpdir"
    return 0
}
install_agent_config() {
    echo
    echo "### AGENT CONFIG ############################################"

    _agent_src="$SCRIPT_DIR/../.cint/agent"
    _agent_dst="$HOME/.cint/agent"

    # No local source (binary/piped install): download from GitHub, or in
    # check mode audit the destination directory directly without downloading.
    if [ ! -d "$_agent_src" ]; then
        if [ "$CHECK_ONLY" = "1" ]; then
            : # fall through — audit the user directory below
        elif command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
            if ! download_agent_config_from_github; then
                echo "  (could not download agent config — skipping)"
                return 0
            fi
        else
            echo "  (no local agent config source and curl/tar unavailable — skipping)"
            return 0
        fi
    fi

    if [ "$CHECK_ONLY" = "0" ]; then
        mkdir -p "$_agent_dst/rules"
    fi

    # RULES.md — sticky operator identity + authorization pre-clearance
    if [ -f "$_agent_dst/RULES.md" ]; then
        mark_skipped "RULES.md (already exists — user version preserved)"
    elif [ "$CHECK_ONLY" = "1" ]; then
        mark_failed "RULES.md (not installed)"
    elif [ -f "$_agent_src/RULES.md" ]; then
        if cp "$_agent_src/RULES.md" "$_agent_dst/RULES.md" 2>/dev/null; then
            mark_installed "RULES.md (operator identity + auth pre-clearance)"
        else
            mark_failed "RULES.md (copy failed)"
        fi
    fi

    # rules/cyber-operator-authorization.md — always-apply authorization rule
    if [ -f "$_agent_dst/rules/cyber-operator-authorization.md" ]; then
        mark_skipped "rules/cyber-operator-authorization.md (already exists)"
    elif [ "$CHECK_ONLY" = "1" ]; then
        mark_failed "rules/cyber-operator-authorization.md (not installed)"
    elif [ -f "$_agent_src/rules/cyber-operator-authorization.md" ]; then
        if cp "$_agent_src/rules/cyber-operator-authorization.md" "$_agent_dst/rules/cyber-operator-authorization.md" 2>/dev/null; then
            mark_installed "rules/cyber-operator-authorization.md"
        else
            mark_failed "rules/cyber-operator-authorization.md (copy failed)"
        fi
    fi

    # config.yml — seed mnemopi defaults only when config is absent
    if [ -f "$_agent_dst/config.yml" ]; then
        mark_skipped "config.yml (already exists — user version preserved)"
    elif [ "$CHECK_ONLY" = "1" ]; then
        mark_skipped "config.yml (will use schema defaults on first run)"
    else
        cat > "$_agent_dst/config.yml" <<'EOF'
memory:
  backend: mnemopi
mnemopi:
  bank: cint
  scoping: global
  autoRecall: true
EOF
        mark_installed "config.yml (mnemopi defaults: global bank, autoRecall)"
    fi
    # Clean up downloaded temp directory if we used one.
    if [ -n "$_AGENT_CFG_TMPDIR" ] && [ -d "$_AGENT_CFG_TMPDIR" ]; then
        rm -rf "$_AGENT_CFG_TMPDIR"
    fi
}

install_all() {
    echo "============================================================"
    echo " CINT Cyber Intelligence — Toolchain Installer"
    echo " OS: $OS    Package manager: $PKG_MGR"
    if [ "$CHECK_ONLY" = "1" ]; then
        echo " Mode: CHECK ONLY (no installation will be performed)"
    else
        echo " Mode: INSTALL"
    fi
    echo "============================================================"
    echo

    # Count total install steps for progress display (approximate — some
    # tools are skipped or OS-conditional, but this gives the user a sense
    # of how far along they are).
    TOTAL_STEPS=40
    # ---- Prerequisites -------------------------------------------------
    pkg_install python3 python3 python3 "python3"
    pkg_install git git git "git"
    pkg_install curl curl curl "curl"
    pkg_install jq jq jq "jq"
    pkg_install docker docker docker.io "docker"
    pkg_install openssl openssl openssl "openssl"

    # ---- Go (needed for PD tools) -------------------------------------
    if [ "$OS" = "macos" ]; then
        pkg_install go go golang-go "go (for ProjectDiscovery tools)"
    else
        pkg_install go golang-go golang-go "go (for ProjectDiscovery tools)"
    fi
    # Ensure GOPATH/bin is on PATH for subsequent go_install calls.
    if have go; then
        export PATH="${PATH}:$(go env GOPATH 2>/dev/null)/bin:${HOME}/.cint/bin"
    fi

    # ===================================================================
    # RECON
    # ===================================================================
    echo
    echo "### RECON ###################################################"
    go_install subfinder "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest" "subfinder"
    go_install naabu   "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"        "naabu"
    pkg_install nmap nmap nmap "nmap"
    pkg_install masscan masscan masscan "masscan"
    go_install httpx   "github.com/projectdiscovery/httpx/cmd/httpx@latest"         "httpx"
    go_install katana  "github.com/projectdiscovery/katana/cmd/katana@latest"       "katana"
    go_install dnsx    "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"           "dnsx"
    pkg_install amass amass amass "amass"

    # ===================================================================
    # WEB EXPLOITATION
    # ===================================================================
    echo
    echo "### WEB EXPLOITATION #######################################"
    pkg_install ffuf ffuf ffuf "ffuf"
    go_install nuclei "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" "nuclei"
    pkg_install sqlmap sqlmap sqlmap "sqlmap"
    pip_install arjun arjun arjun "arjun"
    if [ -d "${HOME}/.cint/src/dirsearch/.git" ] || have dirsearch; then
        mark_skipped "dirsearch (already installed)"
    elif [ "$CHECK_ONLY" = "1" ]; then
        mark_failed "dirsearch (missing)"
    else
        git_clone_tool "https://github.com/maurosoria/dirsearch.git" "dirsearch" "dirsearch"
    fi
    pip_install wafw00f wafw00f wafw00f "wafw00f"
    git_clone_tool "https://github.com/ticarpi/jwt_tool.git" "jwt_tool" "jwt_tool"
    pip_install boofuzz boofuzz boofuzz "boofuzz"

    # ===================================================================
    # CODE AUDIT
    # ===================================================================
    echo
    echo "### CODE AUDIT #############################################"
    pip_install semgrep semgrep semgrep "semgrep"
    pip_install bandit bandit bandit "bandit"
    pkg_install trivy trivy trivy "trivy"
    if [ "$OS" = "macos" ]; then
        pkg_install trufflehog trufflehog trufflehog "trufflehog"
    else
        curl_install trufflehog \
            "https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh" \
            "${HOME}/.cint/bin/trufflehog-install.sh" "trufflehog"
    fi
    if [ "$OS" = "macos" ]; then
        pkg_install gitleaks gitleaks gitleaks "gitleaks"
    else
        # gitleaks ships as a binary release; fall back to go install.
        go_install gitleaks "github.com/gitleaks/gitleaks/v8@latest" "gitleaks"
    fi

    # ===================================================================
    # EXPLOIT DEV
    # ===================================================================
    echo
    echo "### EXPLOIT DEV ############################################"
    if [ "$OS" = "macos" ]; then
        cask_install analyzeHeadless ghidra "ghidra"
    else
        # On Linux Ghidra requires a manual download + JDK. We check for the
        # analyzeHeadless wrapper; if absent we record as missing rather than
        # attempting an unreliable automated install.
        if have analyzeHeadless; then
            mark_skipped "ghidra (already installed)"
        elif [ "$CHECK_ONLY" = "1" ]; then
            mark_failed "ghidra (missing — download from https://ghidra-sre.org/)"
        else
            mark_failed "ghidra (manual install required on Linux: https://ghidra-sre.org/)"
        fi
    fi
    pip_install pwn pwntools "pwntools"
    pip_install ROPgadget ROPgadget "ROPgadget"
    pip_install ropper ropper "ropper"
    pip_install capstone capstone "capstone"

    # ===================================================================
    # FUZZING
    # ===================================================================
    echo
    echo "### FUZZING ################################################"
    if [ "$OS" = "macos" ]; then
        pkg_install aflplusplus aflplusplus "" "afl++"
    else
        pkg_install afl++ "" afl++ "afl++"
    fi
    pkg_install honggfuzz honggfuzz honggfuzz "honggfuzz"

    # ===================================================================
    # DEBUGGING
    # ===================================================================
    echo
    echo "### DEBUGGING ##############################################"
    if [ "$OS" = "macos" ]; then
        if have lldb; then
            mark_skipped "lldb (preinstalled on macOS)"
        elif [ "$CHECK_ONLY" = "1" ]; then
            mark_failed "lldb (missing)"
        else
            # lldb is part of Xcode Command Line Tools on mac.
            if xcode-select -p >/dev/null 2>&1; then
                mark_skipped "lldb (via Xcode CLT)"
            else
                mark_failed "lldb (install Xcode Command Line Tools: xcode-select --install)"
            fi
        fi
    else
        pkg_install lldb lldb lldb "lldb"
    fi
    git_clone_tool "https://github.com/pwndbg/pwndbg.git" "pwndbg" "pwndbg"

    # ===================================================================
    # UTILITIES
    # ===================================================================
    echo
    echo "### UTILITIES ##############################################"
    go_install interactsh-client "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest" "interactsh"
    # interactsh also ships a server; we alias the check.
    if have interactsh-client; then
        mark_skipped "interactsh (client installed)"
    fi

    # ===================================================================
    # WORDLISTS (optional — large download)
    # ===================================================================
    echo
    echo "### WORDLISTS ##############################################"
    if [ "$NO_WORDLISTS" = "1" ]; then
        echo "  (skipped via --no-wordlists)"
        mark_skipped "seclists (skipped via --no-wordlists)"
        mark_skipped "dirb wordlists (skipped via --no-wordlists)"
    else
        # SecLists — the standard wordlist collection for ffuf/content discovery.
        # ~500MB on disk; skip if the directory already exists.
        _seclists_brew="/opt/homebrew/share/seclists"
        _seclists_linux="/usr/share/seclists"
        if [ -d "$_seclists_brew" ] || [ -d "$_seclists_linux" ]; then
            mark_skipped "seclists (already installed)"
        elif [ "$CHECK_ONLY" = "1" ]; then
            mark_failed "seclists (not installed — run without --check, or skip with --no-wordlists)"
        else
            progress; echo "==> Installing seclists (this is a ~500MB download) ..."
            if [ "$PKG_MGR" = "brew" ]; then
                if brew install seclists >/dev/null 2>&1; then
                    mark_installed "seclists"
                else
                    mark_failed "seclists (brew install failed — try manually or skip with --no-wordlists)"
                fi
            elif [ "$PKG_MGR" = "apt" ]; then
                if sudo apt-get install -y seclists >/dev/null 2>&1; then
                    mark_installed "seclists"
                else
                    mark_failed "seclists (apt install failed — try manually or skip with --no-wordlists)"
                fi
            else
                mark_failed "seclists (no package manager — clone from https://github.com/danielmiessler/SecLists or skip with --no-wordlists)"
            fi
        fi

        # dirb wordlists — smaller, ships common.txt used by the pentest skill.
        _dirb_brew="/opt/homebrew/share/wordlists/dirb"
        _dirb_linux="/usr/share/wordlists/dirb"
        if [ -d "$_dirb_brew" ] || [ -d "$_dirb_linux" ]; then
            mark_skipped "dirb wordlists (already installed)"
        elif [ "$CHECK_ONLY" = "1" ]; then
            mark_failed "dirb wordlists (not installed)"
        else
            if [ "$PKG_MGR" = "brew" ]; then
                if brew install dirb >/dev/null 2>&1; then
                    mark_installed "dirb wordlists"
                else
                    mark_failed "dirb wordlists (brew install failed)"
                fi
            elif [ "$PKG_MGR" = "apt" ]; then
                if sudo apt-get install -y dirb >/dev/null 2>&1; then
                    mark_installed "dirb wordlists"
                else
                    mark_failed "dirb wordlists (apt install failed)"
                fi
            else
                mark_failed "dirb wordlists (no package manager)"
            fi
        fi
    fi

    # ===================================================================
    # WEB INTELLIGENCE
    # ===================================================================
    echo
    echo "### WEB INTELLIGENCE #######################################"
    npm_install camofox-browser "@askjo/camofox-browser" "camofox-browser (stealth headless browser)"
    npm_install firecrawl-mcp "firecrawl-mcp" "firecrawl-mcp (web scrape/search MCP server)"
    echo
    echo "  camofox-browser: start with 'npx @askjo/camofox-browser' (REST API on :9377)"
    echo "  firecrawl-mcp: add to ~/.cint/agent/mcp.json:"
    echo '    {"mcpServers":{"firecrawl":{"command":"npx","args":["-y","firecrawl-mcp"],"env":{"FIRECRAWL_API_KEY":"fc-YOUR_KEY"}}}}'
    echo "  Get a Firecrawl API key at https://firecrawl.dev"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_summary() {
    echo
    echo "============================================================"
    echo " SUMMARY"
    echo "============================================================"
    echo " Installed : $INSTALLED_COUNT"
    echo " Skipped   : $SKIPPED_COUNT  (already present)"
    echo " Failed    : $FAILED_COUNT"
    echo "------------------------------------------------------------"
    if [ -n "$INSTALLED" ]; then
        echo "Installed:"; printf '%s' "$INSTALLED"
    fi
    if [ -n "$SKIPPED" ]; then
        echo "Skipped:"; printf '%s' "$SKIPPED"
    fi
    if [ -n "$FAILED" ]; then
        echo "Failed / Missing:"; printf '%s' "$FAILED"
    fi
    echo "============================================================"
    if [ "$FAILED_COUNT" -gt 0 ]; then
        echo "Some tools were not installed. Review the list above."
        if [ "$CHECK_ONLY" = "1" ]; then
            echo "Run without --check to install them."
        fi
    else
        echo "All tools present."
    fi

    # Ensure ~/.cint/bin is on the user's PATH permanently (go-installed tools land here).
    _cint_bin="$HOME/.cint/bin"
    if [ -d "$_cint_bin" ]; then
        _added=0
        for _profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
            [ -f "$_profile" ] || continue
            if ! grep -q '\.cint/bin' "$_profile" 2>/dev/null; then
                echo '' >> "$_profile"
                echo '# CINT cyber tools (go-installed binaries)' >> "$_profile"
                echo 'export PATH="$HOME/.cint/bin:$PATH"' >> "$_profile"
                _added=1
            fi
        done
        if [ "$_added" = "1" ]; then
            echo ""
            echo "Added ~/.cint/bin to your PATH in shell profile."
            echo "Restart your terminal or run: source ~/.bashrc"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

detect_os
if [ "$SKILLS_ONLY" = "1" ]; then
    echo "============================================================"
    echo " CINT Cyber Intelligence — Skills Installer"
    if [ "$CHECK_ONLY" = "1" ]; then
        echo " Mode: CHECK ONLY (no installation will be performed)"
    else
        echo " Mode: INSTALL"
    fi
    echo "============================================================"
    install_skills
    install_agent_config
else
    install_all
    install_skills
    install_agent_config
fi
print_summary

if [ "$FAILED_COUNT" -gt 0 ] && [ "$CHECK_ONLY" = "0" ]; then
    # Non-fatal: we still exit 0 so the script is useful in partial environments.
    :
fi
exit 0
