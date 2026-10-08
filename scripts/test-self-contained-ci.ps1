<#
.SYNOPSIS
  Proves folder deployment on a disposable GitHub-hosted Windows VM.
.DESCRIPTION
  Refuses local/self-hosted execution before any package or filesystem change.
  Removes registered Windows App Runtime packages for the disposable runner user,
  then extracts the verified portable ZIP outside the checkout and captures its window.
#>
#Requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Clean-runtime proof requires a disposable GitHub-hosted runner'
}
. "$PSScriptRoot/_common.ps1"
$versionHeader = Join-Path (Get-BuildDir Release) 'src/core/generated/spellbook/core/build_info.hpp'
$version = (Select-String -LiteralPath $versionHeader -Pattern 'kSemVer = "([^"]+)"').Matches[0].Groups[1].Value
$archive = Join-Path $RepoRoot "artifacts/dist/Spellbook-$version-win-x64-portable.zip"
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
$checksum = '{0}  {1}' -f $archiveHash, ([IO.Path]::GetFileName($archive))
if ((Get-Content -LiteralPath (Join-Path $RepoRoot 'artifacts/dist/SHA256SUMS') -Raw).Trim() -ne $checksum) { throw 'Portable ZIP checksum differs before deployment' }
$packages = @(Get-AppxPackage '*WindowsAppRuntime*')
foreach ($package in $packages) { Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop }
if (@(Get-AppxPackage '*WindowsAppRuntime*').Count -ne 0) { throw 'Windows App Runtime remains registered' }
Write-Host 'PASS: no Windows App Runtime package registered for the runner user'
$copyRoot = Join-Path $env:RUNNER_TEMP "spellbook-deployment-$([Guid]::NewGuid())"
$repoFull = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\') + '\'
if ([IO.Path]::GetFullPath($copyRoot).StartsWith($repoFull, [StringComparison]::OrdinalIgnoreCase)) { throw 'Deployment copy must be outside the repository' }
New-Item -ItemType Directory -Path $copyRoot | Out-Null
Expand-Archive -LiteralPath $archive -DestinationPath $copyRoot
$exe = Join-Path $copyRoot 'Spellbook.exe'
$evidence = Join-Path $RepoRoot 'build/self-contained-proof'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
@{ archive = [IO.Path]::GetFileName($archive); sha256 = $archiveHash; version = $version } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'package.json')
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class SpellbookCapture {
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] public struct MinMax { public Point Reserved, MaxSize, MaxPosition, MinTrack, MaxTrack; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr window);
  [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr value);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr window, IntPtr dc, uint flags);
  [DllImport("user32.dll", EntryPoint="SendMessageW")] public static extern IntPtr ReadMinMax(IntPtr window, uint message, IntPtr parameter, ref MinMax limits);
}
'@
$start = [Diagnostics.ProcessStartInfo]::new($exe)
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.ArgumentList.Add('--data-dir')
$start.ArgumentList.Add((Join-Path $copyRoot 'visual data'))
$process = [Diagnostics.Process]::Start($start)
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 200
        $process.Refresh()
    } until ($process.MainWindowTitle -eq 'Spellbook' -or $process.HasExited -or [DateTime]::UtcNow -gt $deadline)
    if ($process.HasExited -or $process.MainWindowTitle -ne 'Spellbook') { throw 'Copied app did not open its Spellbook window' }
    Start-Sleep -Seconds 2
    $window = $process.MainWindowHandle
    $previousDpi = [SpellbookCapture]::SetThreadDpiAwarenessContext([IntPtr]::new(-4))
    try {
        $rect = [SpellbookCapture+Rect]::new()
        if (-not [SpellbookCapture]::GetWindowRect($window, [ref]$rect)) { throw 'Cannot read window bounds' }
        $dpi = [SpellbookCapture]::GetDpiForWindow($window)
        $limits = [SpellbookCapture+MinMax]::new()
        [SpellbookCapture]::ReadMinMax($window, 0x24, [IntPtr]::Zero, [ref]$limits) | Out-Null
        if ($limits.MinTrack.X -ne (480 * $dpi / 96) -or $limits.MinTrack.Y -ne (320 * $dpi / 96)) { throw "Minimum window size is not 480 by 320 DIPs: $($limits.MinTrack.X) x $($limits.MinTrack.Y) at $dpi DPI" }
        $bitmap = [Drawing.Bitmap]::new($rect.Right - $rect.Left, $rect.Bottom - $rect.Top)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $dc = $graphics.GetHdc()
        try { if (-not [SpellbookCapture]::PrintWindow($window, $dc, 2)) { throw 'Window capture failed' } }
        finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
        try { $bitmap.Save((Join-Path $evidence 'window.png')) } finally { $bitmap.Dispose() }
        $modules = @($process.Modules | Where-Object { $_.ModuleName -match 'Microsoft\.(WindowsAppRuntime|UI\.Xaml)' } | ForEach-Object { $_.FileName })
        if ($modules.Count -eq 0) { throw 'Runtime module evidence missing' }
        foreach ($module in $modules) {
            if (-not $module.StartsWith($copyRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Runtime loaded outside copied folder: $module" }
        }
        @{ title=$process.MainWindowTitle; dpi=$dpi; minimumWidth=$limits.MinTrack.X; minimumHeight=$limits.MinTrack.Y; registeredRuntimePackages=0; copyRoot=$copyRoot; modules=$modules } | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $evidence 'window.json')
    } finally { [SpellbookCapture]::SetThreadDpiAwarenessContext($previousDpi) | Out-Null }
    if (-not $process.CloseMainWindow() -or -not $process.WaitForExit(10000) -or $process.ExitCode -ne 0) { throw 'Window did not close cleanly' }
} finally {
    if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose()
}
$start.ArgumentList.Clear()
$start.ArgumentList.Add('--smoke')
$start.ArgumentList.Add('--data-dir')
$smokeData = Join-Path $copyRoot 'smoke data'
$start.ArgumentList.Add($smokeData)
$process = [Diagnostics.Process]::Start($start)
try {
    if (-not $process.WaitForExit(60000)) { $process.Kill(); $process.WaitForExit(); throw 'Copied app smoke timed out' }
    if ($process.ExitCode -ne 0) { throw "Copied app smoke failed: $($process.ExitCode)" }
} finally { $process.Dispose() }
Copy-Item -LiteralPath (Join-Path $smokeData 'logs/spellbook.log') -Destination (Join-Path $evidence 'smoke.log')
Get-Content (Join-Path $evidence 'smoke.log') | Select-Object -Last 10
Write-Host "self-contained proof: PASS (external folder, no registered runtime, visible window, smoke exit 0); $evidence"
