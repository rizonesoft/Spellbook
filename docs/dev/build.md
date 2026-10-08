# Building Spellbook

How to set up a machine, build, test, run, and troubleshoot. The day-to-day commands are in the README; this page has the detail.

## What is installed where

| Component | Where it comes from | Where it lives |
| --------- | ------------------- | -------------- |
| MSVC v145, WinUI C++ tools, and the Windows SDK | Visual Studio 2026 with Desktop development with C++ and `Microsoft.VisualStudio.Component.WindowsAppSdkSupport.Cpp` (machine-wide) | `Program Files` |
| PowerShell 7, Git, Python 3 | Installed by you (machine-wide) | PATH |
| CMake 4.4.4, Ninja 1.13.2, clang-format 23.1.2, clang-tidy 22.1.8, actionlint 1.7.12 | `toolchain.json`: URL and SHA-256, downloaded by `scripts/setup.ps1` | `.tools/<name>/` (gitignored) |
| vcpkg | `toolchain.json`: cloned at the pinned commit and bootstrapped | `.tools/vcpkg/` |
| NuGet 7.9.0 | Versioned Microsoft download, SHA-256 pinned in `toolchain.json` | `.tools/nuget/nuget.exe` |
| Windows App SDK 2.5.1 and C++/WinRT 3.0.260818.1 | Version/source/date pins in `toolchain.json`; consumed by the planned WinUI project in D00 T02 §3 | App package restore when the hybrid shell ships |
| sqlite3, spdlog, fmt, nlohmann-json, Catch2 | `vcpkg.json` (manifest mode), built on the first configure | `artifacts/vcpkg_installed/`, cached in `.tools/vcpkg-cache/` |

Nothing from `.tools/` is ever replaced by a tool found on PATH: two machines must produce the same configure and format results.

## First-time setup

```powershell
pwsh scripts/setup.ps1            # repairs every failing leg, then verifies
pwsh scripts/setup.ps1 -Verify    # checks only; exit 0 when all legs are green
```

Legs: `msvc`, each tool in `toolchain.json`, `vcpkg`, `hooks` (sets `git config core.hooksPath tools/githooks`), and `python`. MSVC selection requires VS 2026, a usable default v145 compiler (14.50 or later), and the WinUI C++ component. If a component is missing, setup prints the Visual Studio Installer modify command for the operator; it does not install machine-wide tools. The legacy `-InstallMsvc` switch only prints these instructions. `-Verify` also includes the component names and repair guidance on failure.

When moving an existing build tree from VS 2022 to VS 2026, run `pwsh scripts/build.ps1 -Config Debug -Clean` and `pwsh scripts/build.ps1 -Config Release -Clean` once so CMake redetects the compiler. The app is still the Win32 bootstrap until D00 T02 §3; these toolchain pins do not claim that the hybrid app already exists.

## Build, test, run

```powershell
pwsh scripts/build.ps1 -Config Debug        # or Release, RelWithDebInfo; -Clean to start over
pwsh scripts/test.ps1 -Config Debug         # builds first; -NoBuild to skip; -Filter "core:"
pwsh scripts/run.ps1                         # builds if needed and launches
pwsh scripts/run.ps1 -Smoke                  # unattended: start, migrate, paint, exit 0
pwsh scripts/run.ps1 -DataDir build/try     # use a throwaway data folder
```

The scripts enter the MSVC x64 developer environment themselves (through `vswhere` and `vcvars64.bat`), so they work from any PowerShell, not only a Developer prompt. The first configure builds the vcpkg ports (several minutes); afterwards configure takes seconds.

Output lands under `artifacts/build/<preset>/`: `bin/Spellbook.exe`, the test executables, and `compile_commands.json` for clang-tidy and editors.

### Visual Studio and VS Code

Open the folder in Visual Studio 2026 or VS Code with the CMake Tools extension: both read `CMakePresets.json`. Run `pwsh scripts/setup.ps1` first and set `VCPKG_ROOT` to `<repo>\.tools\vcpkg` in the environment the IDE starts from, since the presets read it.

## The gates

```powershell
pwsh scripts/check-all.ps1     # everything CI runs
pwsh scripts/format.ps1 -Check # clang-format
pwsh scripts/lint.ps1          # clang-tidy and the layering check
```

`check-all.ps1` runs: the toolchain check, the layering self-test and check, the format check, Debug and Release builds, Debug and Release tests, the Release launch smoke, clang-tidy, actionlint, the docs check, the three TODO-graph gates, and the run guard probe (`scripts/check-campaign-stop.ps1`). Every gate runs even after a failure, and a table at the end shows each result.

## The dev database

```powershell
pwsh scripts/migrate.ps1 -Reset    # a fresh build/dev-data/spellbook.db at the latest schema
pwsh scripts/migrate.ps1           # upgrade it in place
```

It prints `PRAGMA user_version` and the tables. It refuses to `-Reset` your real `%LOCALAPPDATA%\Spellbook`.

## Packaging

```powershell
pwsh scripts/package.ps1           # Release build, then artifacts/dist/*-Portable.zip and SHA256SUMS
```

The installer (`-Installer`) arrives in M5. Releases are cut with `scripts/release.ps1`; see `standards/release.md` and the `release` skill.

## CI

`.github/workflows/ci.yml` runs on every push and pull request to `main`: a Windows job that calls the same scripts (setup, format check, layering, actionlint, Debug and Release builds and tests, the smoke) with `.tools/` and the vcpkg binary cache restored from the Actions cache, and a Linux job for the TODO and docs gates and the hook mode check. `.github/workflows/release.yml` runs on a `v*` tag.

## Troubleshooting

| Problem | Fix |
| ------- | --- |
| `<tool> is not provisioned at .tools\...` | `pwsh scripts/setup.ps1` |
| `No Visual Studio 2026 with C++ x64 and WindowsAppSdkSupport.Cpp found` | Add Desktop development with C++ and the WinUI C++ component using the VS Installer command printed by setup |
| Configure fails inside `vcpkg install` | read `artifacts/build/<preset>/vcpkg-manifest-install.log`; check that `vcpkg.json`'s `builtin-baseline` equals `toolchain.json`'s vcpkg commit (`setup.ps1 -Verify` checks it) |
| A stale configure after changing presets or tags | `pwsh scripts/build.ps1 -Clean` |
| The version still says `0.0.0-alpha.N` after tagging | the version is read at configure time: `-Clean` and rebuild |
| `format.ps1 -Check` fails only in CI | a file has CRLF and LF mixed, or was formatted by another clang-format; run `pwsh scripts/format.ps1` with the pinned binary |
| The smoke fails | read `build/smoke/<preset>/logs/spellbook.log`; the `[critical]` line names the failure |
