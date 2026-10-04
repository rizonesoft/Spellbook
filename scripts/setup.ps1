<#
.SYNOPSIS
  Verifies and repairs the Spellbook toolchain on this machine.
.DESCRIPTION
  Legs (each reported by name, with the fix when it fails):
    msvc     Visual Studio 2022 or Build Tools with the C++ x64 toolset and a
             Windows SDK. Machine-wide by necessity. -InstallMsvc installs the
             VS 2022 Build Tools with winget; otherwise the command is printed.
    tools    cmake, ninja, clang-format, and clang-tidy at the versions pinned in
             toolchain.json, downloaded into .tools/<name>/ and SHA-256 checked.
    vcpkg    a clone of microsoft/vcpkg at the pinned commit in .tools/vcpkg,
             bootstrapped (vcpkg.exe). The commit equals vcpkg.json's builtin-baseline.
    hooks    git core.hooksPath = tools/githooks (when this is a git work tree).
    python   Python 3 on PATH (the TODO plan gates in scripts/check-all.ps1).
  -Verify only checks: exit 0 when every leg is green, 1 otherwise.
  Without -Verify, failing legs are repaired, then verified again.
.PARAMETER Verify
  Check only; change nothing.
.PARAMETER InstallMsvc
  Install the VS 2022 Build Tools (C++ workload) with winget when MSVC is missing.
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/setup.ps1
  pwsh scripts/setup.ps1 -Verify
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$Verify,
    [switch]$InstallMsvc,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Test-ComponentLeg($c) {
    $path = Join-Path (Join-Path $ToolsDir $c.dir) $c.probe
    if (-not (Test-Path $path)) { return @{ Ok = $false; Detail = "missing ($path)" } }
    $out = (& $path @($c.versionArgs) 2>&1 | Out-String)
    if ($out -match $c.versionMatch -and $Matches[1] -eq $c.version) {
        return @{ Ok = $true; Detail = "$($c.version) $path" }
    }
    return @{ Ok = $false; Detail = "present but reports '$($out.Trim())', wanted $($c.version)" }
}

function Install-Component($c) {
    $dest = Join-Path $ToolsDir $c.dir
    $work = Join-Path $ToolsDir ('.download-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    try {
        $archive = Join-Path $work 'archive.zip'
        Write-Step "download $($c.name) $($c.version)"
        Invoke-WebRequest -Uri $c.url -OutFile $archive -UseBasicParsing
        $hash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $c.sha256) { throw "$($c.name): SHA-256 $hash does not match the pin $($c.sha256)" }
        $unpacked = Join-Path $work 'unpacked'
        [IO.Compression.ZipFile]::ExtractToDirectory($archive, $unpacked)
        $root = $unpacked
        if ($c.stripRoot) {
            $dirs = @(Get-ChildItem $unpacked -Directory)
            if ($dirs.Count -ne 1) { throw "$($c.name): expected one top-level folder in the archive" }
            $root = $dirs[0].FullName
        }
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
        Move-Item $root $dest
        Set-Content -Path (Join-Path $dest '.pinned-version') -Value $c.version -Encoding ascii
    } finally {
        Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
    }
}

function Test-VcpkgLeg {
    $v = $Toolchain.vcpkg
    $root = Join-Path $ToolsDir $v.dir
    if (-not (Test-Path (Join-Path $root '.git'))) { return @{ Ok = $false; Detail = "no clone at $root" } }
    $head = (& git -C $root rev-parse HEAD 2>$null)
    if ($head -ne $v.commit) { return @{ Ok = $false; Detail = "clone at $head, wanted $($v.commit)" } }
    if (-not (Test-Path (Join-Path $root 'vcpkg.exe'))) { return @{ Ok = $false; Detail = 'not bootstrapped (vcpkg.exe missing)' } }
    $manifest = Get-Content (Join-Path $RepoRoot 'vcpkg.json') -Raw | ConvertFrom-Json
    if ($manifest.'builtin-baseline' -ne $v.commit) {
        return @{ Ok = $false; Detail = "vcpkg.json builtin-baseline $($manifest.'builtin-baseline') differs from toolchain.json $($v.commit)" }
    }
    return @{ Ok = $true; Detail = "$($v.commit.Substring(0, 12)) $root" }
}

function Install-Vcpkg {
    $v = $Toolchain.vcpkg
    $root = Join-Path $ToolsDir $v.dir
    if (-not (Test-Path (Join-Path $root '.git'))) {
        Write-Step "clone vcpkg into $root"
        Invoke-Native git clone --quiet $v.repository $root
    }
    $have = (& git -C $root cat-file -t $v.commit 2>$null)
    if ($have -ne 'commit') { Invoke-Native git -C $root fetch --quiet origin }
    Invoke-Native git -C $root -c advice.detachedHead=false checkout --quiet $v.commit
    Write-Step 'bootstrap vcpkg'
    Invoke-Native (Join-Path $root 'bootstrap-vcpkg.bat') -disableMetrics
}

