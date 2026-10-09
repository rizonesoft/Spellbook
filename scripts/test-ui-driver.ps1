<#
.SYNOPSIS
Proves the read-only database helper, real UI Automation primitives, and shell driver failure paths.
#>
[CmdletBinding()]
param([ValidateSet('Debug','Release','RelWithDebInfo')][string]$Config='Release')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/_common.ps1"
Import-Module "$RepoRoot/tests/ui/SpellbookUia.psm1" -Force
$run=Join-Path $RepoRoot "build/ui-driver/probes-$([guid]::NewGuid().ToString('N'))"
[IO.Directory]::CreateDirectory($run) | Out-Null
$pwsh=(Get-Process -Id $PID).Path
$passed=0
function Expect-Failure([string]$Name,[string]$Message,[scriptblock]$Body) {
    $rejected=$false
    try { & $Body | Out-Null } catch {
        if ($_.Exception.Message -notlike "*$Message*") { throw "Wrong failure for ${Name}: $_" }
        $rejected=$true
    }
    if (-not $rejected) { throw "Expected failure: $Name" }
    $script:passed++
    Write-Host "UI probe PASS: $Name"
}
& python "$RepoRoot/tests/ui/test_dbread.py" -v
if ($LASTEXITCODE -ne 0) { throw 'Database helper probes failed' }
& python "$RepoRoot/tests/ui/test_publish.py" -v
if ($LASTEXITCODE -ne 0) { throw 'Capture publication probes failed' }
$session=$null
try {
    $session=Start-Spellbook -Executable $pwsh -DataDir "$run/fixture-data" -PrefixArguments @('-NoProfile','-STA','-File',"$RepoRoot/tests/ui/fixture.ps1")
    $edit=Get-Element $session 'editable'
    Set-ElementValue $session $edit 'round trip'
    $button=Get-Element $session 'invoke'
    Invoke-Element $session $button
    $label=Get-Element $session 'heading'
    $deadline=[DateTime]::UtcNow.AddSeconds(5)
    while ($label.Current.Name -ne 'Fixture invoked' -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    if ($label.Current.Name -ne 'Fixture invoked') { throw 'InvokePattern did not update the fixture' }
    $passed+=2
    Expect-Failure 'missing ID' 'Missing AutomationId' { Get-Element $session 'absent' -TimeoutSeconds 0 }
    Expect-Failure 'ambiguous ID' 'Ambiguous AutomationId' { Get-Element $session 'duplicate' -TimeoutSeconds 0 }
    Expect-Failure 'read-only value' 'read-only' { Set-ElementValue $session (Get-Element $session 'locked') 'bad' }
    Expect-Failure 'unsupported invoke' 'no InvokePattern' { Invoke-Element $session $edit }
    Expect-Failure 'unsupported value' 'no ValuePattern' { Set-ElementValue $session $button 'bad' }
    # This owned fixture is the only window for which the probe requests foreground focus.
    [Spellbook.UiTesting.Native]::SetForegroundWindow($session.Window) | Out-Null
    $edit.SetFocus()
    Send-Keys $session -Chord 'Ctrl+A'
    Send-Keys $session -Text 'typed proof'
    $deadline=[DateTime]::UtcNow.AddSeconds(5)
    $pattern=$edit.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern)
    while ($pattern.Current.Value -ne 'typed proof' -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    if ($pattern.Current.Value -ne 'typed proof') { throw 'Guarded keyboard input did not reach the fixture' }
    $passed++
    Expect-Failure 'unsupported chord' 'Unsupported key' { Send-Keys $session -Chord 'Win+R' }
    $fake=[pscustomobject]@{ Process=$session.Process; StartTicks=$session.StartTicks; Window=[IntPtr]::Zero }
    Expect-Failure 'foreign window refused' 'does not belong' { Send-Keys $fake -Text 'unsafe' }
    $capture=Save-Capture $session "$run/fixture.png" $label 'light'
    if ($capture.Width -lt 100 -or $capture.AnchorContrast -lt 60) { throw 'Invalid fixture capture receipt' }
    $before=(Get-FileHash "$run/fixture.png").Hash
    Expect-Failure 'existing capture preserved' 'already exists' { Save-Capture $session "$run/fixture.png" $label 'light' }
    if ((Get-FileHash "$run/fixture.png").Hash -ne $before) { throw 'Prior capture changed after rejection' }
    $passed++
    foreach ($case in @('stale','wrong-owner','blank-anchor')) {
        $request=Get-Content -LiteralPath "$run/fixture.png.request.json" -Raw | ConvertFrom-Json
        $request.Path=Join-Path $run "$case.png"
        $request.RequestedUtc=[DateTime]::UtcNow.ToString('o')
        if ($case -eq 'stale') { $request.RequestedUtc=[DateTime]::UtcNow.AddMinutes(-1).ToString('o') }
        if ($case -eq 'wrong-owner') { $request.ProcessId=$PID; $request.StartTicks=(Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks }
        if ($case -eq 'blank-anchor') {
            $request.Anchor.X=$capture.Bounds.Left+200; $request.Anchor.Y=$capture.Bounds.Bottom-40
            $request.Anchor.Width=100; $request.Anchor.Height=15
        }
        $requestFile=Join-Path $run "$case.request.json"
        $request | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $requestFile -Encoding utf8NoBOM
        $start=[Diagnostics.ProcessStartInfo]::new($pwsh)
        $start.UseShellExecute=$false; $start.CreateNoWindow=$true
        foreach ($argument in @('-NoProfile','-File',"$RepoRoot/tests/ui/capture.ps1",'-Request',$requestFile)) { $start.ArgumentList.Add($argument) }
        $helper=[Diagnostics.Process]::Start($start)
        try {
            if (-not $helper.WaitForExit(15000)) { $helper.Kill(); $helper.WaitForExit(5000) | Out-Null; throw "Negative capture timed out: $case" }
            if ($helper.ExitCode -eq 0 -or (Test-Path -LiteralPath $request.Path)) { throw "Invalid capture accepted: $case" }
            $reason=switch ($case) { stale { 'Stale capture request' }; wrong-owner { 'does not belong' }; blank-anchor { 'blank or lacks rendered text contrast' } }
            if (-not (Select-String -LiteralPath "$requestFile.error.txt" -SimpleMatch $reason -Quiet)) { throw "Negative capture failed for an unexpected reason: $case" }
        } finally { $helper.Dispose() }
        if ((Get-FileHash "$run/fixture.png").Hash -ne $before) { throw "Capture rejection damaged prior evidence: $case" }
        $passed++
        Write-Host "UI probe PASS: $case capture refused"
    }
    $second=$null
    try {
        $second=Start-Spellbook -Executable $pwsh -DataDir "$run/second-fixture-data" -PrefixArguments @('-NoProfile','-STA','-File',"$RepoRoot/tests/ui/fixture.ps1")
        [Spellbook.UiTesting.Native]::SetForegroundWindow($second.Window) | Out-Null
        if ([Spellbook.UiTesting.Native]::GetForegroundWindow() -ne $second.Window) { throw 'Cannot establish negative focus fixture' }
        Expect-Failure 'unowned foreground refused' 'not foreground' { Send-Keys $session -Text 'unsafe' }
        $secondValue=(Get-Element $second 'editable').GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern).Current.Value
        if ($secondValue -ne '') { throw 'Rejected keyboard input reached another window' }
    } finally { if ($second) { Stop-Spellbook $second } }
} finally { if ($session) { Stop-Spellbook $session } }
& $pwsh -NoProfile -File "$PSScriptRoot/drive.ps1" -Scenario shell -Config $Config -CaptureRoot "$run/captures" *> "$run/shell.log"
if ($LASTEXITCODE -ne 0) { throw "Positive shell driver failed: $run/shell.log" }
$passed++
# A standalone wrapper alters only the expected title and preserves the real scenario implementation.
$negative=Join-Path $run 'wrong-title.ps1'
$realScenario=Join-Path $RepoRoot 'tests/ui/scenarios/shell.ps1'
$quoted=$realScenario.Replace("'","''")
"param(`$Session, [string]`$OutputDirectory)`n& '$quoted' -Session `$Session -OutputDirectory `$OutputDirectory -ExpectedTitle 'Deliberately wrong title'" | Set-Content -LiteralPath $negative -Encoding utf8NoBOM
$published=Get-ChildItem "$run/captures/shell" -Filter '*.png' | Select-Object -First 1
$priorHash=(Get-FileHash $published.FullName).Hash
& $pwsh -NoProfile -File "$PSScriptRoot/drive.ps1" -Scenario shell -Config $Config -ScenarioFile $negative -CaptureRoot "$run/captures" *> "$run/wrong-title.log"
if ($LASTEXITCODE -eq 0 -or -not (Select-String -LiteralPath "$run/wrong-title.log" -SimpleMatch 'Window title mismatch' -Quiet)) { throw 'Wrong-title scenario was not rejected for its assertion' }
if ((Get-FileHash $published.FullName).Hash -ne $priorHash) { throw 'Failure replaced the previous valid capture' }
$passed++
Write-Host "UI driver probes: $passed passed; evidence: $run"
