<#
.SYNOPSIS
  Tests the hosted-only provisioning guard without running an installer.
#>
#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/setup-ci.ps1"
$originalActions = $env:GITHUB_ACTIONS
$originalRunner = $env:RUNNER_ENVIRONMENT
$passed = 0
function Assert-Check([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:passed++
    Write-Host "PASS: $Name"
}
function Find-VisualStudio { if ($script:componentPresent) { return 'fixture VS 2026' } }
function Find-CiBaseVisualStudio { if ($script:basePresent) { return 'fixture VS 2026' } }
function Invoke-CiVsInstaller([string]$Installation) {
    $script:installCalls++
    if ($Installation -ne 'fixture VS 2026') { throw 'Unexpected install target' }
    $script:componentPresent = $script:installAddsComponent
    return $script:installerExit
}
function Reset-Fixture {
    $script:componentPresent = $false
    $script:basePresent = $true
    $script:installCalls = 0
    $script:installAddsComponent = $true
    $script:installerExit = 0
}
function Invoke-ExpectedFailure([string]$Pattern) {
    try { Initialize-CiMsvc } catch { return $_.Exception.Message -match $Pattern }
    return $false
}
try {
    Reset-Fixture
    $env:GITHUB_ACTIONS = $null
    $env:RUNNER_ENVIRONMENT = $null
    Assert-Check ((Invoke-ExpectedFailure 'restricted') -and $installCalls -eq 0) 'local execution is refused before installation'
    $env:GITHUB_ACTIONS = 'true'
    $env:RUNNER_ENVIRONMENT = 'self-hosted'
    Assert-Check ((Invoke-ExpectedFailure 'restricted') -and $installCalls -eq 0) 'self-hosted execution is refused before installation'
    $env:RUNNER_ENVIRONMENT = 'github-hosted'
    $script:componentPresent = $true
    Initialize-CiMsvc
    Assert-Check ($installCalls -eq 0) 'complete hosted image is left unchanged'
    Reset-Fixture
    $script:basePresent = $false
    Assert-Check ((Invoke-ExpectedFailure 'lacks an existing') -and $installCalls -eq 0) 'missing base C++ tools fail without installation'
    Reset-Fixture
    $script:installerExit = 1603
    Assert-Check ((Invoke-ExpectedFailure 'exit 1603') -and $installCalls -eq 1) 'installer failure propagates'
    Reset-Fixture
    $script:installAddsComponent = $false
    Assert-Check ((Invoke-ExpectedFailure 'still missing') -and $installCalls -eq 1) 'exit zero without component discovery fails'
    Reset-Fixture
    $script:installerExit = 3010
    $script:installAddsComponent = $false
    Assert-Check (Invoke-ExpectedFailure 'still missing') 'reboot-required exit without component discovery fails'
    Reset-Fixture
    Initialize-CiMsvc
    Assert-Check ($installCalls -eq 1 -and $componentPresent) 'successful install is verified by discovery'
    Initialize-CiMsvc
    Assert-Check ($installCalls -eq 1) 'second invocation does not reinstall'
    Reset-Fixture
    $script:installerExit = 3010
    Initialize-CiMsvc
    Assert-Check ($installCalls -eq 1 -and $componentPresent) 'reboot-required exit proceeds only after discovery'
    Write-Host "setup-ci tests: $passed passed"
} finally {
    $env:GITHUB_ACTIONS = $originalActions
    $env:RUNNER_ENVIRONMENT = $originalRunner
}
