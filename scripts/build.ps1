<#
.SYNOPSIS
  Configures and builds Spellbook with a CMake preset.
.DESCRIPTION
  Enters the MSVC x64 developer environment, points CMake at the pinned vcpkg in
  .tools/vcpkg, configures the preset for -Config (debug, release, or
  relwithdebinfo in CMakePresets.json), and builds it with Ninja. The first
  configure builds the vcpkg dependencies, which takes several minutes; later
  runs reuse the vcpkg binary cache in .tools/vcpkg-cache.
  Output: artifacts/build/<preset>/bin/Spellbook.exe and the test executables.
.PARAMETER Config
  Debug (default), Release, or RelWithDebInfo.
.PARAMETER Clean
  Delete the preset's build folder first (the vcpkg binary cache is kept).
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/build.ps1
  pwsh scripts/build.ps1 -Config Release -Clean
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release', 'RelWithDebInfo')]
    [string]$Config = 'Debug',
    [switch]$Clean,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }

$preset = $Presets[$Config]
$buildDir = Get-BuildDir $Config
Enter-DevEnvironment

Push-Location $RepoRoot
try {
    if ($Clean -and (Test-Path $buildDir)) {
        Write-Step "clean $buildDir"
        Remove-Item -Recurse -Force $buildDir
    }
    if (-not (Test-Path (Join-Path $buildDir 'CMakeCache.txt'))) {
        Write-Step "cmake --preset $preset"
        Invoke-Native cmake --preset $preset
    }
    Write-Step "cmake --build --preset $preset"
    Invoke-Native cmake --build --preset $preset
    Write-Host "build.ps1: $Config OK -> $(Get-ExePath $Config)" -ForegroundColor Green
} finally {
    Pop-Location
}
