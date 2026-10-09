param($Session, [string]$OutputDirectory, [string]$ExpectedTitle='Spellbook')
$root=[Windows.Automation.AutomationElement]::FromHandle($Session.Window)
if ($root.Current.Name -cne $ExpectedTitle) { throw "Window title mismatch: expected '$ExpectedTitle', observed '$($root.Current.Name)'" }
$heading=Get-Element -Session $Session -AutomationId 'empty-heading'
if ($heading.Current.Name -cne 'Your grimoire is ready') { throw "Unexpected empty heading: $($heading.Current.Name)" }
$deadline=[DateTime]::UtcNow.AddSeconds(5)
do {
    $themeLines=@(Read-Log $Session -Contains 'UI appearance: theme=')
    if ($themeLines.Count) { break }
    Start-Sleep -Milliseconds 100
} while ([DateTime]::UtcNow -lt $deadline)
if (-not $themeLines.Count -or $themeLines[-1] -notmatch 'theme=(light|dark)\s*$') { throw 'Actual XAML theme evidence is missing' }
$theme=$Matches[1]
$db=Join-Path $Session.DataDir 'spellbook.db'
$schemaJson=& python "$PSScriptRoot/../dbread.py" $db 'PRAGMA user_version'
if ($LASTEXITCODE -ne 0) { throw 'Read-only schema query failed' }
$schema=$schemaJson | ConvertFrom-Json
$migrations=@(Get-ChildItem "$PSScriptRoot/../../../migrations" -Filter '*.sql' | Sort-Object Name)
$expectedSchema=[int]($migrations[-1].BaseName.Split('_')[0])
if ($schema.rows[0][0] -ne $expectedSchema) { throw "Wrong schema: $($schema.rows[0][0]), expected $expectedSchema" }
$receipt=Save-Capture -Session $Session -Path (Join-Path $OutputDirectory 'capture.png') -Anchor $heading -Theme $theme
$afterTheme=@(Read-Log $Session -Contains 'UI appearance: theme=')
if ($afterTheme.Count -ne $themeLines.Count -or $afterTheme[-1] -cne $themeLines[-1]) { throw 'XAML theme changed during capture' }
if (@(Read-Log $Session -Contains ' starting').Count -ne 1) { throw 'Expected one startup log entry' }
[pscustomobject]@{ Assertions=@('owned window title', 'empty-heading AutomationId and accessible text', 'latest database schema', 'one startup log entry', 'actual XAML theme', 'nonblank text anchor capture');
    Schema=$expectedSchema; Capture=$receipt }
