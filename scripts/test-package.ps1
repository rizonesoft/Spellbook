<#
.SYNOPSIS
  Packages the built Release folder, verifies its ZIP, and smoke-runs an extracted copy.
.DESCRIPTION
  Requires an existing Release build. Uses disposable build/package-probes data,
  checks the archive hash, payload and notices, then reads back the migrated schema.
  Fixture tests cover incomplete output, missing vendor terms and unsafe paths.
#>
#Requires -Version 7.0
[CmdletBinding()]
param([switch]$Help)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help) { Show-ScriptHelp $PSCommandPath; exit 0 }

Invoke-Native python (Join-Path $PSScriptRoot 'test_package_payload.py') '-v'
& "$PSScriptRoot/package.ps1" -SkipBuild
if ($LASTEXITCODE -ne 0) { throw 'Packaging failed' }
$versionHeader = Join-Path (Get-BuildDir Release) 'src/core/generated/spellbook/core/build_info.hpp'
$version = (Select-String -LiteralPath $versionHeader -Pattern 'kSemVer = "([^"]+)"').Matches[0].Groups[1].Value
$zip = Join-Path $RepoRoot "artifacts/dist/Spellbook-$version-win-x64-portable.zip"
$expectedSum = '{0}  {1}' -f (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant(), ([IO.Path]::GetFileName($zip))
if ((Get-Content -LiteralPath (Join-Path $RepoRoot 'artifacts/dist/SHA256SUMS') -Raw).Trim() -ne $expectedSum) { throw 'ZIP checksum receipt does not match' }
$probe = Join-Path $RepoRoot "build/package-probes/$([Guid]::NewGuid())"
$extracted = Join-Path $probe 'extracted app'
New-Item -ItemType Directory -Path $extracted -Force | Out-Null
Expand-Archive -LiteralPath $zip -DestinationPath $extracted
foreach ($name in @('Spellbook.exe', 'Spellbook.pri', 'spellbook.ico', 'Microsoft.UI.Xaml.dll', 'Microsoft.UI.Xaml.Controls.dll', 'Microsoft.WindowsAppRuntime.dll', 'LICENSE', 'README.md', 'THIRD-PARTY-NOTICES/README.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $extracted $name) -PathType Leaf)) { throw "Extracted payload missing $name" }
}
if (Get-ChildItem -LiteralPath $extracted -Recurse -File | Where-Object Extension -in @('.pdb', '.lib', '.exp', '.ilk', '.ipdb', '.iobj')) { throw 'Development files leaked into payload' }
foreach ($name in @('microsoft.windowsappsdk', 'microsoft.windows.cppwinrt')) {
    $terms = Join-Path $extracted "THIRD-PARTY-NOTICES/NuGet/$name"
    if (-not (Test-Path -LiteralPath $terms -PathType Container)) { throw "Extracted vendor terms missing: $name" }
}
$binary = Join-Path $extracted 'Spellbook.exe'
if ([Diagnostics.FileVersionInfo]::GetVersionInfo($binary).ProductVersion -ne $version) { throw 'Extracted executable version differs from package version' }
$data = Join-Path $probe 'isolated data'
$start = [Diagnostics.ProcessStartInfo]::new($binary)
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
foreach ($arg in @('--smoke', '--data-dir', $data)) { $start.ArgumentList.Add($arg) }
$process = [Diagnostics.Process]::Start($start)
try {
    if (-not $process.WaitForExit(30000)) { $process.Kill(); $process.WaitForExit(); throw 'Extracted app smoke timed out' }
    if ($process.ExitCode -ne 0) { throw "Extracted app smoke failed: $($process.ExitCode)" }
} finally { $process.Dispose() }
$database = Join-Path $data 'spellbook.db'
$schema = & python -c 'import pathlib,sqlite3,sys; p=pathlib.Path(sys.argv[1]).resolve(); c=sqlite3.connect(p.as_uri()+"?mode=ro",uri=True); print(c.execute("PRAGMA user_version").fetchone()[0]); c.close()' $database
if ($LASTEXITCODE -ne 0) { throw 'Extracted smoke database readback failed' }
$latest = (Get-ChildItem (Join-Path $RepoRoot 'migrations') -Filter '*.sql' | ForEach-Object { [int]($_.BaseName -split '_')[0] } | Measure-Object -Maximum).Maximum
if ([int]$schema -ne $latest) { throw "Extracted app schema $schema differs from latest $latest" }
$log = Get-Content -LiteralPath (Join-Path $data 'logs/spellbook.log') -Raw
if ($log -notmatch 'Smoke run: window painted, closing' -or $log -notmatch 'exiting') { throw 'Extracted app did not record a complete smoke run' }
@{ version = $version; archive = $zip; sha256 = $expectedSum.Split(' ')[0]; schema = [int]$schema; smokeExit = 0; extracted = $extracted } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $probe 'receipt.json')
Write-Host "package probes: PASS (fixture failures, checksum, complete payload, notices, extracted smoke, schema $schema); $probe" -ForegroundColor Green
