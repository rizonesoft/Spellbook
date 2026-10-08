<#
.SYNOPSIS
  Proves the Release runner rejects an owned C++ warning in an isolated checkout.
.DESCRIPTION
  Copies the current candidate into a new ignored build/warning-probes checkout,
  reuses the pinned tools through a junction, and injects a deprecation warning
  only into that copy of MainWindow.xaml.cpp. The real worktree is never edited.
  Retains the clone and logs as evidence; never commits or pushes the probe.
#>
#Requires -Version 7.0
[CmdletBinding()]
param([switch]$Help)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }

$evidence = Join-Path $RepoRoot "build/warning-probes/$([Guid]::NewGuid())"
$clone = [IO.Path]::GetFullPath((Join-Path $evidence 'repo'))
$allowed = [IO.Path]::GetFullPath((Join-Path $RepoRoot 'build/warning-probes')) + [IO.Path]::DirectorySeparatorChar
if (-not $clone.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe warning probe path' }
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
& git clone --quiet --local --no-hardlinks $RepoRoot $clone
if ($LASTEXITCODE -ne 0) { throw 'Warning probe clone failed' }
$candidatePaths = @(& git -C $RepoRoot ls-files -co --exclude-standard | Sort-Object -Unique)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inventory the candidate' }
foreach ($relative in $candidatePaths) {
    $source = Join-Path $RepoRoot $relative
    $target = [IO.Path]::GetFullPath((Join-Path $clone $relative))
    if (-not $target.StartsWith(($clone + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe candidate path $relative" }
    if (Test-Path -LiteralPath $source -PathType Leaf) {
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target -Force
    } elseif (Test-Path -LiteralPath $target -PathType Leaf) {
        Remove-Item -LiteralPath $target -Force
    }
}
if (-not (Test-Path -LiteralPath $ToolsDir -PathType Container)) { throw 'Pinned tools are not provisioned' }
New-Item -ItemType Junction -Path (Join-Path $clone '.tools') -Target $ToolsDir | Out-Null
$source = Join-Path $clone 'src/app/MainWindow.xaml.cpp'
$original = [IO.File]::ReadAllBytes((Join-Path $RepoRoot 'src/app/MainWindow.xaml.cpp'))
@'

namespace {
[[deprecated("Spellbook runner warning probe")]] void spellbook_warning_target() {}
}
void spellbook_warning_probe() { spellbook_warning_target(); }
'@ | Add-Content -LiteralPath $source -Encoding utf8
$log = Join-Path $evidence 'build-warning.log'
& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $clone 'scripts/build.ps1') -Config Release *> $log
$result = $LASTEXITCODE
Set-Content -LiteralPath (Join-Path $evidence 'build-warning.exit.txt') -Value $result
$current = [IO.File]::ReadAllBytes((Join-Path $RepoRoot 'src/app/MainWindow.xaml.cpp'))
if (-not [Linq.Enumerable]::SequenceEqual[byte]($original, $current)) { throw 'Original source changed during probe; preserve and inspect it' }
$text = Get-Content -LiteralPath $log -Raw
if ($result -eq 0 -or $text -notmatch '(warning|error) C4996' -or $text -notmatch 'Spellbook runner warning probe') {
    Get-Content -LiteralPath $log -Tail 20
    throw "The runner did not prove warning rejection (exit $result); $log"
}
@{ exit = $result; warning = 'C4996'; originalSourceUnchanged = $true; clone = $clone; log = $log } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'receipt.json')
Write-Host "build warning probe: PASS (owned C4996 rejected; original source unchanged); $evidence" -ForegroundColor Green
