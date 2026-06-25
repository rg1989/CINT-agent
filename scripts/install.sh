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
MIN_BUN_VERSION="1.3.14"

MODE=""
REF=""
NO_CYBER=0
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

# Install bun
install_bun() {
    echo "Installing bun..."
    if command -v bash >/dev/null 2>&1; then
        curl -fsSL https://bun.sh/install | bash
    else
        echo "bash not found; attempting install with sh..."
        curl -fsSL https://bun.sh/install | sh
    fi
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    require_bun_version
}

# Check if git-lfs is available
has_git_lfs() {
    command -v git-lfs >/dev/null 2>&1
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

    # Resolve workspace deps (catalog: protocol needs root install)
    (cd "$SRC_DIR" && bun install) || {
        echo "Failed to install dependencies"
        exit 1
    }

    # Build native addons (Rust .node files) — required for the agent to run.
    # The npm package ships prebuilt binaries, but source installs must compile.
    if ! command -v cargo >/dev/null 2>&1; then
        echo "Installing Rust (required for native addon build)..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null
        # Source cargo env for this shell
        . "${HOME}/.cargo/env" 2>/dev/null || true
    fi
    echo "Building native addons..."
    (cd "$SRC_DIR" && bun run build:native) || {
        echo "WARNING: Native addon build failed."
        echo "  The agent will not start without the native addon."
        echo "  Ensure Rust is installed: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        echo "  Then rebuild: cd $SRC_DIR && bun run build:native"
    }

    # Link globally — creates ~/.bun/bin/cint symlink
    (cd "$SRC_DIR/packages/coding-agent" && bun link) || {
        echo "Failed to link cint"
        exit 1
    }
}

# Install via bun
install_via_bun() {
    echo "Installing CINT via bun..."
    if [ -n "$REF" ]; then
        install_from_git "$REF"
    else
        # Fast path: published npm package. Falls back to git clone + bun link
        # so the installer works even before the package is on npm.
        if bun install -g "$PACKAGE" 2>/dev/null; then
            :
        else
            echo "Package $PACKAGE not available on npm; installing from source..."
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
    echo ""
    echo "✓ Installed cint to ${INSTALL_DIR}/cint"

    # Check if in PATH
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) echo "Run 'cint' to get started!" ;;
        *) echo "Add ${INSTALL_DIR} to your PATH, then run 'cint'" ;;
    esac
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

echo ""
echo "✓ Done."
echo ""
echo "IMPORTANT: Restart your terminal session (or run: source ~/.bashrc / source ~/.zshrc)"
echo "for 'cint' to be available on your PATH."
