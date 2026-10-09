<#
.SYNOPSIS
Builds and drives an isolated Spellbook scenario, saving capture receipts and logs.
.PARAMETER Scenario
The name of a script under tests/ui/scenarios (currently shell).
.PARAMETER Config
Debug, Release, or RelWithDebInfo.
.PARAMETER CaptureRoot
Capture destination; defaults to docs/captures. Reviewers use an ignored unique build/reviews directory.
.PARAMETER Keep
Retain the isolated data directory after success. Failures always retain evidence.
.PARAMETER ScenarioFile
Explicit scenario script for isolated negative probes. The normal named scenario remains unchanged.
.PARAMETER Help
Show this help without building or launching.
.EXAMPLE
pwsh scripts/drive.ps1 -Scenario shell -CaptureRoot build/reviews/example/captures
#>
[CmdletBinding()]
param([ValidatePattern('^[a-z][a-z0-9-]*$')][string]$Scenario='shell',
      [ValidateSet('Debug','Release','RelWithDebInfo')][string]$Config='Debug',
      [string]$CaptureRoot, [switch]$Keep, [string]$ScenarioFile, [switch]$Help)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }
Import-Module "$RepoRoot/tests/ui/SpellbookUia.psm1" -Force
$run=Join-Path $RepoRoot "build/drive/$Scenario-$([guid]::NewGuid().ToString('N'))"
[IO.Directory]::CreateDirectory($run) | Out-Null
$session=$null; $success=$false
try {
    & (Get-Process -Id $PID).Path -NoProfile -File "$PSScriptRoot/build.ps1" -Config $Config *> "$run/build.log"
    if ($LASTEXITCODE -ne 0) { throw "Build failed; see $run/build.log" }
    $scenarioPath=if ($ScenarioFile) { (Resolve-Path -LiteralPath $ScenarioFile).Path } else { Join-Path $RepoRoot "tests/ui/scenarios/$Scenario.ps1" }
    if (-not (Test-Path -LiteralPath $scenarioPath)) { throw "Unknown scenario: $Scenario" }
    $session=Start-Spellbook -Executable (Get-ExePath $Config) -DataDir "$run/data"
    $result=& $scenarioPath -Session $session -OutputDirectory $run
    $exeHash=(Get-FileHash -LiteralPath $session.Executable).Hash.ToLowerInvariant()
    $priHash=(Get-FileHash -LiteralPath (Join-Path (Split-Path $session.Executable) 'Spellbook.pri')).Hash.ToLowerInvariant()
    Stop-Spellbook $session
    $session=$null
    $log=Join-Path $run 'data/logs/spellbook.log'
    if (@(Select-String -LiteralPath $log -SimpleMatch ' exiting').Count -ne 1) { throw 'Expected one clean exit log entry' }
    Copy-Item -LiteralPath $log -Destination "$run/spellbook.log"
    $destinationRoot=if ($CaptureRoot) { [IO.Path]::GetFullPath($CaptureRoot) } else { Join-Path $RepoRoot 'docs/captures' }
    $destination=Join-Path $destinationRoot "$Scenario/main-window-$($result.Capture.Dpi)dpi.png"
    [IO.Directory]::CreateDirectory((Split-Path $destination)) | Out-Null
    # Both published files are protected; ordinary publication failure restores the prior pair.
    foreach ($target in @($destination,"$destination.json")) {
        $relative=[IO.Path]::GetRelativePath($RepoRoot,$target).Replace('\','/')
        $dirty=@(& git -C $RepoRoot status --porcelain -- $relative)
        if ($LASTEXITCODE -ne 0 -or $dirty.Count) { throw "Capture has uncommitted changes: $target" }
    }
    $manifest=[ordered]@{ Scenario=$Scenario; Config=$Config; RunDirectory=$run; SourceHead=(& git -C $RepoRoot rev-parse HEAD);
        ExecutableSha256=$exeHash; ResourcesSha256=$priHash; Assertions=@($result.Assertions)+@('clean exit');
        Schema=$result.Schema; Capture=$result.Capture; PublishedPath=$destination }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$run/manifest.json" -Encoding utf8NoBOM
    & python "$RepoRoot/tests/ui/publish.py" $result.Capture.Path "$run/manifest.json" $destination "$run/publication-recovery"
    if ($LASTEXITCODE -ne 0) { throw "Capture publication failed; inspect $run/publication-recovery" }
    if (-not $Keep) {
        $data=[IO.Path]::GetFullPath("$run/data")
        $owned=[IO.Path]::GetFullPath((Join-Path $RepoRoot 'build/drive'))+[IO.Path]::DirectorySeparatorChar
        if (-not $data.StartsWith($owned,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup path' }
        Remove-Item -LiteralPath $data -Recurse -Force
    }
    $success=$true
    Write-Host "drive: PASS $Scenario ($($result.Capture.Dpi) DPI, $($result.Capture.Theme)); evidence: $run/manifest.json"
} catch {
    $_ | Out-String | Set-Content -LiteralPath "$run/failure.txt"
    Write-Error "drive: FAIL; evidence: $run; $($_.Exception.Message)" -ErrorAction Continue
} finally {
    if ($session) { try { Stop-Spellbook $session } catch { Write-Warning $_; $success=$false } }
}
if (-not $success) { exit 1 }
