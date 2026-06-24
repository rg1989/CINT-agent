#!/bin/sh
set -e

# CINT — Cyber Intelligence Coding Agent Uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/rg1989/CINT-agent/main/scripts/uninstall.sh | sh

PRESERVE_DATA="${CINT_PRESERVE_DATA:-0}"

echo "Uninstalling CINT..."

# 1. Remove bun link — bun unlink must be run from the linked package dir.
#    We try the known source locations; if found, cd in and unlink.
for src in "$HOME/.cint/src/packages/coding-agent" \
           "$HOME/Documents/Projects/cint/packages/coding-agent"; do
	if [ -f "$src/package.json" ]; then
		(cd "$src" && bun unlink 2>/dev/null) || true
	fi
done

# 2. Force-clean the global link registry entries that bun link created.
rm -rf "$HOME/.bun/install/global/node_modules/@incrt/cint" 2>/dev/null || true
rm -f  "$HOME/.bun/bin/cint" 2>/dev/null || true

# 3. Remove binary install
rm -f "${CINT_INSTALL_DIR:-$HOME/.local/bin}/cint" 2>/dev/null || true
rm -f "$HOME/.local/bin/cint" 2>/dev/null || true

# 4. Remove source-based install (bun link target from install.sh)
rm -rf "$HOME/.cint/src" 2>/dev/null || true

# 5. Verify removal — if cint is still on PATH, report it
if command -v cint >/dev/null 2>&1; then
	echo "  ⚠ cint is still on PATH at: $(command -v cint)"
	echo "  This may be a stale shell hash. Open a new terminal, or run: hash -r"
fi

# 6. Optionally remove user data (settings, sessions, memory, logs)
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
