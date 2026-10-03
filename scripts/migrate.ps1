#Requires -Version 7.0
<#
.SYNOPSIS
  Applies the migrations to a development database and reports its schema.
.DESCRIPTION
  Builds (unless -NoBuild) and runs Spellbook.exe --smoke against -DataDir, which
  opens <DataDir>\spellbook.db and applies every migration in migrations/ that
  it has not reached, exactly as the app does on start. It then prints
  PRAGMA user_version and the tables, read back with Python's sqlite3 module.
  The default -DataDir is build/dev-data/, never your real
  %LOCALAPPDATA%\Spellbook. -Reset deletes the dev database first, so every
  migration runs from version 0.
.PARAMETER DataDir
  The data folder holding spellbook.db. Default: build/dev-data.
.PARAMETER Reset
  Delete the dev database before migrating.
.PARAMETER Config
  The build to run. Debug (default), Release, or RelWithDebInfo.
.PARAMETER NoBuild
  Use what is already built.
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/migrate.ps1 -Reset
#>
[CmdletBinding()]
param(
    [string]$DataDir,
    [switch]$Reset,
    [ValidateSet('Debug', 'Release', 'RelWithDebInfo')]
    [string]$Config = 'Debug',
    [switch]$NoBuild,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }

if (-not $DataDir) { $DataDir = Join-Path $RepoRoot 'build/dev-data' }
$DataDir = [IO.Path]::GetFullPath($DataDir)
$appData = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Spellbook'))
if ($Reset -and $DataDir -eq $appData) { throw 'migrate.ps1 refuses to -Reset your real %LOCALAPPDATA%\Spellbook database' }

$db = Join-Path $DataDir 'spellbook.db'
if ($Reset) {
    foreach ($f in @($db, "$db-wal", "$db-shm")) { if (Test-Path $f) { Remove-Item -Force $f } }
    Write-Step "reset $db"
}
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

$runArgs = @{ Config = $Config; DataDir = $DataDir; Smoke = $true }
if ($NoBuild) { $runArgs.NoBuild = $true }
& "$PSScriptRoot/run.ps1" @runArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$py = @'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
print("  user_version:", c.execute("PRAGMA user_version").fetchone()[0])
for (name,) in c.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE '%fts_%' ORDER BY name"):
    print("  table:", name)
'@
& python -c $py $db
