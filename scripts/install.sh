#!/bin/sh
set -e

# CINT — Cyber Intelligence Coding Agent Installer
# Roman Grinevich
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/rg1989/CINT-agent/main/scripts/install.sh | sh
#   sh scripts/install.sh                   # from a cloned repo — installs everything
#
# Installs the agent, then the full cyber toolchain + skills + wordlists.
# Use --no-cyber to skip the toolchain (agent only).
# Options:
#   --source       Install via bun (installs bun if needed)
#   --binary       Always install prebuilt binary
#   --no-cyber     Skip cyber toolchain/skills/wordlists (agent only)
#   --ref <ref>    Install specific tag/commit/branch
#   -r <ref>       Shorthand for --ref

REPO="rg1989/CINT-agent"
PACKAGE="@incrt/cint"
INSTALL_DIR="${CINT_INSTALL_DIR:-$HOME/.local/bin}"
BUN_BIN_DIR="${BUN_INSTALL:-$HOME/.bun}/bin"
MIN_BUN_VERSION="1.3.14"
CINT_PATH_MARKER="# CINT agent CLI"

MODE=""
REF=""
NO_CYBER=0
CINT_INSTALLED_BIN=""
while [ $# -gt 0 ]; do
    case "$1" in
        --source)
            MODE="source"
            shift
            ;;
        --binary)
            MODE="binary"
            shift
            ;;
        --no-cyber)
            NO_CYBER=1
            shift
            ;;
        --ref)
            shift
            if [ -z "$1" ]; then
                echo "Missing value for --ref"
                exit 1
            fi
            REF="$1"
            shift
            ;;
        --ref=*)
            REF="${1#*=}"
            if [ -z "$REF" ]; then
                echo "Missing value for --ref"
                exit 1
            fi
            shift
            ;;
        -r)
            shift
            if [ -z "$1" ]; then
                echo "Missing value for -r"
                exit 1
            fi
            REF="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# If a ref is provided, default to source install
if [ -n "$REF" ] && [ -z "$MODE" ]; then
    MODE="source"
fi

# Check if bun is available
has_bun() {
    command -v bun >/dev/null 2>&1
}

version_ge() {
    current="$1"
    minimum="$2"

    current_major="${current%%.*}"
    current_rest="${current#*.}"
    current_minor="${current_rest%%.*}"
    current_patch="${current_rest#*.}"
    current_patch="${current_patch%%.*}"

    minimum_major="${minimum%%.*}"
    minimum_rest="${minimum#*.}"
    minimum_minor="${minimum_rest%%.*}"
    minimum_patch="${minimum_rest#*.}"
    minimum_patch="${minimum_patch%%.*}"

    if [ "$current_major" -ne "$minimum_major" ]; then
        [ "$current_major" -gt "$minimum_major" ]
        return $?
    fi

    if [ "$current_minor" -ne "$minimum_minor" ]; then
        [ "$current_minor" -gt "$minimum_minor" ]
        return $?
    fi

    [ "$current_patch" -ge "$minimum_patch" ]
}

require_bun_version() {
    version_raw=$(bun --version 2>/dev/null || true)
    if [ -z "$version_raw" ]; then
        echo "Failed to read bun version"
        exit 1
    fi

    version_clean=${version_raw%%-*}
    if ! version_ge "$version_clean" "$MIN_BUN_VERSION"; then
        echo "Bun ${MIN_BUN_VERSION} or newer is required. Current version: ${version_clean}"
        echo "Upgrade Bun at https://bun.sh/docs/installation"
        exit 1
    fi
}

# Check if git is available
has_git() {
    command -v git >/dev/null 2>&1
}

# Map `uname -m` to the Bun/Node arch label used in release tags.
normalize_cpu_arch() {
    case "$1" in
        x86_64|amd64) printf '%s' "x64" ;;
        aarch64|arm64) printf '%s' "arm64" ;;
        *) printf '%s' "$1" ;;
    esac
}

