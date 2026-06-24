#!/bin/sh
# CINT Cyber Intelligence — cyber/exploit toolchain installer
#
# Installs the full offensive + defensive cyber toolchain for the CINT agent.
# Idempotent: already-installed tools are skipped. Run with --check to audit
# presence without installing anything.
#
# Usage:
#   cint --install-cyber-tools            # install everything
#   cint --install-cyber-tools --check     # audit only, no changes
#   ./scripts/install-cyber-tools.sh
#   ./scripts/install-cyber-tools.sh --check
set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CHECK_ONLY=0
if [ "$1" = "--check" ] || [ "$2" = "--check" ]; then
    CHECK_ONLY=1
fi

# Accumulators for the end-of-run summary.
INSTALLED=""
INSTALLED_COUNT=0
SKIPPED=""
SKIPPED_COUNT=0
FAILED=""
FAILED_COUNT=0

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
    echo "==> Installing $_name ..."
    if [ "$PKG_MGR" = "brew" ] && [ -n "$_brew" ]; then
        if brew install "$_brew" >/dev/null 2>&1; then
            mark_installed "$_name"
        else
            mark_failed "$_name"
        fi
    elif [ "$PKG_MGR" = "apt" ] && [ -n "$_apt" ]; then
        if sudo apt-get install -y "$_apt" >/dev/null 2>&1; then
            mark_installed "$_name"
        else
            mark_failed "$_name"
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
    echo "==> Installing $_name (pip) ..."
    if python3 -m pip install --user "$_pip" >/dev/null 2>&1; then
        mark_installed "$_name"
    else
        mark_failed "$_name"
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
    echo "==> Installing $_name (go install) ..."
    if GOBIN="${HOME}/.cint/bin" go install "$_mod" >/dev/null 2>&1; then
        export PATH="${HOME}/.cint/bin:${PATH}"
        mark_installed "$_name"
    else
        mark_failed "$_name"
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
    echo "==> Cloning $_name ..."
    mkdir -p "${HOME}/.cint/src"
    if git clone --depth 1 "$_url" "$_dest" >/dev/null 2>&1; then
        mark_installed "$_name"
    else
        mark_failed "$_name"
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
    echo "==> Installing $_name (curl) ..."
    mkdir -p "$(dirname "$_dest")"
    if curl -fsSL "$_url" -o "$_dest" && chmod +x "$_dest"; then
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
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

detect_os
install_all
print_summary

if [ "$FAILED_COUNT" -gt 0 ] && [ "$CHECK_ONLY" = "0" ]; then
    # Non-fatal: we still exit 0 so the script is useful in partial environments.
    :
fi
exit 0
