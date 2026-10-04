<#
.SYNOPSIS
  Cuts a release: moves the CHANGELOG's Unreleased notes under the version, commits, and tags v<version>.
.DESCRIPTION
  The version is never typed into a project file: it comes from the tag this
  script creates (cmake/SpellbookVersion.cmake). Steps:
    1. Refuse unless the work tree is clean, on main, and -Version is SemVer
       greater than the latest v* tag.
    2. Refuse unless CHANGELOG.md has entries under "## [Unreleased]".
    3. Run scripts/check-all.ps1 (skip with -SkipChecks only for a dry run).
    4. Rename "## [Unreleased]" to "## [v<version>] - <today>" and open a fresh
       empty Unreleased section above it.
    5. Commit "release: v<version>" and create the annotated tag v<version>.
  Nothing is pushed: the script prints the push command. Pushing the tag runs
  .github/workflows/release.yml. -DryRun prints what would change and stops
  before step 4.
  Stub status: steps 1 to 5 work; the release checklist in standards/release.md
  (installer smoke on a clean machine) is still manual until M5.
.PARAMETER Version
  The new version, MAJOR.MINOR.PATCH or with a prerelease (0.1.0-beta.1).
.PARAMETER DryRun
  Check everything and show the plan; change nothing.
.PARAMETER SkipChecks
  Skip scripts/check-all.ps1 (only allowed with -DryRun).
.PARAMETER Help
  Show this help.
.EXAMPLE
  pwsh scripts/release.ps1 -Version 0.1.0 -DryRun
  pwsh scripts/release.ps1 -Version 0.1.0
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Version,
    [switch]$DryRun,
    [switch]$SkipChecks,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"
if ($Help -or -not $Version) { Show-ScriptHelp $PSCommandPath; exit ($Help ? 0 : 1) }

if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)(-[0-9A-Za-z.]+)?$') { throw "'$Version' is not SemVer (MAJOR.MINOR.PATCH[-pre])" }
if ($SkipChecks -and -not $DryRun) { throw '-SkipChecks is allowed only with -DryRun' }
$tag = "v$Version"

Push-Location $RepoRoot
try {
    if ((& git status --porcelain) -ne $null) { throw 'the work tree is not clean; commit or stash first' }
    $branch = (& git rev-parse --abbrev-ref HEAD).Trim()
    if ($branch -ne 'main') { throw "releases are cut from main, not '$branch'" }
    if (& git tag --list $tag) { throw "tag $tag already exists" }

    $latest = (& git describe --tags --match 'v[0-9]*' --abbrev=0 2>$null)
    if ($latest) {
        $prev = [version](($latest.TrimStart('v') -split '-')[0])
        $next = [version](($Version -split '-')[0])
        if ($next -lt $prev) { throw "$tag is older than the latest tag $latest" }
    }

    $changelog = Join-Path $RepoRoot 'CHANGELOG.md'
    $lines = Get-Content $changelog
    $start = [Array]::IndexOf($lines, '## [Unreleased]')
    if ($start -lt 0) { throw 'CHANGELOG.md has no "## [Unreleased]" heading' }
    $end = $lines.Count
    for ($i = $start + 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^## ') { $end = $i; break } }
    $notes = @($lines[($start + 1)..($end - 1)] | Where-Object { $_ -match '^\s*[-*] ' })
    if ($notes.Count -eq 0) { throw 'CHANGELOG.md has no entries under [Unreleased]; nothing to release' }

    Write-Step "release $tag ($($notes.Count) changelog entries)"
    if (-not $SkipChecks) { & "$PSScriptRoot/check-all.ps1"; if ($LASTEXITCODE -ne 0) { throw 'check-all failed' } }
    if ($DryRun) { Write-Host "release.ps1: dry run OK; would commit 'release: $tag' and tag $tag" -ForegroundColor Green; exit 0 }

    $today = (Get-Date).ToString('yyyy-MM-dd')
    $updated = @($lines[0..($start - 1)]) + @('## [Unreleased]', '', "## [$tag] - $today") + @($lines[($start + 1)..($lines.Count - 1)])
    Set-Content -Path $changelog -Value $updated -Encoding utf8NoBOM
    Invoke-Native git add CHANGELOG.md
    Invoke-Native git commit -m "release: $tag"
    Invoke-Native git tag -a $tag -m "Spellbook $Version"
    Write-Host "release.ps1: tagged $tag. Push with: git push origin main $tag" -ForegroundColor Green
} finally {
    Pop-Location
}