function Test-MsvcLeg {
    $vs = Find-VisualStudio
    if (-not $vs) { return @{ Ok = $false; Detail = 'no Visual Studio or Build Tools with Microsoft.VisualStudio.Component.VC.Tools.x86.x64' } }
    $sdk = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\Include'
    if (-not (Test-Path $sdk)) { return @{ Ok = $false; Detail = "MSVC at $vs, but no Windows 10/11 SDK under $sdk" } }
    $toolsets = @(Get-ChildItem (Join-Path $vs 'VC\Tools\MSVC') -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
    return @{ Ok = $true; Detail = "$vs (MSVC $($toolsets -join ', '))" }
}

function Install-Msvc {
    $m = $Toolchain.msvc
    $cmd = "winget install --id $($m.wingetId) --exact --override `"$($m.wingetOverride)`""
    if (-not $InstallMsvc) {
        Write-Host "  MSVC is machine-wide and is not installed automatically. Install it with:" -ForegroundColor Yellow
        Write-Host "    $cmd" -ForegroundColor Yellow
        Write-Host '  or rerun: pwsh scripts/setup.ps1 -InstallMsvc' -ForegroundColor Yellow
        return
    }
    Write-Step $cmd
    Invoke-Native winget install --id $m.wingetId --exact --accept-package-agreements --accept-source-agreements --override $m.wingetOverride
}

function Test-HooksLeg {
    $inside = (& git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null)
    if ($inside -ne 'true') { return @{ Ok = $true; Detail = 'not a git work tree; skipped' } }
    $path = (& git -C $RepoRoot config --get core.hooksPath 2>$null)
    if ($path -eq 'tools/githooks') { return @{ Ok = $true; Detail = 'core.hooksPath = tools/githooks' } }
    return @{ Ok = $false; Detail = "core.hooksPath is '$path'" }
}

function Test-PythonLeg {
    foreach ($py in 'python', 'python3') {
        $cmd = Get-Command $py -ErrorAction SilentlyContinue
        if ($cmd) {
            $v = (& $cmd.Source --version 2>&1 | Out-String).Trim()
            if ($v -match 'Python 3\.') { return @{ Ok = $true; Detail = "$v ($($cmd.Source))" } }
        }
    }
    return @{ Ok = $false; Detail = 'no Python 3 on PATH; install it: winget install --id Python.Python.3.14' }
}

function Invoke-Legs {
    $results = [ordered]@{}
    $results['msvc'] = Test-MsvcLeg
    foreach ($c in $Toolchain.components) { $results[$c.name] = Test-ComponentLeg $c }
    $results['vcpkg'] = Test-VcpkgLeg
    $results['hooks'] = Test-HooksLeg
    $results['python'] = Test-PythonLeg
    return $results
}

function Write-Legs($results) {
    foreach ($k in $results.Keys) {
        $r = $results[$k]
        $color = if ($r.Ok) { 'Green' } else { 'Red' }
        $mark = if ($r.Ok) { 'OK  ' } else { 'FAIL' }
        Write-Host ("  {0} {1,-13} {2}" -f $mark, $k, $r.Detail) -ForegroundColor $color
    }
}

New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
Write-Host 'Spellbook toolchain' -ForegroundColor Cyan
$results = Invoke-Legs
Write-Legs $results

$failed = @($results.Keys | Where-Object { -not $results[$_].Ok })
if ($failed.Count -eq 0) { Write-Host 'setup: all legs green' -ForegroundColor Green; exit 0 }
if ($Verify) { Write-Host "setup: $($failed.Count) leg(s) failed: $($failed -join ', ')" -ForegroundColor Red; exit 1 }

foreach ($leg in $failed) {
    switch ($leg) {
        'msvc' { Install-Msvc }
        'vcpkg' { Install-Vcpkg }
        'hooks' { Invoke-Native git -C $RepoRoot config core.hooksPath tools/githooks }
        'python' { Write-Host "  $($results['python'].Detail)" -ForegroundColor Yellow }
        default { Install-Component (Get-Component $leg) }
    }
}

Write-Host 'Spellbook toolchain (after repair)' -ForegroundColor Cyan
$results = Invoke-Legs
Write-Legs $results
$failed = @($results.Keys | Where-Object { -not $results[$_].Ok })
if ($failed.Count -eq 0) { Write-Host 'setup: all legs green' -ForegroundColor Green; exit 0 }
Write-Host "setup: $($failed.Count) leg(s) still failing: $($failed -join ', ')" -ForegroundColor Red
exit 1
