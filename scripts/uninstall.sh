#!/bin/sh
set -e

# CINT — Cyber Intelligence Coding Agent Uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/rg1989/CINT-agent/main/scripts/uninstall.sh | sh

PRESERVE_DATA="${CINT_PRESERVE_DATA:-0}"

echo "Uninstalling CINT..."

# 1. Remove bun link (if linked)
if command -v bun >/dev/null 2>&1; then
	bun unlink -g "@incrt/cint" 2>/dev/null || true
	# Also remove from the linked-packages registry if present
	rm -f "$HOME/.bun/install/global/node_modules/@incrt/cint" 2>/dev/null || true
fi

# 2. Remove binary install
rm -f "${CINT_INSTALL_DIR:-$HOME/.local/bin}/cint" 2>/dev/null || true
rm -f "$HOME/.local/bin/cint" 2>/dev/null || true

# 3. Remove source-based install (bun link target)
rm -rf "$HOME/.cint/src" 2>/dev/null || true

# 4. Remove the global symlink bun link created
rm -f "$HOME/.bun/bin/cint" 2>/dev/null || true

# 5. Optionally remove user data (settings, sessions, memory, logs)
if [ "$PRESERVE_DATA" = "1" ]; then
	echo "  Preserving user data (~/.cint)"
else
	echo "  Removing user data (~/.cint) — set CINT_PRESERVE_DATA=1 to keep"
	rm -rf "$HOME/.cint" 2>/dev/null || true
	rm -rf "$HOME/.omp" 2>/dev/null || true
fi

echo ""
echo "✓ CINT uninstalled"
echo ""
if [ "$PRESERVE_DATA" != "1" ]; then
	echo "All settings, sessions, and logs have been removed."
	echo "To reinstall: curl -fsSL https://raw.githubusercontent.com/rg1989/CINT-agent/main/scripts/install.sh | sh"
fi