# Map `uname -m` to the Bun Linux release zip suffix (not the Node `process.arch` label).
bun_linux_zip_arch() {
    case "$1" in
        x86_64|amd64) printf '%s' "x64" ;;
        aarch64|arm64) printf '%s' "aarch64" ;;
        *) return 1 ;;
    esac
}

# True when cargo exists, executes, and matches the native host triple.
cargo_ready_for_cpu() {
    _cpu_raw="$1"
    _rust_host=$(rust_host_triple "$_cpu_raw") || return 1
    load_cargo_env
    _cargo=$(command -v cargo 2>/dev/null) || return 1
    case "$_cargo" in
        *"${_rust_host}/bin/cargo"*) ;;
        *) return 1 ;;
    esac
    cargo --version >/dev/null 2>&1
}

# Install Bun on Linux from the official release zip for `uname -m` (not bun.sh guessing).
install_bun_linux_explicit() {
    _cpu_raw=$(uname -m)
    _zip_arch=$(bun_linux_zip_arch "$_cpu_raw") || {
        echo "Unsupported CPU architecture for Bun on Linux: $_cpu_raw"
        exit 1
    }
    _bun_install="${BUN_INSTALL:-$HOME/.bun}"
    _tmp_dir=$(mktemp -d 2>/dev/null || echo "/tmp/cint-bun-$$")
    _zip="${_tmp_dir}/bun.zip"
    _url="https://github.com/oven-sh/bun/releases/download/bun-v${MIN_BUN_VERSION}/bun-linux-${_zip_arch}.zip"

    echo "Installing Bun ${MIN_BUN_VERSION} for linux-${_zip_arch}..."
    curl -fsSL "$_url" -o "$_zip"
    if command -v unzip >/dev/null 2>&1; then
        unzip -oq "$_zip" -d "$_tmp_dir"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import zipfile; zipfile.ZipFile('$_zip').extractall('$_tmp_dir')"
    else
        echo "Need unzip or python3 to install Bun on Linux."
        exit 1
    fi
    mkdir -p "${_bun_install}/bin"
    if command -v install >/dev/null 2>&1; then
        install -m 755 "${_tmp_dir}/bun-linux-${_zip_arch}/bun" "${_bun_install}/bin/bun"
    else
        cp "${_tmp_dir}/bun-linux-${_zip_arch}/bun" "${_bun_install}/bin/bun"
        chmod 755 "${_bun_install}/bin/bun"
    fi
    rm -rf "$_tmp_dir"
    export BUN_INSTALL="$_bun_install"
    export PATH="${_bun_install}/bin:$PATH"
    BUN_BIN_DIR="${_bun_install}/bin"
}

# Map the CPU to the Rust host triple rustup must install for native builds.
rust_host_triple() {
    case "$(uname -s)" in
        Darwin)
            case "$1" in
                x86_64|amd64) printf '%s' "x86_64-apple-darwin" ;;
                arm64|aarch64) printf '%s' "aarch64-apple-darwin" ;;
                *) return 1 ;;
            esac
            ;;
        Linux)
            case "$1" in
                x86_64|amd64) printf '%s' "x86_64-unknown-linux-gnu" ;;
                aarch64|arm64) printf '%s' "aarch64-unknown-linux-gnu" ;;
                armv7l|armv7) printf '%s' "armv7-unknown-linux-gnueabihf" ;;
                *) return 1 ;;
            esac
            ;;
        *) return 1 ;;
    esac
}

load_cargo_env() {
    if [ -f "${HOME}/.cargo/env" ]; then
        # shellcheck disable=SC1091
        . "${HOME}/.cargo/env"
    fi
}

