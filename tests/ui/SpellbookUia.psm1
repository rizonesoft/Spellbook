# UI actions are scoped to the exact process this module launched.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
if (-not ('Spellbook.UiTesting.Native' -as [type])) { Add-Type -Path "$PSScriptRoot/Native.cs" }

function Assert-OwnedWindow($Session) {
    $Session.Process.Refresh()
    if ($Session.Process.HasExited -or $Session.Process.StartTime.ToUniversalTime().Ticks -ne $Session.StartTicks) {
        throw 'The launched process has exited or its identity changed'
    }
    [Spellbook.UiTesting.Native]::VerifyWindow($Session.Window, $Session.Process.Id)
}

function Start-Spellbook {
    <# .SYNOPSIS
    Launches one app with a new isolated data directory and waits at most 30 seconds for its window.
    .DESCRIPTION
    Executable and PrefixArguments also support an owned test fixture. No existing data folder is accepted.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Executable, [Parameter(Mandatory)][string]$DataDir,
          [string[]]$PrefixArguments = @())
    $exe = (Resolve-Path -LiteralPath $Executable).Path
    $data = [IO.Path]::GetFullPath($DataDir)
    if (Test-Path -LiteralPath $data) { throw "Data directory already exists: $data" }
    [IO.Directory]::CreateDirectory($data) | Out-Null
    $start = [Diagnostics.ProcessStartInfo]::new($exe)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    foreach ($argument in $PrefixArguments) { $start.ArgumentList.Add($argument) }
    $start.ArgumentList.Add('--data-dir')
    $start.ArgumentList.Add($data)
    $process = [Diagnostics.Process]::Start($start)
    try {
        $ticks = $process.StartTime.ToUniversalTime().Ticks
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        do {
            $process.Refresh()
            if ($process.HasExited) { throw "App exited before opening a window: $($process.ExitCode)" }
            if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
                $session = [pscustomobject]@{ Process=$process; StartTicks=$ticks; Window=$process.MainWindowHandle;
                    DataDir=$data; Executable=$exe; Nonce=[guid]::NewGuid().ToString(); Captures=@() }
                Assert-OwnedWindow $session
                return $session
            }
            Start-Sleep -Milliseconds 100
        } while ([DateTime]::UtcNow -lt $deadline)
        throw 'App did not open a visible window within 30 seconds'
    } catch {
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(5000) | Out-Null }
        $process.Dispose()
        throw
    }
}

function Get-Element {
    <# .SYNOPSIS
    Finds exactly one AutomationId within the owned window, or fails within TimeoutSeconds.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Session, [Parameter(Mandatory)][string]$AutomationId,
          [ValidateRange(0,30)][int]$TimeoutSeconds=5)
    $condition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        Assert-OwnedWindow $Session
        $root = [Windows.Automation.AutomationElement]::FromHandle($Session.Window)
        $found = $root.FindAll([Windows.Automation.TreeScope]::Subtree, $condition)
        if ($found.Count -gt 1) { throw "Ambiguous AutomationId: $AutomationId ($($found.Count) elements)" }
        if ($found.Count -eq 1) { return $found[0] }
        if ([DateTime]::UtcNow -ge $deadline) { break }
        Start-Sleep -Milliseconds 100
    } while ($true)
    throw "Missing AutomationId: $AutomationId"
}

function Assert-OwnedElement($Session, $Element) {
    Assert-OwnedWindow $Session
    if ($Element.Current.ProcessId -ne $Session.Process.Id) { throw 'Element belongs to another process' }
    if (-not $Element.Current.IsEnabled) { throw 'Element is disabled' }
}

function Invoke-Element {
    <# .SYNOPSIS
    Invokes an enabled element through InvokePattern; unsupported controls fail explicitly.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Session, [Parameter(Mandatory)]$Element)
    Assert-OwnedElement $Session $Element
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) { throw 'Element has no InvokePattern' }
    $pattern.Invoke()
}

function Set-ElementValue {
    <# .SYNOPSIS
    Sets and reads back a writable ValuePattern, without global keyboard input.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Session, [Parameter(Mandatory)]$Element, [AllowEmptyString()][string]$Value)
    Assert-OwnedElement $Session $Element
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) { throw 'Element has no ValuePattern' }
    if ($pattern.Current.IsReadOnly) { throw 'Element ValuePattern is read-only' }
    $pattern.SetValue($Value)
    if ($pattern.Current.Value -cne $Value) { throw 'ValuePattern readback did not match' }
}

