<#
.SYNOPSIS
  Adds missing WinUI C++ tools only on disposable GitHub-hosted Windows runners.
#>
#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"

function Find-CiBaseVisualStudio {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) { return $null }
    return & $vswhere -products * -version $Toolchain.msvc.vswhereVersionRange -latest `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
}

function Invoke-CiVsInstaller([string]$Installation) {
    $installer = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/setup.exe'
    if (-not (Test-Path -LiteralPath $installer)) { throw 'VS Installer is missing from the runner image.' }
    # setup.exe does not support --wait; Start-Process waits for the process tree.
    $arguments = @('modify', '--installPath', "`"$Installation`"", '--add',
        'Microsoft.VisualStudio.Component.WindowsAppSdkSupport.Cpp', '--quiet', '--norestart')
    $process = Start-Process -FilePath $installer -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    return $process.ExitCode
}

function Initialize-CiMsvc {
    if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
        throw 'setup-ci is restricted to disposable GitHub-hosted runners; local and self-hosted setup is operator-owned.'
    }
    if (Find-VisualStudio) {
        Write-Host 'setup-ci: VS 2026 WinUI C++ component already present'
        return
    }
    $installation = Find-CiBaseVisualStudio
    if (-not $installation) { throw 'Runner image lacks an existing VS 2026 C++ installation.' }
    Write-Host "setup-ci: add WindowsAppSdkSupport.Cpp to $installation"
    $installerExit = Invoke-CiVsInstaller $installation
    if ($installerExit -notin @(0, 3010)) { throw "VS Installer failed with exit $installerExit." }
    # A successful installer return alone is not proof, including reboot-required 3010.
    if (-not (Find-VisualStudio)) { throw 'VS Installer completed but the required WinUI C++ component is still missing.' }
    Write-Host "setup-ci: WinUI C++ component verified (installer exit $installerExit)"
}

if ($MyInvocation.InvocationName -ne '.') { Initialize-CiMsvc }