# Bun reports process.arch, which follows the Bun binary — not necessarily the CPU.
# An x64 Bun on arm64 Linux (common in misconfigured VMs) breaks native Rust builds.
ensure_bun_matches_cpu() {
    _cpu_raw=$(uname -m)
    _cpu_arch=$(normalize_cpu_arch "$_cpu_raw")

    if has_bun; then
        _bun_arch=$(bun -e 'process.stdout.write(process.arch)' 2>/dev/null || true)
        if [ -n "$_bun_arch" ] && [ "$_bun_arch" = "$_cpu_arch" ]; then
            return 0
        fi
        if [ -n "$_bun_arch" ]; then
            echo ""
            echo "Bun architecture mismatch — reinstalling native Bun."
            echo "  CPU (uname -m): $_cpu_raw ($_cpu_arch)"
            echo "  Bun binary:     $_bun_arch"
        fi
    fi

    rm -rf "${BUN_INSTALL:-$HOME/.bun}"
    install_bun
    _bun_arch=$(bun -e 'process.stdout.write(process.arch)' 2>/dev/null || true)
    if [ "$_bun_arch" != "$_cpu_arch" ]; then
        echo ""
        echo "FATAL: Bun is still $_bun_arch after reinstall; this CPU is $_cpu_arch."
        echo "Use a Lima/VM image that matches your Mac (arm64 on Apple Silicon)."
        exit 1
    fi
}

read_rust_toolchain_channel() {
    _toolchain_file="$1"
    if [ ! -f "$_toolchain_file" ]; then
        printf '%s' "nightly-2026-04-29"
        return 0
    fi
    _channel=$(grep '^channel = ' "$_toolchain_file" | sed -E 's/^channel = "([^"]+)".*/\1/' | head -n1)
    if [ -n "$_channel" ]; then
        printf '%s' "$_channel"
    else
        printf '%s' "nightly-2026-04-29"
    fi
}

# Verify cargo executes on the host CPU; reinstall rustup for the native triple when not.
ensure_rust_for_native_build() {
    _src_dir="$1"
    load_cargo_env

    _cpu_raw=$(uname -m)
    _rust_host=$(rust_host_triple "$_cpu_raw") || {
        echo "Unsupported CPU architecture for native builds on $(uname -s): $_cpu_raw"
        exit 1
    }
    _rust_channel=$(read_rust_toolchain_channel "$_src_dir/rust-toolchain.toml")

    if cargo_ready_for_cpu "$_cpu_raw"; then
        return 0
    fi

    if command -v cargo >/dev/null 2>&1 || command -v rustup >/dev/null 2>&1; then
        echo ""
        echo "Removing broken or wrong-architecture Rust toolchains..."
        rustup self uninstall -y 2>/dev/null || true
        rm -rf "${HOME}/.rustup" "${HOME}/.cargo"
    fi

    echo ""
    echo "Rust/cargo is missing or cannot execute on this CPU ($_cpu_raw)."
    echo "Installing Rust for native host $_rust_host (channel $_rust_channel)..."

    if command -v rustup >/dev/null 2>&1; then
        rustup set default-host "$_rust_host"
        rustup toolchain install "$_rust_channel" --profile minimal
        rustup default "$_rust_channel"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-host="$_rust_host"
        load_cargo_env
        rustup toolchain install "$_rust_channel" --profile minimal
        rustup default "$_rust_channel"
    fi

    load_cargo_env
    if ! cargo --version >/dev/null 2>&1 && command -v rustup >/dev/null 2>&1; then
        echo "Rust still broken after host retarget — reinstalling rustup from scratch..."
        rustup self uninstall -y || true
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-host="$_rust_host"
        load_cargo_env
        rustup toolchain install "$_rust_channel" --profile minimal
        rustup default "$_rust_channel"
        load_cargo_env
    fi

    if ! cargo --version >/dev/null 2>&1; then
        echo ""
        echo "FATAL: cargo still cannot execute after rustup setup."
        echo ""
        echo "This usually means the CPU architecture and installed toolchains disagree"
        echo "(Exec format error / os error 8). Check:"
        echo "  uname -m          # actual CPU"
        echo "  bun -e 'process.stdout.write(process.arch)'  # Bun binary arch"
        echo "  file \"\$(command -v cargo)\"  # cargo ELF architecture"
        echo ""
        echo "Use a Lima/VM image matching your CPU (arm64 on Apple Silicon), reinstall"
        echo "native Bun (curl -fsSL https://bun.sh/install | bash), then re-run install."
        exit 1
    fi
}

