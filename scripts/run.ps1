#Requires -Version 7.0
<#
.SYNOPSIS
  Builds Spellbook (if needed) and launches Spellbook.exe.
.DESCRIPTION
  Runs scripts/build.ps1 for -Config (Ninja rebuilds only what changed), then
  starts artifacts/build/<preset>/bin/Spellbook.exe.
  -Smoke runs the launch smoke instead: the app starts fully (logging, database,
  migrations, main window), paints once, and exits. The script waits, checks the
  exit code is 0, and prints the log lines the run wrote. By default the smoke
  uses a throwaway data folder under build/smoke/, so it never touches your real
  %LOCALAPPDATA%\Spellbook; pass -DataDir to choose another.
.PARAMETER Config
  Debug (default), Release, or RelWithDebInfo.
.PARAMETER DataDir
  Use this folder instead of %LOCALAPPDATA%\Spellbook (passed as --data-dir).
.PARAMETER Smoke
  Run the launch smoke and exit with its result.
.PARAMETER NoBuild
  Launch what is already built.
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/run.ps1
  pwsh scripts/run.ps1 -Smoke -Config Release
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release', 'RelWithDebInfo')]
    [string]$Config = 'Debug',
    [string]$DataDir,
    [switch]$Smoke,
    [switch]$NoBuild,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }

if (-not $NoBuild) { & "$PSScriptRoot/build.ps1" -Config $Config }
$exe = Get-ExePath $Config
if (-not (Test-Path $exe)) { throw "$exe not found. Run: pwsh scripts/build.ps1 -Config $Config" }

$appArgs = @()
if ($Smoke -and -not $DataDir) {
    $DataDir = Join-Path $RepoRoot "build/smoke/$($Presets[$Config])"
    if (Test-Path $DataDir) { Remove-Item -Recurse -Force $DataDir }
}
if ($DataDir) { $appArgs += @('--data-dir', $DataDir) }

if (-not $Smoke) {
    Write-Step "start $exe $($appArgs -join ' ')"
    if ($appArgs.Count -gt 0) { Start-Process -FilePath $exe -ArgumentList $appArgs } else { Start-Process -FilePath $exe }
    exit 0
}

$appArgs += '--smoke'
Write-Step "smoke $exe $($appArgs -join ' ')"
$p = Start-Process -FilePath $exe -ArgumentList $appArgs -PassThru
if (-not $p.WaitForExit(60000)) {
    $p.Kill()
    throw 'smoke: Spellbook.exe did not exit within 60 seconds'
}
$log = Join-Path $DataDir 'logs/spellbook.log'
if (Test-Path $log) { Get-Content $log | ForEach-Object { Write-Host "  log: $_" } }
$db = Join-Path $DataDir 'spellbook.db'
if ($p.ExitCode -ne 0) { Write-Host "smoke: FAIL (exit $($p.ExitCode))" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $db)) { Write-Host "smoke: FAIL ($db was not created)" -ForegroundColor Red; exit 1 }
if (-not (Select-String -Path $log -Pattern 'at schema version \d+' -Quiet)) {
    Write-Host 'smoke: FAIL (the log does not record the schema version)' -ForegroundColor Red; exit 1
}
Write-Host "smoke: OK (exit 0, $db created)" -ForegroundColor Green
exit 0
