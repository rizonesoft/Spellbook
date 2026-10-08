<#
.SYNOPSIS
  Runs library clang-tidy, MSVC app analysis, and the layering check.
.DESCRIPTION
  1. python scripts/check-layering.py: core includes no Windows, storage, or app
     headers; storage includes no app headers (docs/architecture.md).
  2. The pinned clang-tidy (.tools/clang-tidy) with .clang-tidy over every .cpp
     in src/core/, src/storage/, and tests/, using the compile database of the -Config preset
     (configured first if absent). Findings are printed as file:line.
  3. MSBuild app analysis with /analyze and /W4 /WX; external headers excluded.
  Exit 1 when a tool fails or reports a finding.
.PARAMETER Config
  The preset whose compile_commands.json is used. Debug (default) or Release.
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/lint.ps1
#>
#Requires -Version 7.0
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
$appRoot = [IO.Path]::GetFullPath((Join-Path $RepoRoot 'src/app')) + [IO.Path]::DirectorySeparatorChar
$sources = @(Get-CppSources | Where-Object { $_ -like '*.cpp' -and -not [IO.Path]::GetFullPath($_).StartsWith($appRoot, [StringComparison]::OrdinalIgnoreCase) })

Write-Step "clang-tidy ($($sources.Count) files)"
$findings = 0
$clangFailed = $false
foreach ($f in $sources) {
    # MSVC-only switches in CMake's database are harmless to Clang's parser.
    $out = & $clangTidy -p $buildDir --quiet '--extra-arg=-Wno-unused-command-line-argument' $f 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        $failed = $true
        $clangFailed = $true
        Write-Host "clang-tidy failed for $f (exit $LASTEXITCODE)" -ForegroundColor Red
        $out -split "`r?`n" | Select-Object -Last 15 | ForEach-Object { Write-Host $_ }
    }
    $lines = @($out -split "`r?`n" | Where-Object { $_ -match ': (warning|error): ' -and $_ -notmatch 'vcpkg_installed' })
    if ($lines.Count -gt 0) {
        $findings += $lines.Count
        $lines | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    }
}
if ($findings -gt 0) {
    Write-Host "lint.ps1: clang-tidy reported $findings finding(s)" -ForegroundColor Red
    $failed = $true
} elseif (-not $clangFailed) {
    Write-Host 'lint.ps1: clang-tidy clean' -ForegroundColor Green
}
Write-Step 'MSVC app code analysis'
$msbuild = Join-Path (Find-VisualStudio) 'MSBuild/Current/Bin/amd64/MSBuild.exe'
$analysisLog = Join-Path $RepoRoot "build/app-analysis-$($Presets[$Config]).log"
& $msbuild (Join-Path $RepoRoot 'src/app/Spellbook.vcxproj') '-t:Build' "-p:Configuration=$Config" '-p:Platform=x64' '-p:SpellbookAnalyze=true' '-v:minimal' '-nologo' *> $analysisLog
$analysisExit = $LASTEXITCODE
Get-Content -LiteralPath $analysisLog | Select-Object -Last 15 | ForEach-Object { Write-Host $_ }
if ($analysisExit -ne 0 -or (Select-String -LiteralPath $analysisLog -Pattern '\bwarning [A-Z]+[0-9]+:' -Quiet)) {
    Write-Host "lint.ps1: MSVC app analysis failed (exit $analysisExit); $analysisLog" -ForegroundColor Red
    $failed = $true
} else { Write-Host 'lint.ps1: MSVC app analysis clean' -ForegroundColor Green }
if ($failed) { exit 1 }
exit 0
