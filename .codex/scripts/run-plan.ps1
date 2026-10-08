<#
.SYNOPSIS
  Audit, start, resume, pause, or inspect the separate Codex plan supervisor.
.DESCRIPTION
  Start/resume require the native Codex executable. No model, approval, sandbox,
  hook trust, scheduled task, or machine-wide setting is changed.
.EXAMPLE
  pwsh .codex/scripts/run-plan.ps1 -Action audit
  pwsh .codex/scripts/run-plan.ps1 -Action start -CodexExe C:/path/to/codex.exe
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('audit', 'start', 'resume', 'pause', 'status')]
    [string]$Action = 'audit',
    [string]$CodexExe,
    [ValidateRange(0, 5)][int]$Phase,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
if ($Help) { Get-Help $PSCommandPath -Detailed; exit 0 }
$arguments = @((Join-Path $PSScriptRoot 'campaign.py'), $Action)
if ($CodexExe) { $arguments += @('--codex', $CodexExe) }
if ($PSBoundParameters.ContainsKey('Phase')) { $arguments += @('--phase', [string]$Phase) }
& python @arguments
exit $LASTEXITCODE
