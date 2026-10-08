# Shared helpers for scripts/*.ps1. Dot-source it: . "$PSScriptRoot/_common.ps1"
# Shape copied from Isotone's scripts/_common.ps1 (Write-Step, Invoke-Native);
# the toolchain resolution follows Resolute's toolchain.json pins.
Set-StrictMode -Version Latest

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:ToolsDir = Join-Path $script:RepoRoot '.tools'
$script:Toolchain = Get-Content (Join-Path $script:RepoRoot 'toolchain.json') -Raw | ConvertFrom-Json
$script:Presets = @{ Debug = 'debug'; Release = 'release'; RelWithDebInfo = 'relwithdebinfo' }

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-Native {
    # Runs a native command and throws on a non-zero exit code. Deliberately a
    # simple function (no param block) so flags like -o reach the command as-is.
    # $rest is forced to an array: Isotone's `$file, $rest = $args` leaves a lone
    # argument as a string, and splatting a string passes it one character at a time.
    $file = $args[0]
    $rest = @($args | Select-Object -Skip 1)
    & $file @rest
    if ($LASTEXITCODE -ne 0) { throw "$file $($rest -join ' ') failed with exit code $LASTEXITCODE" }
}

function Show-ScriptHelp([string]$Path) {
    # Every runner takes -Help; the text is the script's comment-based help. The <# #> block
    # must be the first thing in the file: PowerShell 7.6's Get-Help ignores it after #Requires.
    Get-Help $Path -Detailed | Out-String | Write-Host
}

function Get-Component([string]$Name) {
    $c = $script:Toolchain.components | Where-Object { $_.name -eq $Name }
    if (-not $c) { throw "toolchain.json has no component '$Name'" }
    return $c
}

function Get-ToolPath([string]$Name) {
    # The repo copy under .tools/ is the only accepted one: a tool on PATH may be
    # another version, and formatting or configure results would then differ by machine.
    $c = Get-Component $Name
    $path = Join-Path (Join-Path $script:ToolsDir $c.dir) $c.probe
    if (-not (Test-Path $path)) {
        throw "$Name $($c.version) is not provisioned at $path. Run: pwsh scripts/setup.ps1"
    }
    return $path
}

function Get-VcpkgRoot {
    $root = Join-Path $script:ToolsDir $script:Toolchain.vcpkg.dir
    if (-not (Test-Path (Join-Path $root 'vcpkg.exe'))) {
        throw "vcpkg is not bootstrapped at $root. Run: pwsh scripts/setup.ps1"
    }
    return $root
}

function Find-VisualStudio {
    # Returns the installation path of a Visual Studio (or Build Tools) with the
    # required C++ and WinUI components in the pinned VS 2026 version range.
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) { return $null }
    $m = $script:Toolchain.msvc
    $path = & $vswhere -products * -requires $m.requires -version $m.vswhereVersionRange -latest -property installationPath
    if (-not $path -and $m.fallbackToLatest) {
        $path = & $vswhere -products * -requires $m.requires -latest -property installationPath
    }
    if ($path) { return ($path | Select-Object -First 1).Trim() }
    return $null
}

function Get-MsvcVersion([string]$VisualStudio) {
    $defaultFile = Join-Path $VisualStudio 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt'
    if (-not (Test-Path -LiteralPath $defaultFile)) { return $null }
    $versionText = (Get-Content -LiteralPath $defaultFile -Raw).Trim()
    $version = $null
    if (-not [version]::TryParse($versionText, [ref]$version)) { return $null }
    $compiler = Join-Path $VisualStudio "VC/Tools/MSVC/$versionText/bin/Hostx64/x64/cl.exe"
    if (-not (Test-Path -LiteralPath $compiler)) { return $null }
    return $version
}

function Enter-DevEnvironment {
    # Imports the MSVC x64 developer environment into this PowerShell process,
    # then puts the pinned tools first on PATH and points VCPKG_ROOT at the repo copy.
    # Idempotent within a process.
    $vs = Find-VisualStudio
    if (-not $vs) {
        throw 'No Visual Studio 2026 with C++ x64 and WindowsAppSdkSupport.Cpp found. Run: pwsh scripts/setup.ps1'
    }
    $version = Get-MsvcVersion $vs
    if (-not $version -or $version -lt [version]$script:Toolchain.msvc.minimumToolsetVersion) {
        throw "Visual Studio at $vs requires MSVC $($script:Toolchain.msvc.minimumToolsetVersion) or later (v145)."
    }
    # An inherited marker from another VS installation cannot bypass selection.
    if ($env:SPELLBOOK_DEVENV -eq '1' -and $env:VSINSTALLDIR -and
        $env:VSINSTALLDIR.TrimEnd('\') -eq $vs.TrimEnd('\') -and
        $env:VCToolsVersion -and $env:VCToolsVersion.TrimEnd('\') -eq $version.ToString()) { return }
    $vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path $vcvars)) { throw "vcvars64.bat not found under $vs" }
    $lines = & cmd.exe /d /c "`"$vcvars`" >nul 2>&1 && set"
    if ($LASTEXITCODE -ne 0) { throw "vcvars64.bat failed ($LASTEXITCODE)" }
    foreach ($line in $lines) {
        $i = $line.IndexOf('=')
        if ($i -gt 0) { [Environment]::SetEnvironmentVariable($line.Substring(0, $i), $line.Substring($i + 1)) }
    }
    if (-not $env:VCToolsVersion -or
        [version]$env:VCToolsVersion.TrimEnd('\') -lt [version]$script:Toolchain.msvc.minimumToolsetVersion) {
        throw "vcvars64.bat did not select the required v145 toolset under $vs"
    }
    $pinned = @(
        (Split-Path -Parent (Get-ToolPath 'cmake')),
        (Split-Path -Parent (Get-ToolPath 'ninja'))
    )
    $env:PATH = ($pinned -join ';') + ';' + $env:PATH
    $env:VCPKG_ROOT = Get-VcpkgRoot
    # vcpkg binary cache outside the build tree, so -Clean keeps built packages.
    if (-not $env:VCPKG_DEFAULT_BINARY_CACHE) {
        $cache = Join-Path $script:ToolsDir 'vcpkg-cache'
        New-Item -ItemType Directory -Force -Path $cache | Out-Null
        $env:VCPKG_DEFAULT_BINARY_CACHE = $cache
    }
    $env:SPELLBOOK_DEVENV = '1'
}

function Get-BuildDir([string]$Config) {
    return Join-Path $script:RepoRoot "artifacts/build/$($script:Presets[$Config])"
}

function Get-ExePath([string]$Config) {
    return Join-Path (Get-BuildDir $Config) 'bin/Spellbook.exe'
}

function Get-CppSources {
    # Every C++ source the project owns (never vcpkg or build output).
    $roots = @('src', 'tests') | ForEach-Object { Join-Path $script:RepoRoot $_ }
    return @(Get-ChildItem -Path $roots -Recurse -File -Include *.cpp, *.hpp, *.h |
        Where-Object { $_.FullName -notmatch '[\\/](artifacts|build)[\\/]' } |
        ForEach-Object FullName)
}
