#Requires -Version 7.0
<#
.SYNOPSIS
  Formats every C++ source with the pinned clang-format.
.DESCRIPTION
  Runs .tools/clang-format (the version pinned in toolchain.json) with the
  repository's .clang-format over src/ and tests/. Only the pinned binary is
  used: clang-format versions disagree, and a check that passes on one machine
  and fails on another is not a gate.
  -Check changes nothing and exits 1 listing every file that is not formatted
  (the CI gate).
.PARAMETER Check
  Report unformatted files and exit 1 if any; do not rewrite.
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/format.ps1
  pwsh scripts/format.ps1 -Check
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }

$clangFormat = Get-ToolPath 'clang-format'
$files = Get-CppSources
if ($files.Count -eq 0) { Write-Host 'format.ps1: no sources'; exit 0 }

Push-Location $RepoRoot
try {
    if ($Check) {
        $bad = @()
        foreach ($f in $files) {
            & $clangFormat --style=file --dry-run --Werror $f 2>$null
            if ($LASTEXITCODE -ne 0) { $bad += [IO.Path]::GetRelativePath($RepoRoot, $f) }
        }
        if ($bad.Count -gt 0) {
            Write-Host "format.ps1: $($bad.Count) file(s) need formatting:" -ForegroundColor Red
            $bad | ForEach-Object { Write-Host "  $_" }
            Write-Host '  Fix: pwsh scripts/format.ps1' -ForegroundColor Yellow
            exit 1
        }
        Write-Host "format.ps1: $($files.Count) file(s) formatted correctly" -ForegroundColor Green
        exit 0
    }
    Write-Step "clang-format -i ($($files.Count) files)"
    Invoke-Native $clangFormat --style=file -i @files
    Write-Host 'format.ps1: done' -ForegroundColor Green
} finally {
    Pop-Location
}
