<#
.SYNOPSIS
  Drives the built WinUI shell against disposable data, including failure paths.
#>
#Requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('Debug', 'Release', 'RelWithDebInfo')][string]$Config = 'Release')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
$exe = Get-ExePath $Config
if (-not (Test-Path -LiteralPath $exe)) { throw "Build $Config before running app probes" }
$probeRoot = Join-Path $RepoRoot "build/app-probes/$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $probeRoot -Force | Out-Null

function Invoke-AppProbe([string]$Name, [string[]]$Arguments, [int]$ExpectedExit) {
    $start = [Diagnostics.ProcessStartInfo]::new($exe)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        if (-not $process.WaitForExit(60000)) {
            $process.Kill()
            $process.WaitForExit()
            throw "$Name timed out (possible blocking dialog)"
        }
        if ($process.ExitCode -ne $ExpectedExit) { throw "$Name exited $($process.ExitCode), expected $ExpectedExit" }
    } finally { $process.Dispose() }
    Write-Host "PASS: $Name (exit $ExpectedExit)"
}

$data = Join-Path $probeRoot 'data with spaces'
Invoke-AppProbe 'first frame and space-containing data path' @('--smoke', '--data-dir', $data) 0
$log = Join-Path $data 'logs/spellbook.log'
foreach ($expected in @('at schema version 1', 'Main window created: WinUI 3', 'Smoke run: window painted, closing', 'Main window closed')) {
    if (-not (Select-String -LiteralPath $log -SimpleMatch $expected -Quiet)) { throw "Missing smoke evidence: $expected" }
}
$db = Join-Path $data 'spellbook.db'
& python -c 'import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); v=c.execute("PRAGMA user_version").fetchone()[0]; assert v==1,v; print("PASS: database readback schema version 1")' $db
if ($LASTEXITCODE -ne 0) { throw 'Database readback failed' }
Invoke-AppProbe 'existing database restart' @('--data-dir', $data, '--smoke') 0
Invoke-AppProbe 'smoke without isolated data refuses startup' @('--smoke') 1
Invoke-AppProbe 'missing data argument remains noninteractive' @('--data-dir', '--smoke') 1
Invoke-AppProbe 'unknown option remains noninteractive' @('--unknown', '--smoke', '--data-dir', $data) 1
$blocked = Join-Path $probeRoot 'file instead of directory'
Set-Content -LiteralPath $blocked -Value 'probe'
Invoke-AppProbe 'data-directory failure remains noninteractive' @('--smoke', '--data-dir', $blocked) 1
$future = Join-Path $probeRoot 'future schema'
New-Item -ItemType Directory -Path $future | Out-Null
& python -c 'import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); c.execute("PRAGMA user_version=999"); c.close()' (Join-Path $future 'spellbook.db')
if ($LASTEXITCODE -ne 0) { throw 'Future database fixture failed' }
Invoke-AppProbe 'newer schema refuses startup without a dialog' @('--smoke', '--data-dir', $future) 1
$version = (Get-Item -LiteralPath $exe).VersionInfo
if (-not $version.ProductVersion -or $version.ProductName -ne 'Spellbook') { throw 'Executable version resource is missing' }
Add-Type -AssemblyName System.Drawing
$icon = [Drawing.Icon]::ExtractAssociatedIcon($exe)
if (-not $icon) { throw 'Executable icon is missing' }
$icon.Dispose()
Write-Host "PASS: executable resources (Spellbook $($version.ProductVersion), icon)"
foreach ($context in @(@{ Actions='false'; Runner='github-hosted' }, @{ Actions='true'; Runner='self-hosted' })) {
    $guard = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    $guard.UseShellExecute = $false
    $guard.CreateNoWindow = $true
    $guard.RedirectStandardError = $true
    # Stub the first package operation so even a broken guard cannot touch the machine.
    $guard.Environment['SPELLBOOK_GUARD_SCRIPT'] = Join-Path $PSScriptRoot 'test-self-contained-ci.ps1'
    $probeCommand = 'function Get-AppxPackage { throw "UNSAFE: package discovery reached" }; function Remove-AppxPackage { throw "UNSAFE: package removal reached" }; & $env:SPELLBOOK_GUARD_SCRIPT'
    foreach ($argument in @('-NoProfile', '-Command', $probeCommand)) { $guard.ArgumentList.Add($argument) }
    $guard.Environment['GITHUB_ACTIONS'] = $context.Actions
    $guard.Environment['RUNNER_ENVIRONMENT'] = $context.Runner
    $process = [Diagnostics.Process]::Start($guard)
    try {
        $errorText = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 1 -or $errorText -notmatch 'requires a disposable GitHub-hosted runner') { throw 'Clean-runtime guard failed to refuse unsafe execution' }
    } finally { $process.Dispose() }
}
Write-Host 'PASS: clean-runtime proof refuses local and self-hosted execution'
& python (Join-Path $PSScriptRoot 'test_startup_dialogs.py') $exe $probeRoot
if ($LASTEXITCODE -ne 0) { throw "Interactive startup dialog probes failed; $probeRoot/startup-dialogs.json" }
Write-Host "app probes: all passed; evidence: $probeRoot"
