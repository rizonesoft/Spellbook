<#
.SYNOPSIS
  Runs the GitHub CLI wherever it is installed, so runs never depend on PATH.
.DESCRIPTION
  Finds gh.exe on PATH, then in "C:\Program Files\GitHub CLI", then in
  "%LOCALAPPDATA%\Programs\GitHub CLI", and runs it with every argument passed
  through unchanged; the exit code is gh's. The GitHub CLI is machine-wide by
  necessity (it holds the operator's login in the Windows keyring), so it is
  found, never installed. The run skills (process-plan, process-phase) call it
  through this script, for example to read the last CI result.
.PARAMETER Help
  Show this help (only when it is the sole argument; anything else goes to gh).
.EXAMPLE
  pwsh scripts/gh.ps1 run list --branch main --limit 1
.EXAMPLE
  pwsh scripts/gh.ps1 auth status
#>
#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($args.Count -eq 1 -and $args[0] -in '-Help', '--script-help') { Show-ScriptHelp $PSCommandPath; exit 0 }

$candidates = @(
    (Get-Command gh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source),
    (Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\GitHub CLI\gh.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

$gh = $candidates | Select-Object -First 1
if (-not $gh) {
    [Console]::Error.WriteLine('gh.ps1: the GitHub CLI is not installed (winget install --id GitHub.cli), or not in any known location.')
    exit 127
}
& $gh @args
exit $LASTEXITCODE
