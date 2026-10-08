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
| Windows App SDK 2.5.1 and C++/WinRT 3.0.260818.1 | Version/source/date pins in `toolchain.json`; consumed by `src/app/Spellbook.vcxproj` | Restored by the hybrid build into `artifacts/nuget/` |
| sqlite3, spdlog, fmt, nlohmann-json, Catch2 | `vcpkg.json` (manifest mode), built on the first configure | `artifacts/vcpkg_installed/`, cached in `.tools/vcpkg-cache/` |

Nothing from `.tools/` is ever replaced by a tool found on PATH: two machines must produce the same configure and format results.

## First-time setup

```powershell
pwsh scripts/setup.ps1            # repairs every failing leg, then verifies
pwsh scripts/setup.ps1 -Verify    # checks only; exit 0 when all legs are green
```

Legs: `msvc`, each tool in `toolchain.json`, `vcpkg`, `hooks` (sets `git config core.hooksPath tools/githooks`), and `python`. MSVC selection requires VS 2026, a usable default v145 compiler (14.50 or later), and the WinUI C++ component. If a component is missing, setup prints the Visual Studio Installer modify command for the operator; it does not install machine-wide tools. The legacy `-InstallMsvc` switch only prints these instructions. `-Verify` also includes the component names and repair guidance on failure.

GitHub-hosted CI and release jobs first run `scripts/setup-ci.ps1`. It adds a missing WinUI C++ component to the existing VS 2026 C++ installation on the disposable VM, then repeats component discovery. It refuses local and self-hosted execution. Installer exits other than 0 or 3010 fail; both accepted codes still require successful discovery and the normal setup/build checks. Local setup remains operator-owned. The installer uses the [documented modify command](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio), with PowerShell waiting for completion.

When moving an existing build tree from VS 2022 to VS 2026, run `pwsh scripts/build.ps1 -Config Debug -Clean` and `pwsh scripts/build.ps1 -Config Release -Clean` once so CMake redetects the compiler. The runner builds the libraries and tests with CMake/Ninja, then restores and builds the WinUI project with MSBuild. The project opts into native C++ PackageReference support and requires VS 2026 18.7 or newer.

## Build, test, run

```powershell
pwsh scripts/build.ps1 -Config Debug        # or Release, RelWithDebInfo; -Clean to start over
pwsh scripts/test.ps1 -Config Debug         # builds first; -NoBuild to skip; -Filter "core:"
pwsh scripts/run.ps1                         # builds if needed and launches
pwsh scripts/run.ps1 -Smoke                  # unattended: start, migrate, paint, exit 0
pwsh scripts/run.ps1 -DataDir build/try     # use a throwaway data folder
```

The scripts enter the MSVC x64 developer environment themselves (through `vswhere` and `vcvars64.bat`), so they work from any PowerShell, not only a Developer prompt. The first configure builds the vcpkg ports (several minutes); afterwards configure takes seconds.

Output lands under `artifacts/build/<preset>/`: `app/Spellbook.exe` with its complete runtime/resource payload, test executables under `bin/`, and `compile_commands.json` for library clang-tidy and editors. Copy the entire `app/` folder to deploy the shell; the executable alone is insufficient. Package pins and version resources are generated from `toolchain.json` and git tags when the runner configures CMake.

### Visual Studio and VS Code

Open the folder in Visual Studio 2026 or VS Code with the CMake Tools extension: both read `CMakePresets.json`. Run `pwsh scripts/setup.ps1` first and set `VCPKG_ROOT` to `<repo>\.tools\vcpkg` in the environment the IDE starts from, since the presets read it.

## The gates

```powershell
pwsh scripts/check-all.ps1     # everything CI runs
pwsh scripts/format.ps1 -Check # clang-format
pwsh scripts/lint.ps1          # library clang-tidy, MSVC app analysis, layering
```

`check-all.ps1` runs: the toolchain checks and rejection probes, the layering self-test and check, the format check, Debug and Release hybrid builds, Debug and Release tests, the Release launch smoke and startup failure probes, library clang-tidy, MSVC app analysis, actionlint, the docs and TODO-graph gates, and the workflow/guard probes. Every gate runs even after a failure, and a table at the end shows each result. MSVC analysis retains `/W4 /WX` on app sources and excludes external headers with `/analyze:external-`.

`scripts/test-self-contained-ci.ps1` is an additional hosted-only proof. It refuses local and self-hosted execution before changes, removes registered Windows App Runtime packages only from the disposable runner user, extracts the checksum-verified portable ZIP outside the checkout, checks the visible window and app-local runtime modules, captures its DPI and screenshot, and runs smoke. Evidence is uploaded from `build/self-contained-proof/`; it never removes runtime packages from a developer machine.

The startup probes also read and dismiss their own interactive error dialogs through `scripts/test_startup_dialogs.py`. Corrupt-data and invalid-argument cases must name the failed startup and return 1; an isolated copy without its PRI must retain the startup context and return nonzero (WinUI may use a native failure status for invalid XAML resources). No real library or installed app files are changed.

## The dev database

```powershell
pwsh scripts/migrate.ps1 -Reset    # a fresh build/dev-data/spellbook.db at the latest schema
pwsh scripts/migrate.ps1           # upgrade it in place
```

It prints `PRAGMA user_version` and the tables. It refuses to `-Reset` your real `%LOCALAPPDATA%\Spellbook`.

## Packaging

```powershell
pwsh scripts/package.ps1           # Release build, then artifacts/dist/*-portable.zip and SHA256SUMS
```

Packaging prepares both outputs before publication and restores the previous archive if replacing `SHA256SUMS` fails. If restoration also fails, the error names retained recovery files under `artifacts/stage/package-*/`; preserve that directory and repair the ZIP/checksum pair before distributing it. Two file replacements do not provide power-loss atomicity.

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

### Hybrid runner and package proofs

The static MSBuild coverage gate requires unconditional owned-source declarations in the project. Conditional items/groups, dynamic target additions, exclusions, removals, updates, and `ExcludedFromBuild` metadata are rejected rather than credited as compiled sources. Extend the gate with evaluated-configuration proof before introducing such declarations.

The root `Spellbook.slnx` opens the WinUI MSBuild project; the PowerShell build runner first prepares its CMake libraries and generated package/version properties. The project-source coverage gate rejects an owned app `.cpp` absent from the MSBuild target, unresolved source paths, and lower-layer references to app headers.

`pwsh scripts/test-build-warning.ps1` creates an isolated candidate checkout under `build/warning-probes/`, injects C4996 in its copy of `MainWindow.xaml.cpp`, and requires the Release runner to reject it. The original worktree is unchanged. The probe uses a junction to the existing pinned `.tools` and retains its clone/logs as evidence; it never commits or pushes.

`pwsh scripts/test-package.ps1` packages the existing Release build, verifies the ZIP checksum and complete payload, extracts it under `build/package-probes/`, smoke-runs that copy against isolated data, and reads the schema back. Nine disposable package fixtures also test missing runtime files, missing vendor terms, stale restore pins, unsafe paths, checksum publication failures, and rollback recovery. This probe runs in the full suite, CI, and the release packaging job. The executable's product version must match the generated package version, including with `-SkipBuild`.

The packager takes vendor terms from the resolved `artifacts/nuget-obj/project.assets.json` dependency closure and vcpkg copyright files. It requires the Windows App SDK license/NOTICE and C++/WinRT MIT license, preserves their contents, and explains that Spellbook's license does not relicense bundled components. Required-file failures leave an existing ZIP/checksum untouched. Both workflows cache `artifacts/nuget` using the package pins and project inputs; restored packages still pass normal NuGet restore and build checks.