# Install bun
install_bun() {
    echo "Installing bun..."
    if [ "$(uname -s)" = "Linux" ]; then
        install_bun_linux_explicit
    elif command -v bash >/dev/null 2>&1; then
        curl -fsSL https://bun.sh/install | bash
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        BUN_BIN_DIR="$BUN_INSTALL/bin"
    else
        echo "bash not found; attempting install with sh..."
        curl -fsSL https://bun.sh/install | sh
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        BUN_BIN_DIR="$BUN_INSTALL/bin"
    fi
    persist_path_dir "$BUN_BIN_DIR" "bun"
    require_bun_version
}

# Check if git-lfs is available
has_git_lfs() {
    command -v git-lfs >/dev/null 2>&1
}

path_contains_dir() {
    _dir="$1"
    case ":$PATH:" in
        *":$_dir:"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Shell profiles to update, ordered by preference for the user's login shell.
shell_profile_candidates() {
    _shell_name=$(basename "${SHELL:-}")
    if [ -z "$_shell_name" ] || [ "$_shell_name" = "sh" ]; then
        _shell_name=bash
    fi

    if [ "$(uname -s)" = "Darwin" ]; then
        case "$_shell_name" in
            zsh)  set -- "$HOME/.zprofile" "$HOME/.zshrc" ;;
            bash) set -- "$HOME/.bash_profile" "$HOME/.bashrc" ;;
            *)    set -- "$HOME/.profile" ;;
        esac
    else
        case "$_shell_name" in
            zsh)  set -- "$HOME/.zshrc" "$HOME/.profile" ;;
            bash) set -- "$HOME/.bashrc" "$HOME/.profile" ;;
            *)    set -- "$HOME/.profile" ;;
        esac
    fi

    for _profile in "$@"; do
        printf '%s\n' "$_profile"
    done
}

# Append a PATH export to the user's shell profile(s) when the bin dir is missing.
persist_path_dir() {
    _dir="$1"
    _label="${2:-$1}"

    if [ -z "$_dir" ]; then
        return 1
    fi

    if ! path_contains_dir "$_dir"; then
        export PATH="$_dir:$PATH"
    fi

    _updated=0
    _first_profile=""
    for _profile in $(shell_profile_candidates); do
        if [ -z "$_first_profile" ]; then
            _first_profile="$_profile"
        fi
        if [ ! -f "$_profile" ]; then
            continue
        fi
        if grep -q "$CINT_PATH_MARKER" "$_profile" 2>/dev/null; then
            continue
        fi
        {
            echo ""
            echo "$CINT_PATH_MARKER ($_label)"
            echo "export PATH=\"$_dir:\$PATH\""
        } >> "$_profile"
        _updated=1
        echo "  Added $_dir to PATH via $_profile"
    done

    if [ "$_updated" = "0" ]; then
        if [ -n "$_first_profile" ] && [ ! -f "$_first_profile" ]; then
            mkdir -p "$(dirname "$_first_profile")"
            {
                echo "$CINT_PATH_MARKER ($_label)"
                echo "export PATH=\"$_dir:\$PATH\""
            } > "$_first_profile"
            echo "  Created $_first_profile with PATH entry for $_dir"
            _updated=1
        elif grep -q "$CINT_PATH_MARKER" "$HOME/.profile" 2>/dev/null \
            || grep -q "$CINT_PATH_MARKER" "$HOME/.zshrc" 2>/dev/null \
            || grep -q "$CINT_PATH_MARKER" "$HOME/.zprofile" 2>/dev/null \
            || grep -q "$CINT_PATH_MARKER" "$HOME/.bashrc" 2>/dev/null \
            || grep -q "$CINT_PATH_MARKER" "$HOME/.bash_profile" 2>/dev/null; then
            : # already configured in a profile we did not iterate (race/manual edit)
        fi
    fi

    return 0
}

