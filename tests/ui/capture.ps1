# Private, disposable helper: PrintWindow is synchronous, so the parent bounds its lifetime.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Request)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -Path "$PSScriptRoot/Native.cs"
Add-Type -AssemblyName System.Drawing
$r = Get-Content -LiteralPath $Request -Raw | ConvertFrom-Json
$window = [IntPtr][long]$r.Window
$owner = Get-Process -Id $r.ProcessId
$bitmap=$null; $graphics=$null; $previous=[IntPtr]::Zero
try {
    if ($owner.StartTime.ToUniversalTime().Ticks -ne $r.StartTicks) { throw 'Process identity changed before capture' }
    $age=([DateTimeOffset]::UtcNow - [DateTimeOffset]$r.RequestedUtc).TotalSeconds
    if ($age -lt -1 -or $age -gt 15) { throw 'Stale capture request' }
    if ((Test-Path -LiteralPath $r.Path) -or (Test-Path -LiteralPath "$($r.Path).json")) { throw 'Capture destination exists' }
    [Spellbook.UiTesting.Native]::VerifyWindow($window, $r.ProcessId)
    $previous = [Spellbook.UiTesting.Native]::SetThreadDpiAwarenessContext([IntPtr](-4))
    if ($previous -eq [IntPtr]::Zero) { throw 'Cannot establish physical-pixel capture coordinates' }
    $rect = [Spellbook.UiTesting.Native+Rect]::new()
    if (-not [Spellbook.UiTesting.Native]::GetWindowRect($window, [ref]$rect)) { throw 'Cannot read window bounds' }
    $width=$rect.Right-$rect.Left; $height=$rect.Bottom-$rect.Top
    if ($width -lt 100 -or $height -lt 100 -or $width -gt 10000 -or $height -gt 10000) { throw 'Invalid capture dimensions' }
    $dpi=[Spellbook.UiTesting.Native]::GetDpiForWindow($window)
    $contrast=[Spellbook.UiTesting.Native]::HighContrastEnabled()
    if ($dpi -lt 48 -or $dpi -gt 768) { throw 'Invalid observed DPI' }
    $bitmap=[Drawing.Bitmap]::new($width,$height)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    $dc=$graphics.GetHdc()
    try { if (-not [Spellbook.UiTesting.Native]::PrintWindow($window,$dc,2)) { throw 'PrintWindow failed' } }
    finally { $graphics.ReleaseHdc($dc) }
    $after=[Spellbook.UiTesting.Native+Rect]::new()
    [Spellbook.UiTesting.Native]::VerifyWindow($window,$r.ProcessId)
    $owner.Refresh()
    if ($owner.HasExited -or [Spellbook.UiTesting.Native]::HighContrastEnabled() -ne $contrast) { throw 'Owner or contrast state changed during capture' }
    if (-not [Spellbook.UiTesting.Native]::GetWindowRect($window,[ref]$after) -or
        $after.Left -ne $rect.Left -or $after.Top -ne $rect.Top -or $after.Right -ne $rect.Right -or $after.Bottom -ne $rect.Bottom -or
        [Spellbook.UiTesting.Native]::GetDpiForWindow($window) -ne $dpi) { throw 'Window moved or changed DPI during capture' }
    $x=[int][Math]::Floor($r.Anchor.X-$rect.Left); $y=[int][Math]::Floor($r.Anchor.Y-$rect.Top)
    $aw=[int][Math]::Floor($r.Anchor.Width); $ah=[int][Math]::Floor($r.Anchor.Height)
    if ($aw -lt 10 -or $ah -lt 5 -or $x -lt 0 -or $y -lt 0 -or $x+$aw -gt $width -or $y+$ah -gt $height) { throw 'Text anchor falls outside captured window' }
    $minimum=255; $maximum=0; $dark=0; $light=0
    for ($row=$y; $row -lt $y+$ah; $row++) {
        for ($col=$x; $col -lt $x+$aw; $col+=2) {
            $pixel=$bitmap.GetPixel($col,$row)
            $luma=[int](0.2126*$pixel.R+0.7152*$pixel.G+0.0722*$pixel.B)
            $minimum=[Math]::Min($minimum,$luma); $maximum=[Math]::Max($maximum,$luma)
            if ($luma -lt 100) { $dark++ }; if ($luma -gt 155) { $light++ }
        }
    }
    if ($maximum-$minimum -lt 60 -or $dark -lt 5 -or $light -lt 5) { throw 'Capture text anchor is blank or lacks rendered text contrast' }
    $output=[IO.File]::Open($r.Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $bitmap.Save($output,[Drawing.Imaging.ImageFormat]::Png) } finally { $output.Dispose() }
    $receipt=[ordered]@{ Nonce=$r.Nonce; ProcessId=$r.ProcessId; StartTicks=$r.StartTicks; Window=$r.Window;
        RequestedUtc=$r.RequestedUtc; CapturedUtc=[DateTime]::UtcNow.ToString('o'); Path=$r.Path;
        Width=$width; Height=$height; Dpi=$dpi; Theme=$r.Theme; HighContrast=$contrast;
        Bounds=@{ Left=$rect.Left; Top=$rect.Top; Right=$rect.Right; Bottom=$rect.Bottom };
        Anchor=$r.Anchor; AnchorContrast=$maximum-$minimum;
        Sha256=(Get-FileHash -LiteralPath $r.Path -Algorithm SHA256).Hash.ToLowerInvariant() }
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "$($r.Path).json" -Encoding utf8NoBOM
} catch {
    $_ | Out-String | Set-Content -LiteralPath "$Request.error.txt"
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally {
    if ($graphics) { $graphics.Dispose() }; if ($bitmap) { $bitmap.Dispose() }
    if ($previous -ne [IntPtr]::Zero) { [Spellbook.UiTesting.Native]::SetThreadDpiAwarenessContext($previous) | Out-Null }
    $owner.Dispose()
}
