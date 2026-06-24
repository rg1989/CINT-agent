# CINT — Cyber Intelligence Coding Agent Uninstaller for Windows
# Usage: irm https://raw.githubusercontent.com/rg1989/CINT-agent/main/scripts/uninstall.ps1 | iex

$ErrorActionPreference = "Stop"

$PreserveData = if ($env:CINT_PRESERVE_DATA) { $env:CINT_PRESERVE_DATA } else { "0" }

Write-Host "Uninstalling CINT..."

# 1. Remove bun link — must run from the linked package dir
$srcDirs = @(
	(Join-Path $env:USERPROFILE ".cint\src\packages\coding-agent")
)
foreach ($d in $srcDirs) {
	if (Test-Path (Join-Path $d "package.json")) {
		Push-Location $d
		try { bun unlink 2>$null } catch {}
		finally { Pop-Location }
	}
}

# 2. Force-clean the global link registry
$globalLink = Join-Path $env:USERPROFILE ".bun\install\global\node_modules\@incrt\cint"
if (Test-Path $globalLink) { Remove-Item -Recurse -Force $globalLink -ErrorAction SilentlyContinue }
$bunBin = Join-Path $env:USERPROFILE ".bun\bin\cint"
if (Test-Path $bunBin) { Remove-Item -Force $bunBin -ErrorAction SilentlyContinue }

# 3. Remove binary
$binaryPaths = @(
	(Join-Path $env:LOCALAPPDATA "cint\cint.exe"),
	(Join-Path $env:USERPROFILE ".local\bin\cint.exe")
)
foreach ($p in $binaryPaths) {
	if (Test-Path $p) { Remove-Item -Force $p -ErrorAction SilentlyContinue }
}

# 4. Remove source install
$srcDir = Join-Path $env:USERPROFILE ".cint\src"
if (Test-Path $srcDir) { Remove-Item -Recurse -Force $srcDir -ErrorAction SilentlyContinue }

# 5. Verify
if (Get-Command cint -ErrorAction SilentlyContinue) {
	Write-Host "  cint is still on PATH at: $(Get-Command cint | Select-Object -ExpandProperty Source)"
	Write-Host "  Open a new terminal to clear the cached PATH."
}

# 6. Optionally remove user data
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
