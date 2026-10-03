#Requires -Version 7.0
<#
.SYNOPSIS
  Builds Spellbook and runs the unit tests through CTest.
.DESCRIPTION
  Runs scripts/build.ps1 for -Config (unless -NoBuild), then
  `ctest --preset <preset>`. Every Catch2 TEST_CASE is its own CTest test, named
  "core: <case>" or "storage: <case>". -Filter is a CTest regular expression over
  those names. A failing test prints its Catch2 output (outputOnFailure).
.PARAMETER Config
  Debug (default), Release, or RelWithDebInfo.
.PARAMETER Filter
  Run only tests whose name matches this regex, e.g. 'storage:' or 'FTS5'.
.PARAMETER NoBuild
  Skip the build step and test what is already built.
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/test.ps1
  pwsh scripts/test.ps1 -Filter 'storage: .*migrate'
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release', 'RelWithDebInfo')]
    [string]$Config = 'Debug',
    [string]$Filter,
    [switch]$NoBuild,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }

if (-not $NoBuild) { & "$PSScriptRoot/build.ps1" -Config $Config }
Enter-DevEnvironment

$preset = $Presets[$Config]
$ctestArgs = @('--preset', $preset)
if ($Filter) { $ctestArgs += @('-R', $Filter) }

Push-Location $RepoRoot
try {
    Write-Step "ctest $($ctestArgs -join ' ')"
    Invoke-Native ctest @ctestArgs
    Write-Host "test.ps1: $Config OK" -ForegroundColor Green
} finally {
    Pop-Location
}
