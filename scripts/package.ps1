<#
.SYNOPSIS
  Builds a Release Spellbook and packages it into artifacts/dist/.
.DESCRIPTION
  Produces Spellbook-<version>-win-x64-portable.zip and SHA256SUMS under
  artifacts/dist/. The ZIP contains the complete self-contained WinUI folder,
  application license/README, and resolved third-party licenses/notices.
  Development PDB/LIB/EXP and incremental-link files are excluded. The stdlib
  Python packager refuses incomplete output or missing required vendor terms.
  Version comes from the git-derived Release build_info.hpp.

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
#Requires -Version 7.0
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
$header = Join-Path (Get-BuildDir Release) 'src/core/generated/spellbook/core/build_info.hpp'
$version = (Select-String -LiteralPath $header -Pattern 'kSemVer = "([^"]+)"').Matches[0].Groups[1].Value
if ([Diagnostics.FileVersionInfo]::GetVersionInfo($exe).ProductVersion -ne $version) { throw 'Release executable version differs from generated metadata; rebuild before packaging' }
Invoke-Native python (Join-Path $PSScriptRoot 'package_payload.py') '--repo' $RepoRoot
Write-Host 'package.ps1: complete folder and vendor notices packaged' -ForegroundColor Green
