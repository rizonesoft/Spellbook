#Requires -Version 7.0
<#
.SYNOPSIS
  Builds a Release Spellbook and packages it into artifacts/dist/.
.DESCRIPTION
  Produces, under artifacts/dist/:
    Spellbook-<version>-win-x64-Portable.zip   Spellbook.exe, LICENSE, README.md
    SHA256SUMS                                 the hash of every file above
  <version> is the SemVer the build derived from git tags (the generated
  build_info.hpp). Spellbook.exe is self-contained (static CRT and libraries),
  so the ZIP runs from an empty folder.

  The installer is a stub until M5: the plan's choice is Inno Setup 7
  (docs/adr/0001-tech-stack.md), built by todo/05-ship/TODO-02 §2. -Installer
  says so and exits 1, so no caller mistakes the stub for an installer.
.PARAMETER SkipBuild
  Package what artifacts/build/release already holds.
.PARAMETER Installer
  Also build the Inno Setup installer (not implemented until M5).
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/package.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$Installer,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }

if ($Installer) {
    Write-Host 'package.ps1: the installer is not implemented yet (Inno Setup 7, todo/05-ship/TODO-02 §2).' -ForegroundColor Yellow
    exit 1
}

if (-not $SkipBuild) { & "$PSScriptRoot/build.ps1" -Config Release }
$exe = Get-ExePath 'Release'
if (-not (Test-Path $exe)) { throw "$exe not found; build Release first" }

$info = Join-Path (Get-BuildDir 'Release') 'src/core/generated/spellbook/core/build_info.hpp'
$m = Select-String -Path $info -Pattern 'kSemVer = "([^"]+)"'
if (-not $m) { throw "no version in $info" }
$version = $m.Matches[0].Groups[1].Value

$dist = Join-Path $RepoRoot 'artifacts/dist'
$stage = Join-Path $RepoRoot "artifacts/stage/Spellbook-$version"
foreach ($d in @($stage)) { if (Test-Path $d) { Remove-Item -Recurse -Force $d } }
New-Item -ItemType Directory -Force -Path $dist, $stage | Out-Null
Copy-Item $exe, (Join-Path $RepoRoot 'LICENSE'), (Join-Path $RepoRoot 'README.md') $stage

$zip = Join-Path $dist "Spellbook-$version-win-x64-Portable.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Write-Step "zip $zip"
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal

Push-Location $dist
try {
    Get-ChildItem -File -Filter "Spellbook-$version-*" | Sort-Object Name | ForEach-Object {
        '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name
    } | Set-Content -Encoding ascii SHA256SUMS
    Get-Content SHA256SUMS | ForEach-Object { Write-Host "  $_" }
} finally {
    Pop-Location
}
Write-Host ("package.ps1: {0} ({1:N1} MB)" -f $zip, ((Get-Item $zip).Length / 1MB)) -ForegroundColor Green