# Native builds need several GiB under $HOME for Rust crates and Bun deps.
check_disk_space_for_build() {
    _avail=$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -z "$_avail" ]; then
        return 0
    fi
    if [ "$_avail" -lt 1024 ]; then
        echo ""
        echo "FATAL: need at least 1 GiB free under \$HOME for the native build (found ${_avail} MiB)."
        echo "Free disk space and re-run install."
        exit 1
    fi
}

# OS-specific toolchain prerequisites for compiling pi-natives from source.
install_native_build_prereqs() {
    case "$(uname -s)" in
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                echo "Installing build dependencies (build-essential, pkg-config, libssl-dev, unzip)..."
                sudo apt-get update -qq >/dev/null 2>&1 && sudo apt-get install -y -qq build-essential pkg-config libssl-dev unzip >/dev/null 2>&1 || true
            elif command -v dnf >/dev/null 2>&1; then
                echo "Installing build dependencies (gcc, make, pkgconfig, openssl-devel, unzip)..."
                sudo dnf install -y -q gcc gcc-c++ make pkgconfig openssl-devel unzip >/dev/null 2>&1 || true
            fi
            ;;
        Darwin)
            if ! xcode-select -p >/dev/null 2>&1; then
                echo ""
                echo "Xcode Command Line Tools are required to compile native addons on macOS."
                echo "Run: xcode-select --install"
                echo "Then re-run this installer after the install completes."
                exit 1
            fi
            ;;
    esac
}

verify_cint_runs() {
    _bin=$(resolve_cint_binary) || return 1
    PI_PYTHON_SKIP_CHECK=1 "$_bin" --version >/dev/null 2>&1
}

resolve_cint_binary() {
    if [ -n "$CINT_INSTALLED_BIN" ] && [ -x "$CINT_INSTALLED_BIN" ]; then
        printf '%s\n' "$CINT_INSTALLED_BIN"
        return 0
    fi

    for _candidate in \
        "$BUN_BIN_DIR/cint" \
        "$INSTALL_DIR/cint" \
        "$HOME/.local/bin/cint"; do
        if [ -x "$_candidate" ]; then
            CINT_INSTALLED_BIN="$_candidate"
            printf '%s\n' "$_candidate"
            return 0
        fi
    done

    if command -v cint >/dev/null 2>&1; then
        CINT_INSTALLED_BIN=$(command -v cint)
        printf '%s\n' "$CINT_INSTALLED_BIN"
        return 0
    fi

    return 1
}

finalize_cint_install() {
    _cint_bin=$(resolve_cint_binary) || {
        echo ""
        echo "ERROR: cint was not installed. No executable found in:"
        echo "  - $BUN_BIN_DIR/cint"
        echo "  - $INSTALL_DIR/cint"
        echo ""
        echo "Re-run with --source after fixing any errors above, or check the install log."
        exit 1
    }

    _cint_dir=$(dirname "$_cint_bin")
    echo ""
    echo "cint installed at: $_cint_bin"

    if path_contains_dir "$_cint_dir"; then
        echo "  $_cint_dir is already on PATH for this shell."
    else
        echo "  $_cint_dir is not on PATH yet — updating shell profile..."
    fi

    persist_path_dir "$_cint_dir" "cint"

    if ! verify_cint_runs; then
        echo ""
        echo "ERROR: cint is on disk at $_cint_bin but failed to start."
        echo "If you installed from source, rebuild natives: cd \"\${CINT_SRC_DIR:-\$HOME/.cint/src}\" && bun run build:native"
        exit 1
    fi

    echo ""
    if path_contains_dir "$_cint_dir"; then
        echo "You can run 'cint' in this terminal now."
    fi
    echo "Open a new terminal (or run: source ~/.zshrc / source ~/.bashrc) so PATH"
    echo "updates everywhere — then run 'cint' to start the agent."
}

