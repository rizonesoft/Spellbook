<#
.SYNOPSIS
  Exercises toolchain rejection and provisioning with disposable fixtures.
#>
#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"

# Load only the setup functions, without running its repair entrypoint.
$tokens = $null
$parseErrors = $null
$setupAst = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PSScriptRoot 'setup.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'setup.ps1 has syntax errors' }
foreach ($name in @('Install-Component', 'Test-MsvcLeg', 'Get-MsvcInstallHelp')) {
    $definition = $setupAst.Find({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true)
    if (-not $definition) { throw "Missing setup function: $name" }
    . ([scriptblock]::Create($definition.Extent.Text))
}

$fixtureRoot = Join-Path $RepoRoot "build/toolchain-tests/$([Guid]::NewGuid().ToString('N'))"
$fixtureRoot = [IO.Path]::GetFullPath($fixtureRoot)
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $RepoRoot 'build/toolchain-tests')) + [IO.Path]::DirectorySeparatorChar
if (-not $fixtureRoot.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test fixture path' }
$originalFinder = ${function:Find-VisualStudio}
$originalToolsDir = $script:ToolsDir
$originalRange = $Toolchain.msvc.vswhereVersionRange
$originalFallback = $Toolchain.msvc.fallbackToLatest
$passed = 0
function Assert-Check([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:passed++
    Write-Host "PASS: $Name"
}
try {
    New-Item -ItemType Directory -Force -Path $fixtureRoot | Out-Null
    $script:TestVsPath = Join-Path $fixtureRoot 'vs'
    function Find-VisualStudio { return $script:TestVsPath }
    $defaultFile = Join-Path $script:TestVsPath 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt'
    New-Item -ItemType Directory -Force -Path (Split-Path $defaultFile) | Out-Null
    Set-Content -LiteralPath $defaultFile -Value '14.44.35207'
    $compiler = Join-Path $script:TestVsPath 'VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe'
    New-Item -ItemType Directory -Force -Path (Split-Path $compiler) | Out-Null
    Set-Content -LiteralPath $compiler -Value 'fixture, never executed'
    $result = Test-MsvcLeg
    Assert-Check (-not $result.Ok -and $result.Detail -match 'v145') 'old compiler is rejected even when discovery returns an installation'
    Set-Content -LiteralPath $defaultFile -Value '14.51.36231'
    Assert-Check ($null -eq (Get-MsvcVersion $script:TestVsPath)) 'missing compiler binary is rejected'
    Set-Content -LiteralPath $defaultFile -Value 'invalid'
    Assert-Check ($null -eq (Get-MsvcVersion $script:TestVsPath)) 'malformed default toolset is rejected'
    $script:TestVsPath = $null
    $result = Test-MsvcLeg
    Assert-Check (-not $result.Ok -and $result.Detail -match 'WindowsAppSdkSupport.Cpp') 'missing WinUI discovery names the required component'
    Assert-Check ($result.Detail -match 'modify --installPath' -or $result.Detail -match 'Install Visual Studio 2026') 'missing components provide operator installation guidance'

    ${function:Find-VisualStudio} = $originalFinder
    $Toolchain.msvc.vswhereVersionRange = '[17.0,18.0)'
    $Toolchain.msvc.fallbackToLatest = $false
    $result = Test-MsvcLeg
    Assert-Check (-not $result.Ok) 'VS 2022-only pin is rejected without fallback'
    $Toolchain.msvc.vswhereVersionRange = $originalRange
    $Toolchain.msvc.fallbackToLatest = $originalFallback

    $script:ToolsDir = Join-Path $fixtureRoot '.tools'
    $payload = Join-Path $fixtureRoot 'payload.exe'
    Set-Content -LiteralPath $payload -Value 'fixture tool payload'
    function Invoke-WebRequest { param($Uri, $OutFile, [switch]$UseBasicParsing)
        Copy-Item -LiteralPath $payload -Destination $OutFile
    }
    $component = [pscustomobject]@{
        name = 'fixture'; version = '1'; dir = 'fixture'; url = 'https://fixture.invalid/tool.exe'
        sha256 = (Get-FileHash $payload -Algorithm SHA256).Hash.ToLowerInvariant()
        archiveType = 'file'; stripRoot = $false; probe = 'tool.exe'
    }
    Install-Component $component
    $installed = Join-Path $ToolsDir 'fixture/tool.exe'
    Assert-Check ((Get-FileHash $installed).Hash -eq (Get-FileHash $payload).Hash) 'raw executable provisioning preserves exact bytes'
    $component.sha256 = '0' * 64
    $rejected = $false
    try { Install-Component $component } catch { $rejected = $_.Exception.Message -match 'SHA-256' }
    Assert-Check ($rejected -and (Get-FileHash $installed).Hash -eq (Get-FileHash $payload).Hash) 'hash mismatch refuses replacement and preserves the installed tool'
    $component.dir = '../escape'
    $rejected = $false
    try { Install-Component $component } catch { $rejected = $_.Exception.Message -match 'escapes .tools' }
    Assert-Check $rejected 'tool destination cannot escape .tools'
    Assert-Check (@(Get-ChildItem -LiteralPath $ToolsDir -Directory -Filter '.download-*').Count -eq 0) 'temporary download directories are removed after success and failure'
    Write-Host "toolchain tests: $passed passed"
} finally {
    ${function:Find-VisualStudio} = $originalFinder
    $script:ToolsDir = $originalToolsDir
    $Toolchain.msvc.vswhereVersionRange = $originalRange
    $Toolchain.msvc.fallbackToLatest = $originalFallback
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
