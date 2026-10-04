<#
.SYNOPSIS
  Proves the run guard's Stop hook (.claude/hooks/campaign-stop.ps1) case by case.
.DESCRIPTION
  Builds a throwaway git workspace in the system temp folder holding a copy of
  todo/, scripts/todo-graph.py, .gitignore, and the hook, then feeds the hook
  Stop-event JSON exactly as Claude Code does (on stdin, through the same
  command line as .claude/settings.json) and asserts:
    1. no guard file: the stop is allowed;
    2. a guard for another session: allowed;
    3. the guarded session with an open run: blocked ("decision":"block");
    4. a "## Closeout" heading in the run file: allowed;
    5. a column-0 PARKED line in the run file: allowed;
    6. three blocks with no change to the tree, then the fourth stop is
       allowed and the state file records a trip (the stall breaker).
  The real repository is never touched. Exit 0 when every case holds.
.PARAMETER Keep
  Keep the temp workspace for inspection.
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/check-campaign-stop.ps1
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$Keep,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }

$ws = Join-Path ([IO.Path]::GetTempPath()) ("spellbook-campaign-stop-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $ws | Out-Null
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Case([string]$Name, [bool]$Ok, [string]$Detail) {
    if ($Ok) { Write-Host "  PASS  $Name" }
    else { Write-Host "  FAIL  $Name -- $Detail" -ForegroundColor Red; $failures.Add($Name) }
}

function Invoke-Hook([string]$SessionId) {
    $payload = @{ session_id = $SessionId; hook_event_name = 'Stop'; cwd = $ws; stop_hook_active = $false } | ConvertTo-Json -Compress
    $env:CLAUDE_PROJECT_DIR = $ws
    # The same command line .claude/settings.json runs.
    $cmd = "& ([System.IO.Path]::Combine([Environment]::GetEnvironmentVariable('CLAUDE_PROJECT_DIR'), '.claude', 'hooks', 'campaign-stop.ps1'))"
    $out = $payload | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>$null
    return ($out -join "`n")
}

try {
    Push-Location $ws
    $ErrorActionPreference = 'Continue'
    git init -q 2>$null
    git config user.name 'probe'; git config user.email 'probe@example.invalid'; git config core.autocrlf false
    $ErrorActionPreference = 'Stop'
    Copy-Item -Recurse (Join-Path $RepoRoot 'todo') (Join-Path $ws 'todo')
    New-Item -ItemType Directory -Path (Join-Path $ws 'scripts'), (Join-Path $ws '.claude/hooks'), (Join-Path $ws 'build'), (Join-Path $ws 'docs/phase-runs') | Out-Null
    Copy-Item (Join-Path $RepoRoot 'scripts/todo-graph.py') (Join-Path $ws 'scripts/')
    Copy-Item (Join-Path $RepoRoot '.gitignore') $ws
    Copy-Item (Join-Path $RepoRoot '.claude/hooks/campaign-stop.ps1') (Join-Path $ws '.claude/hooks/')
    $runRel = 'docs/phase-runs/2026-10-04-phase-0.md'
    $run = Join-Path $ws $runRel
    Set-Content -LiteralPath $run -Value "# Phase run: Phase 0`n`n## Sections`n" -Encoding utf8NoBOM
    $ErrorActionPreference = 'Continue'
    git add -A 2>$null; git commit -q -m 'probe workspace' 2>$null
    $ErrorActionPreference = 'Stop'

    $guardPath = Join-Path $ws 'build/claude-campaign-guard.json'
    $statePath = Join-Path $ws 'build/claude-campaign-state.json'

    # 1. no guard
    $o = Invoke-Hook 'session-a'
    Assert-Case 'no guard file allows the stop' (-not $o) "printed: $o"

    @{ runner = 'claude'; workspace = $ws; phase = 0; run_file = $runRel; session_id = 'session-a'; cron_id = 'probe' } |
        ConvertTo-Json | Set-Content -LiteralPath $guardPath -Encoding utf8NoBOM

    # 2. another session
    $o = Invoke-Hook 'session-b'
    Assert-Case 'another session is never blocked' (-not $o) "printed: $o"

    # 3. the guarded session, open run
    $o = Invoke-Hook 'session-a'
    Assert-Case 'an open run blocks its own session' ($o -match '"decision":"block"' -and $o -match 'Next runnable row: D\d{2} T\d{2}') "printed: $o"

    # 4. closeout
    Add-Content -LiteralPath $run -Value "`n## Closeout`n`nAll shipped.`n"
    $o = Invoke-Hook 'session-a'
    Assert-Case 'a closeout heading releases the stop' (-not $o) "printed: $o"
    Set-Content -LiteralPath $run -Value "# Phase run: Phase 0`n`n## Sections`n" -Encoding utf8NoBOM

    # 5. park
    Add-Content -LiteralPath $run -Value "`nPARKED 2026-10-04T12:00:00Z only operator rows remain`n"
    $o = Invoke-Hook 'session-a'
    Assert-Case 'a column-0 PARKED line releases the stop' (-not $o) "printed: $o"
    Set-Content -LiteralPath $run -Value "# Phase run: Phase 0`n`n## Sections`n" -Encoding utf8NoBOM

    # 6. stall breaker: three blocks with no tree change, then the fourth stop is allowed
    Remove-Item -LiteralPath $statePath -ErrorAction SilentlyContinue
    $blocks = 0
    foreach ($i in 1..3) { if ((Invoke-Hook 'session-a') -match '"decision":"block"') { $blocks++ } }
    $o = Invoke-Hook 'session-a'
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    Assert-Case 'the stall breaker releases after three blocks with no change' ($blocks -eq 3 -and -not $o -and [int]$state.trips -eq 1) "blocks=$blocks fourth='$o' trips=$($state.trips)"
} finally {
    Pop-Location
    Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
    if (-not $Keep) { Remove-Item -Recurse -Force -LiteralPath $ws -ErrorAction SilentlyContinue } else { Write-Host "kept: $ws" }
}

if ($failures.Count -gt 0) {
    Write-Host "check-campaign-stop: $($failures.Count) of 6 cases failed" -ForegroundColor Red
    exit 1
}
Write-Host 'check-campaign-stop: all 6 cases passed' -ForegroundColor Green
exit 0