# Clone the repo at ref $1 and link packages/coding-agent globally via bun.
# Uses bun link (not bun install -g) because the monorepo uses the catalog:
# protocol, which cannot be resolved outside the workspace context.
install_from_git() {
    REF_ARG="$1"
    if ! has_git; then
        echo "git is required to install from source"
        exit 1
    fi

    # Permanent location — bun link creates a symlink to this source.
    SRC_DIR="${CINT_SRC_DIR:-$HOME/.cint/src}"
    if [ -d "$SRC_DIR" ]; then
        rm -rf "$SRC_DIR"
    fi
    mkdir -p "$(dirname "$SRC_DIR")"

    if git clone --depth 1 --branch "$REF_ARG" "https://github.com/${REPO}.git" "$SRC_DIR" >/dev/null 2>&1; then
        :
    else
        git clone "https://github.com/${REPO}.git" "$SRC_DIR"
        (cd "$SRC_DIR" && git checkout "$REF_ARG")
    fi

    # Pull LFS files
    if has_git_lfs; then
        (cd "$SRC_DIR" && git lfs pull)
    fi

    if [ ! -d "$SRC_DIR/packages/coding-agent" ]; then
        echo "Expected package at ${SRC_DIR}/packages/coding-agent"
        exit 1
    fi

    _cpu_raw=$(uname -m)
    _rust_host=$(rust_host_triple "$_cpu_raw") || {
        echo "Unsupported CPU architecture for native builds on $(uname -s): $_cpu_raw"
        exit 1
    }

    ensure_bun_matches_cpu

    # Resolve workspace deps (catalog: protocol needs root install)
    (cd "$SRC_DIR" && bun install) || {
        echo "Failed to install dependencies"
        exit 1
    }

    check_disk_space_for_build
    install_native_build_prereqs
    ensure_rust_for_native_build "$SRC_DIR"

    if ! cargo_ready_for_cpu "$_cpu_raw"; then
        echo ""
        echo "FATAL: cargo is not ready for $_cpu_raw ($_rust_host) after setup."
        exit 1
    fi

    echo "Building native addons (this takes a few minutes)..."
    if ! (cd "$SRC_DIR" && bun run build:native 2>&1); then
        echo ""
        echo "FATAL: Native addon build failed. The agent cannot run without it."
        echo ""
        echo "Common fixes:"
        echo "  - Architecture mismatch (Exec format error): ensure uname -m matches your Bun"
        echo "    binary (bun -e 'process.stdout.write(process.arch)') and use a native Lima/VM image"
        echo "  - Install build tools: sudo apt install build-essential pkg-config libssl-dev"
        echo "  - Reinstall Rust for this CPU: rustup set default-host $_rust_host"
        echo "  - Then rebuild: cd $SRC_DIR && bun run build:native"
        exit 1
    fi

    # Link globally — creates ~/.bun/bin/cint symlink
    (cd "$SRC_DIR/packages/coding-agent" && bun link) || {
        echo "Failed to link cint"
        exit 1
    }
    CINT_INSTALLED_BIN="$BUN_BIN_DIR/cint"
}

# Install via bun
install_via_bun() {
    echo "Installing CINT via bun..."
    if ! has_bun; then
        install_bun
    else
        ensure_bun_matches_cpu
    fi
    _bun_pm_bin=$(bun pm bin -g 2>/dev/null || true)
    if [ -n "$_bun_pm_bin" ]; then
        BUN_BIN_DIR="$_bun_pm_bin"
    fi
    if [ -n "$REF" ]; then
        install_from_git "$REF"
    else
        # Fast path: published npm package. Falls back to git clone + bun link
        # so the installer works even before the package is on npm.
        if bun install -g "$PACKAGE" 2>/dev/null && verify_cint_runs; then
            _global_bin=$(bun pm bin -g 2>/dev/null || true)
            if [ -n "$_global_bin" ] && [ -x "$_global_bin/cint" ]; then
                CINT_INSTALLED_BIN="$_global_bin/cint"
            else
                CINT_INSTALLED_BIN="$BUN_BIN_DIR/cint"
            fi
        else
            echo "Package $PACKAGE not available on npm or did not produce a working cint; installing from source..."
            install_from_git main
        fi
    fi
    echo ""
    echo "✓ Installed cint via bun"
}