function Send-Keys {
    <# .SYNOPSIS
    Sends Unicode text or a small chord only when the owned window already has foreground focus.
    .DESCRIPTION
    Chords use Ctrl, Alt, Shift, Enter, Escape, Tab, Backspace, Delete, Home, End, arrows, or one ASCII letter/digit.
    The function never steals focus and refuses held user modifiers or a changed foreground window.
    #>
    [CmdletBinding(DefaultParameterSetName='Text')]
    param([Parameter(Mandatory,Position=0)]$Session,
          [Parameter(Mandatory,ParameterSetName='Text')][string]$Text,
          [Parameter(Mandatory,ParameterSetName='Chord')][string]$Chord)
    Assert-OwnedWindow $Session
    if ($PSCmdlet.ParameterSetName -eq 'Text') {
        [Spellbook.UiTesting.Native]::SendText($Session.Window, $Session.Process.Id, $Text)
    } else {
        $map = @{ Ctrl=17; Alt=18; Shift=16; Enter=13; Escape=27; Tab=9; Backspace=8; Delete=46;
            Home=36; End=35; Left=37; Up=38; Right=39; Down=40 }
        $keys = @($Chord.Split('+') | ForEach-Object {
            if ($map.ContainsKey($_)) { [ushort]$map[$_] }
            elseif ($_ -cmatch '^[a-zA-Z0-9]$') { [ushort][char]$_.ToUpperInvariant() }
            else { throw "Unsupported key: $_" }
        })
        if (@($keys | Select-Object -Unique).Count -ne $keys.Count) { throw 'Duplicate chord keys' }
        [Spellbook.UiTesting.Native]::SendChord($Session.Window, $Session.Process.Id, [ushort[]]$keys)
    }
}

function Save-Capture {
    <# .SYNOPSIS
    Captures the owned window in a bounded helper, validates a visible text anchor, and returns its receipt.
    .DESCRIPTION
    Path must not exist. A failed capture never replaces an earlier image. The anchor is a visible UIA text element.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Session, [Parameter(Mandatory)][string]$Path,
          [Parameter(Mandatory)]$Anchor, [Parameter(Mandatory)][ValidateSet('light','dark')][string]$Theme)
    Assert-OwnedElement $Session $Anchor
    if ($Anchor.Current.IsOffscreen -or [string]::IsNullOrWhiteSpace($Anchor.Current.Name)) { throw 'Capture anchor is not visible text' }
    $target = [IO.Path]::GetFullPath($Path)
    if ((Test-Path -LiteralPath $target) -or (Test-Path -LiteralPath "$target.json")) { throw 'Capture destination already exists' }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    $requestPath = "$target.request.json"
    if (Test-Path -LiteralPath $requestPath) { throw 'Capture request already exists' }
    $bounds = $Anchor.Current.BoundingRectangle
    $request = @{ Window=$Session.Window.ToInt64(); ProcessId=$Session.Process.Id; StartTicks=$Session.StartTicks;
        Nonce=$Session.Nonce; Path=$target; Theme=$Theme; RequestedUtc=[DateTime]::UtcNow.ToString('o');
        Anchor=@{ X=$bounds.X; Y=$bounds.Y; Width=$bounds.Width; Height=$bounds.Height; Name=$Anchor.Current.Name } }
    $request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $requestPath -Encoding utf8NoBOM
    $start = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    foreach ($arg in @('-NoProfile','-File',"$PSScriptRoot/capture.ps1",'-Request',$requestPath)) { $start.ArgumentList.Add($arg) }
    $helper = [Diagnostics.Process]::Start($start)
    try {
        if (-not $helper.WaitForExit(15000)) { $helper.Kill(); $helper.WaitForExit(5000) | Out-Null; throw 'Capture helper timed out' }
        if ($helper.ExitCode -ne 0) { throw "Capture helper failed ($($helper.ExitCode)); request retained: $requestPath" }
        Assert-OwnedWindow $Session
        $receipt = Get-Content -LiteralPath "$target.json" -Raw | ConvertFrom-Json
        if ($receipt.Nonce -ne $Session.Nonce -or $receipt.ProcessId -ne $Session.Process.Id -or
            $receipt.Sha256 -ne (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()) { throw 'Capture receipt identity or hash mismatch' }
        $Session.Captures += $receipt
        return $receipt
    } finally { $helper.Dispose() }
}

function Read-Log {
    <# .SYNOPSIS
    Reads only the isolated session log, with an optional literal substring filter.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Session, [string]$Contains='')
    $path = Join-Path $Session.DataDir 'logs/spellbook.log'
    if (-not (Test-Path -LiteralPath $path)) { throw 'Session log does not exist' }
    Get-Content -LiteralPath $path | Where-Object { $_.Contains($Contains) }
}

function Stop-Spellbook {
    <# .SYNOPSIS
    Closes only this session's process; a timeout forces owned-process cleanup and reports failure.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Session)
    $process = $Session.Process
    try {
        if (-not $process.HasExited) {
            Assert-OwnedWindow $Session
            if (-not $process.CloseMainWindow()) { throw 'Owned window refused a close message' }
            if (-not $process.WaitForExit(10000)) { throw 'Owned process did not close within 10 seconds' }
        }
        if ($process.ExitCode -ne 0) { throw "App exit code: $($process.ExitCode)" }
    } finally {
        if (-not $process.HasExited -and $process.StartTime.ToUniversalTime().Ticks -eq $Session.StartTicks) {
            $process.Kill(); $process.WaitForExit(5000) | Out-Null
        }
        $process.Dispose()
    }
}

Export-ModuleMember -Function Start-Spellbook, Get-Element, Invoke-Element, Set-ElementValue, Send-Keys, Save-Capture, Read-Log, Stop-Spellbook
