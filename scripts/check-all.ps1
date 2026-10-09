<#
.SYNOPSIS
  Runs every local gate: toolchain, layering, format, build, tests, smoke, lint, and the plan tooling.
.DESCRIPTION
  The same gates CI runs, in one command (shape copied from Isotone's check-all.ps1):
   1. pwsh scripts/setup.ps1 -Verify            (the pinned toolchain is present)
   2. python scripts/check-layering.py --self-test, then the check itself
   3. pwsh scripts/format.ps1 -Check
   4. build Debug and Release                   (warnings as errors)
   5. ctest Debug and Release
   6. launch smoke, Release                     (scripts/run.ps1 -Smoke)
   7. pwsh scripts/lint.ps1                     (clang-tidy, skipped with -SkipLint)
   8. actionlint over .github/workflows
   9. python scripts/check-docs.py --self-test, then the check (links, forms, em dashes)
  10. python scripts/todo-graph.py self-test, validate, plan --check
  11. pwsh scripts/check-campaign-stop.ps1     (the unattended run's Stop hook, six cases)
  Every gate runs even after an earlier failure; the exit code is 1 when any gate failed.
.PARAMETER SkipBuild
  Skip the builds (tests and smoke then use what is already built).
.PARAMETER SkipLint
  Skip clang-tidy, the slowest gate.
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/check-all.ps1
  pwsh scripts/check-all.ps1 -SkipLint
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$SkipLint,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }

$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Gate([string]$Name, [scriptblock]$Body) {
    Write-Step $Name
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $status = 'PASS'
    try {
        $global:LASTEXITCODE = 0
        & $Body
        if ($LASTEXITCODE -ne 0) { $status = "FAIL (exit $LASTEXITCODE)" }
    } catch {
        $status = "FAIL ($($_.Exception.Message))"
    }
    $results.Add([pscustomobject]@{ Gate = $Name; Status = $status; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) })
}

$python = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' } elseif (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } else { $null }
$pwsh = (Get-Process -Id $PID).Path

Push-Location $RepoRoot
try {
    Invoke-Gate 'toolchain' { & $pwsh -NoProfile -File scripts/setup.ps1 -Verify }
    Invoke-Gate 'hosted provisioning probes' { & $pwsh -NoProfile -File scripts/test-setup-ci.ps1 }
    Invoke-Gate 'toolchain rejection probes' { & $pwsh -NoProfile -File scripts/test-toolchain.ps1 }
    if ($python) {
        Invoke-Gate 'layering self-test' { & $python scripts/check-layering.py --self-test }
        Invoke-Gate 'layering' { & $python scripts/check-layering.py }
    }
    Invoke-Gate 'format -Check' { & $pwsh -NoProfile -File scripts/format.ps1 -Check }
    if (-not $SkipBuild) {
        Invoke-Gate 'build Debug' { & $pwsh -NoProfile -File scripts/build.ps1 -Config Debug }
        Invoke-Gate 'build Release' { & $pwsh -NoProfile -File scripts/build.ps1 -Config Release }
    }
    Invoke-Gate 'test Debug' { & $pwsh -NoProfile -File scripts/test.ps1 -Config Debug -NoBuild }
    Invoke-Gate 'test Release' { & $pwsh -NoProfile -File scripts/test.ps1 -Config Release -NoBuild }
    Invoke-Gate 'smoke Release' { & $pwsh -NoProfile -File scripts/run.ps1 -Config Release -Smoke -NoBuild }
    Invoke-Gate 'app startup probes' { & $pwsh -NoProfile -File scripts/test-app.ps1 -Config Release }
    Invoke-Gate 'portable package probes' { & $pwsh -NoProfile -File scripts/test-package.ps1 }
    Invoke-Gate 'UI driver probes' { & $pwsh -NoProfile -File scripts/test-ui-driver.ps1 }
    if (-not $SkipLint) {
        Invoke-Gate 'lint' { & $pwsh -NoProfile -File scripts/lint.ps1 }
    }
    Invoke-Gate 'actionlint' { & (Get-ToolPath 'actionlint') }
    if ($python) {
        Invoke-Gate 'check-docs self-test' { & $python scripts/check-docs.py --self-test }
        Invoke-Gate 'check-docs' { & $python scripts/check-docs.py }
        Invoke-Gate 'todo-graph self-test' { & $python scripts/todo-graph.py self-test }
        Invoke-Gate 'todo-graph validate' { & $python scripts/todo-graph.py validate }
        Invoke-Gate 'todo-graph plan --check' { & $python scripts/todo-graph.py plan --check }
        Invoke-Gate 'run guard probe' { & $pwsh -NoProfile -File scripts/check-campaign-stop.ps1 }
        Invoke-Gate 'Codex workflow layout' { & $python .codex/scripts/check-workflow.py }
        Invoke-Gate 'Codex campaign probes' { & $python -m unittest discover -s .codex/tests -v }
        Invoke-Gate 'writer selection probes' { & $python scripts/test_writer.py -v }
        Invoke-Gate 'Claude writer guard probes' { & $python -m unittest discover -s .claude/tests -v }
    } else {
        $results.Add([pscustomobject]@{ Gate = 'python gates'; Status = 'SKIP (no python)'; Seconds = 0 })
    }
} finally {
    Pop-Location
}

$results | Format-Table -AutoSize | Out-String | Write-Host
$failed = @($results | Where-Object { $_.Status -like 'FAIL*' })
if ($failed.Count -gt 0) {
    Write-Host "check-all: $($failed.Count) gate(s) failed" -ForegroundColor Red
    exit 1
}
Write-Host 'check-all: all gates passed' -ForegroundColor Green
exit 0
