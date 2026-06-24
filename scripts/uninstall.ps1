# CINT — Cyber Intelligence Coding Agent Uninstaller for Windows
# Usage: irm https://raw.githubusercontent.com/rg1989/CINT-agent/main/scripts/uninstall.ps1 | iex

$ErrorActionPreference = "Stop"

$PreserveData = if ($env:CINT_PRESERVE_DATA) { $env:CINT_PRESERVE_DATA } else { "0" }

Write-Host "Uninstalling CINT..."

# 1. Remove bun link
if (Get-Command bun -ErrorAction SilentlyContinue) {
	bun unlink -g "@incrt/cint" 2>$null
	$globalLink = Join-Path $env:USERPROFILE ".bun\install\global\node_modules\@incrt\cint"
	if (Test-Path $globalLink) { Remove-Item -Recurse -Force $globalLink -ErrorAction SilentlyContinue }
}

# 2. Remove binary
$binaryPaths = @(
	(Join-Path $env:LOCALAPPDATA "cint\cint.exe"),
	(Join-Path $env:USERPROFILE ".local\bin\cint.exe")
)
foreach ($p in $binaryPaths) {
	if (Test-Path $p) { Remove-Item -Force $p -ErrorAction SilentlyContinue }
}

# 3. Remove source install
$srcDir = Join-Path $env:USERPROFILE ".cint\src"
if (Test-Path $srcDir) { Remove-Item -Recurse -Force $srcDir -ErrorAction SilentlyContinue }

# 4. Remove bun bin symlink
$bunBin = Join-Path $env:USERPROFILE ".bun\bin\cint"
if (Test-Path $bunBin) { Remove-Item -Force $bunBin -ErrorAction SilentlyContinue }

# 5. Optionally remove user data
if ($PreserveData -eq "1") {
	Write-Host "  Preserving user data (~/.cint)"
} else {
	Write-Host "  Removing user data (~/.cint) — set CINT_PRESERVE_DATA=1 to keep"
	$cintDir = Join-Path $env:USERPROFILE ".cint"
	if (Test-Path $cintDir) { Remove-Item -Recurse -Force $cintDir -ErrorAction SilentlyContinue }
	$ompDir = Join-Path $env:USERPROFILE ".omp"
	if (Test-Path $ompDir) { Remove-Item -Recurse -Force $ompDir -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "✓ CINT uninstalled" -ForegroundColor Green
