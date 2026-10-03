#Requires -Version 7.0
<#
.SYNOPSIS
  Runs clang-tidy and the layering check over Spellbook's sources.
.DESCRIPTION
  1. python scripts/check-layering.py: core includes no Windows, storage, or app
     headers; storage includes no app headers (docs/architecture.md).
  2. The pinned clang-tidy (.tools/clang-tidy) with .clang-tidy over every .cpp
     in src/ and tests/, using the compile database of the -Config preset
     (configured first if absent). Findings are printed as file:line.
  Exit 1 when the layering check fails or clang-tidy reports any finding.
.PARAMETER Config
  The preset whose compile_commands.json is used. Debug (default) or Release.
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/lint.ps1
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release', 'RelWithDebInfo')]
    [string]$Config = 'Debug',
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }

$failed = $false
Write-Step 'layering check'
& python (Join-Path $PSScriptRoot 'check-layering.py')
if ($LASTEXITCODE -ne 0) { $failed = $true }

$buildDir = Get-BuildDir $Config
if (-not (Test-Path (Join-Path $buildDir 'compile_commands.json'))) {
    & "$PSScriptRoot/build.ps1" -Config $Config
}
Enter-DevEnvironment
$clangTidy = Get-ToolPath 'clang-tidy'
$sources = @(Get-CppSources | Where-Object { $_ -like '*.cpp' })

Write-Step "clang-tidy ($($sources.Count) files)"
$findings = 0
foreach ($f in $sources) {
    $out = & $clangTidy -p $buildDir --quiet $f 2>&1 | Out-String
    $lines = @($out -split "`r?`n" | Where-Object { $_ -match ': (warning|error): ' -and $_ -notmatch 'vcpkg_installed' })
    if ($lines.Count -gt 0) {
        $findings += $lines.Count
        $lines | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    }
}
if ($findings -gt 0) {
    Write-Host "lint.ps1: clang-tidy reported $findings finding(s)" -ForegroundColor Red
    $failed = $true
} else {
    Write-Host 'lint.ps1: clang-tidy clean' -ForegroundColor Green
}
if ($failed) { exit 1 }
exit 0