# Install cyber toolchain + skills + wordlists.
# Tries the local scripts/ dir first (cloned repo), then downloads from GitHub.
install_cyber() {
    echo ""
    echo "============================================================"
    echo " Installing cyber toolchain + skills + wordlists..."
    echo "============================================================"

    # Find the cyber tools installer: local scripts/ dir first, then download.
    _script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
    _cyber_script="$_script_dir/install-cyber-tools.sh"

    if [ -f "$_cyber_script" ]; then
        # Running from a cloned repo — script and skills are local.
        sh "$_cyber_script"
    else
        # Piped install (curl | sh) — download the cyber tools installer.
        echo "Downloading cyber tools installer..."
        _tmp_cyber="$(mktemp 2>/dev/null || echo /tmp/cint-cyber-$$.sh)"
        if curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/scripts/install-cyber-tools.sh" -o "$_tmp_cyber" 2>/dev/null; then
            sh "$_tmp_cyber"
            rm -f "$_tmp_cyber"
        else
            echo "  (could not download cyber tools installer — run 'cint --install-cyber-tools' later)"
        fi
    fi
}

# Install binary from GitHub releases
install_binary() {
    # Detect platform
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "$OS" in
        Linux)  PLATFORM="linux" ;;
        Darwin) PLATFORM="darwin" ;;
        *)      echo "Unsupported OS: $OS"; exit 1 ;;
    esac

    case "$ARCH" in
        x86_64|amd64)  ARCH="x64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        *)             echo "Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    BINARY="cint-${PLATFORM}-${ARCH}"
    # Get release tag
    if [ -n "$REF" ]; then
        echo "Fetching release $REF..."
        if RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/tags/${REF}"); then
            LATEST=$(echo "$RELEASE_JSON" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/1/')
        else
            echo "Release tag not found: $REF"
            echo "For branch/commit installs, use --source with --ref."
            exit 1
        fi
    else
        echo "Fetching latest release..."
        RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null) || RELEASE_JSON=""
        LATEST=$(echo "$RELEASE_JSON" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/1/')
    fi

    if [ -z "$LATEST" ]; then
        echo "No prebuilt binary release found."
        echo "Falling back to source install (this installs bun if needed)..."
        if ! has_bun; then
            install_bun
        fi
        require_bun_version
        install_via_bun
        return
    fi
    echo "Using version: $LATEST"

    mkdir -p "$INSTALL_DIR"
    # Download binary
    BINARY_URL="https://github.com/${REPO}/releases/download/${LATEST}/${BINARY}"
    echo "Downloading ${BINARY}..."
    if ! curl -fsSL "$BINARY_URL" -o "${INSTALL_DIR}/cint" 2>/dev/null; then
        echo "Binary download failed. Falling back to source install..."
        if ! has_bun; then
            install_bun
        fi
        require_bun_version
        install_via_bun
        return
    fi
    chmod +x "${INSTALL_DIR}/cint"
    CINT_INSTALLED_BIN="${INSTALL_DIR}/cint"
    echo ""
    echo "✓ Installed cint to ${INSTALL_DIR}/cint"
}

# Main logic
case "$MODE" in
    source)
        if ! has_bun; then
            install_bun
        fi
        require_bun_version
        install_via_bun
        ;;
    binary)
        install_binary
        ;;
    *)
        # Default: use bun if available, otherwise binary
        if has_bun; then
            require_bun_version
            install_via_bun
        else
            install_binary
        fi
        ;;
esac

# Install cyber toolchain + skills unless explicitly skipped.
if [ "$NO_CYBER" = "0" ]; then
    install_cyber
fi

finalize_cint_install

echo ""
echo "✓ Done."
