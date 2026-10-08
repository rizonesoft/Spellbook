---
name: build-and-test
description: Configure, build, test, and smoke-run Spellbook through the repo runners, and read a failure to its cause. Use whenever code changed, a gate went red, CI failed, or someone asks how to build or run the tests.
---

# Build and Test

Every build goes through `scripts/*.ps1`, never a hand-typed `cmake` or `cl` line: the runners enter the MSVC environment, put the pinned tools from `.tools/` first on PATH, and point CMake at the pinned vcpkg. A hand-typed command can pick up another CMake or clang-format and produce a result nobody else can reproduce.

## The commands

```powershell
pwsh scripts/setup.ps1 -Verify            # 1. toolchain present? (no -Verify repairs it)
pwsh scripts/build.ps1 -Config Debug      # 2. configure if needed, then build
pwsh scripts/test.ps1 -Config Debug       # 3. build, then ctest; -Filter "storage: .*migrate"
pwsh scripts/run.ps1 -Smoke               # 4. start, migrate, paint, exit 0, in build/smoke/
pwsh scripts/check-all.ps1                # 5. everything CI runs, in one command
```

Configs: `Debug`, `Release`, `RelWithDebInfo`. Output: `artifacts/build/<preset>/bin/` (`Spellbook.exe`, `spellbook_core_tests.exe`, `spellbook_storage_tests.exe`). `-Clean` deletes the preset folder; the vcpkg binary cache in `.tools/vcpkg-cache` survives it, so a clean rebuild does not rebuild the dependencies.

The first configure on a machine builds the five vcpkg ports and takes several minutes. Later configures take seconds.

## Bound the output

```powershell
pwsh scripts/build.ps1 *>&1 | Out-File build/build.log; Select-String -Path build/build.log -Pattern 'error|warning' | Select-Object -First 20
pwsh scripts/test.ps1 -NoBuild 2>&1 | Select-Object -Last 15
```

Keep full logs under `build/` (ignored). Quote the lines that matter, never the whole log.

## Reading failures

| Symptom | Where to look | Usual cause |
| ------- | ------------- | ----------- |
| `setup: N leg(s) failed` | the leg name and its detail line | a tool missing or the wrong version; rerun `pwsh scripts/setup.ps1` without `-Verify` |
| `No Visual Studio 2026 with C++ x64 and WindowsAppSdkSupport.Cpp found` | `setup.ps1` msvc leg | operator action: add the VS 2026 C++ workload and `WindowsAppSdkSupport.Cpp` using setup's printed VS Installer command |
| configure fails in `vcpkg install` | `artifacts/build/<preset>/vcpkg-manifest-install.log` | a port failed to build, or `builtin-baseline` and `toolchain.json` disagree |
| `spellbook_set_warnings() was never called for: X` | the configure output | a new target without the warning policy: add `spellbook_set_warnings(X)` |
| `error C2220` / `warning treated as error` | the first `warning Cxxxx` above it | fix the warning; never lower `/W4` or drop `/WX` |
| `Migration 'x.sql' breaks the sequence` | `cmake/EmbedMigrations.cmake` | a gap or a misnamed file in `migrations/` |
| a test fails | CTest prints the Catch2 output (`outputOnFailure`) | read the expansion line: Catch2 shows both sides of a failed `CHECK` |
| smoke fails | `build/smoke/<preset>/logs/spellbook.log` | the last `[critical]` line names the failure |
| `format.ps1: N file(s) need formatting` | the listed files | run `pwsh scripts/format.ps1` and commit the result |

Run one Catch2 case directly when CTest is not enough:

```powershell
artifacts/build/debug/bin/spellbook_storage_tests.exe "migrate refuses a database newer than this build" -s
```

## Rules

- A red gate is fixed, not skipped. Never comment out a test, add a warning suppression without a recorded reason, or pass `-SkipLint` to make check-all green.
- Quote the command and its result in the section's stamp.
