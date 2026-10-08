<#
.SYNOPSIS
  Builds the CMake libraries/tests and then the MSBuild WinUI app.
.DESCRIPTION
  Enters the MSVC x64 developer environment, points CMake at the pinned vcpkg in
  .tools/vcpkg, configures the preset for -Config (debug, release, or
  relwithdebinfo in CMakePresets.json), and builds it with Ninja. The first
  configure builds the vcpkg dependencies, which takes several minutes; later
  runs reuse the vcpkg binary cache in .tools/vcpkg-cache.
  Output: artifacts/build/<preset>/app/Spellbook.exe and bin/ test executables.
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
        $resolvedBuild = [IO.Path]::GetFullPath($buildDir)
        $allowedBuild = [IO.Path]::GetFullPath((Join-Path $RepoRoot 'artifacts/build')) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolvedBuild.StartsWith($allowedBuild, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe build directory: $resolvedBuild" }
        Remove-Item -LiteralPath $resolvedBuild -Recurse -Force
    }
    # Refresh package pins and the git-derived version on every build.
    Write-Step "cmake --preset $preset"
    Invoke-Native cmake --preset $preset
    Write-Step "cmake --build --preset $preset"
    Invoke-Native cmake --build --preset $preset
    $msbuild = Join-Path (Find-VisualStudio) 'MSBuild/Current/Bin/amd64/MSBuild.exe'
    if (-not (Test-Path -LiteralPath $msbuild)) { throw "MSBuild missing: $msbuild" }
    $logDir = Join-Path $RepoRoot 'build'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $buildLog = Join-Path $logDir "msbuild-$preset.log"
    Write-Step "MSBuild Spellbook.slnx ($Config)"
    Invoke-Native $msbuild Spellbook.slnx '-restore' '-m' "-p:Configuration=$Config" '-p:Platform=x64' '-v:minimal' '-nologo' '-fl' "-flp:logfile=$buildLog;verbosity=normal"
    if (-not (Test-Path -LiteralPath (Get-ExePath $Config))) { throw 'MSBuild did not produce Spellbook.exe' }
    Write-Host "build.ps1: $Config OK -> $(Get-ExePath $Config)" -ForegroundColor Green
} finally {
    Pop-Location
}
