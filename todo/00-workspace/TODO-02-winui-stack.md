---
schema_version: 1
id: workspace-winui-stack
domain: 00-workspace
status: active
title: "TODO-02 -- The WinUI 3 Stack: Visual Studio 2026, Windows App SDK, and the Hybrid Build"
depends_on: []
---

# TODO-02 -- The WinUI 3 Stack: Visual Studio 2026, Windows App SDK, and the Hybrid Build

> **Goal:** Spellbook's app layer is a WinUI 3 desktop app in C++/WinRT on the latest stable Windows App SDK, built with the Visual Studio 2026 toolset (v145). `core`, `storage`, and their tests keep building through the CMake presets with Ninja. The app is an MSBuild `.vcxproj` in `Spellbook.slnx` that links those libraries. It ships unpackaged and self-contained as a folder (portable ZIP, Inno Setup 7 later). The runners, CI, ADR, standards, skills, and every open UI section of the plan speak WinUI, and the Win32 shell from `D00 T01 §5` is gone.

> [!IMPORTANT]
> **Current state (verified 2026-10-08):** The operator chose WinUI 3 on Visual Studio 2026, a hybrid build, and unpackaged self-contained distribution on 2026-10-04. ADR 0002 now records that decision and its two provisional choices; §1 is independently verified. The executable remains the CMake-built Win32 bootstrap until §3. `toolchain.json` now requires VS 2026 (`[18.0,19.0)`, fallback disabled), MSVC 14.50+, and the C++ WinUI component. Setup verifies MSVC 14.51.36231 and the pinned NuGet 7.9.0; clean Debug and Release builds use compiler 19.51.36260. Windows App SDK 2.5.1 and C++/WinRT 3.0.260818.1 are pinned for the hybrid build. The replacement shell and hybrid runners remain open in §§3-4.

## Inputs

- [`../../docs/adr/0001-tech-stack.md`](../../docs/adr/0001-tech-stack.md) -- the decisions this file supersedes in part (UI framework, build of the app, single-file exe)
- [`../../src/app/`](../../src/app/) -- the Win32 shell whose behavior the WinUI shell must keep: title, icon, `--data-dir`, `--smoke`, logging lines, migration on start
- [`../../toolchain.json`](../../toolchain.json) and [`../../scripts/setup.ps1`](../../scripts/setup.ps1) -- the msvc leg to retarget
- Microsoft Learn: "Distribute an unpackaged WinUI 3 app" (`WindowsPackageType=None`, `AppxPackage=false`, `WindowsAppSDKSelfContained=true`, the auto-initializer)
- Microsoft Learn: "Upgrading C++ projects to Visual Studio 2026" (v145, MSVC 14.50, binary compatibility with 2015 and later)
- -> XREF: D00 T01 §10 -- CI must be green on the old stack before this file changes it
- -> XREF: D99 T01 §5 -- the operator installs the VS 2026 C++ and WinUI workloads
- -> XREF: D01 T01 §5 -- the first M1 surface, which builds on the WinUI shell from §3
- -> XREF: D05 T02 §1 -- the approved icon (`assets/spellbook.ico`), which the WinUI shell uses for the window, taskbar, and Explorer
- -> XREF: D00 T03 §4 -- the UI driver that drives the WinUI shell from §3

## Outcome

- `pwsh scripts/setup.ps1 -Verify` reports Visual Studio 2026 with the v145 toolset and the Windows App SDK C++ tools, and the pinned Windows App SDK 2.5.1 and C++/WinRT packages.
- `pwsh scripts/build.ps1` builds `core` and `storage` through CMake and then `Spellbook.slnx` through MSBuild, under `/W4 /WX` on our code.
- `Spellbook.exe` is a WinUI 3 window titled "Spellbook" that keeps every M0 behavior (icon, `--data-dir`, `--smoke`, the log lines, schema 1 on first start), and runs from its output folder on a machine with no Windows App SDK runtime installed.
- `check-all.ps1`, CI, and `package.ps1` hold on the new stack; the portable ZIP holds the app folder.
- ADR 0002, `AGENTS.md`, `standards/ui.md`, `docs/architecture.md`, and a `winui-patterns` skill describe WinUI; no open plan section asks for a Win32 control.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | ADR 0002 and the decision record | -- |  [x]   |
|   2   |   §2    | The Visual Studio 2026 toolchain pins and the setup leg | §1, D99 T01 §5 |  [x]   |
|   3   |   §7    | Provision missing WinUI tools on disposable CI runners | §2 |  [x]   |
|   4   |   §3    | The WinUI 3 shell in the hybrid build | §2, §7 |  [ ]   |
|   5   |   §4    | Runners, CI, and the portable package on the new stack | §3, D00 T01 §10 |  [ ]   |
|   6   |   §5    | The winui-patterns skill, the UI standard, and the architecture doc | §3 |  [ ]   |
|   7   |   §6    | Retarget the open UI sections of the plan to WinUI | §5 |  [ ]   |

---

## 1. ADR 0002 and the Decision Record

The operator changed the stack on 2026-10-04. This section records that decision before any code moves, so a later session never reads ADR 0001 and rebuilds the Win32 shell. Two questions stay open until §3 proves them; each gets a default and its cost here, and §3 replaces the default with the measured answer.

- [x] Write `docs/adr/0002-winui-3.md`: context (the operator's request, quoted), the decision (WinUI 3 on Windows App SDK 2.5.1 through C++/WinRT; VS 2026 v145; hybrid build with CMake + Ninja for `core`, `storage`, and tests, MSBuild `.vcxproj` in `Spellbook.slnx` for the app; unpackaged self-contained), the alternatives refused with the operator's choice (all-MSBuild; MSIX packaged; framework-dependent with the runtime installer), and the consequences (a folder not a single exe; two build systems; the app layer can no longer be compiled by CMake). Done when: the ADR has Status `Accepted` and a date.
- [x] Record the two open questions in the ADR with defaults. **CRT:** default keeps `x64-windows-static` and the static CRT for `core` and `storage`; if the WinUI app cannot link or start against `/MT`, switch every target to the `x64-windows-static-md` triplet and the dynamic CRT, shipping the VC++ runtime app-local in the folder (cost: the triplet change rebuilds the vcpkg cache and every gate). **clang-tidy on the app:** default keeps clang-tidy on `core` and `storage` only (they have `compile_commands.json`) and uses MSVC Code Analysis on the `.vcxproj` (cost: the app gets a different analyzer than the libraries). Done when: both are in the ADR under "Open until §3".
- [x] Mark ADR 0001's UI framework, app build, and single-file sections "Superseded by ADR 0002" in place, without deleting them. Done when: `rg -n "Superseded by ADR 0002" docs/adr/0001-tech-stack.md` prints a line per superseded section.
- [x] Update "The decisions this project runs on" in `AGENTS.md` (C++20 on MSVC bullet, the Win32 bullet, the packaging bullet) and the `src/app/` row of the path table to point at ADR 0002. Done when: `rg -n "Win32, no UI framework" AGENTS.md` prints nothing.
- [x] Independently update the product overview, `src/app/` row, compiler/UI decisions, and packaging decision in `CLAUDE.md` to reference ADR 0002 while retaining its standalone workflow. Done when: both writer contracts state the approved WinUI direction, provisional CRT choice, and current bootstrap caveat; neither presents the superseded stack as current. Added 2026-10-08 after Stage 2 review exposed this gap; do not import, copy, or synchronize agent orchestration.
- [x] Commit: `"docs: adr 0002, winui 3 on visual studio 2026 with a hybrid build (D00 T02 §1)"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` passes on the new ADR (no em dash, one line per paragraph), and `rg -n "Win32, no UI framework|one self-contained file|single self-contained file" AGENTS.md CLAUDE.md docs/adr/0002-winui-3.md` prints nothing. Both independently maintained writer contracts point to ADR 0002 and retain the current-bootstrap caveat.

> **Verified:** 2026-10-08 | §1 | Corrected candidate: `python scripts/check-docs.py` returned "0 findings", exit 0; `rg -n "Win32, no UI framework|one self-contained file|single self-contained file" AGENTS.md CLAUDE.md docs/adr/0002-winui-3.md` returned no matches, expected exit 1; `rg -n "Superseded by ADR 0002" docs/adr/0001-tech-stack.md` returned four notices, exit 0. Independent `pwsh scripts/check-all.ps1` exited 0: "check-all: all gates passed", all 21 gates PASS, "100% tests passed out of 29" in both Debug and Release, Release smoke exit 0, "todo-graph validate: 17 files, 120 sections, 0 fatal, 0 warnings", and "plan --check: current". Evidence: `build/reviews/d00-t02-s1-r2-9285/stage1-checkpoint.log`, `stage1-check-all.log`, and `stage1-check-all.exit.txt` in that directory; writer gate log `build/codex/d00-t02-s1-r2-check-all.log`. All 188 manifest files matched before/after Stage 1 and again before finalization; CRT and app-analysis defaults remain provisional until §3.
> **Implementer:** Codex (gpt-6-astra).
> **Reviewer:** Codex gpt-6-astra, effort high, CLI 0.161.0, session `01a11c1f-a002-77f1-876a-7334a049d92e`; APPROVE for base `609fb35cc8b9b322cdb70da601b16d41bc00f263` plus `build/reviews/d00-t02-s1-r2-9285/candidate.json`, manifest SHA-256 `e79c3a07cb9df0aa835b4aaa0e32dc3a1b9da312d33f5809ad54526cf219bca7`, tracked diff SHA-256 `61b9b118f90df8d486774aa22880b777a50206ef5757135623d88a7849b2b33a`, including the untracked ADR 0002. Reports: `build/reviews/d00-t02-s1-r2-9285/stage1-review.md` and `codex-review.md`; exit 0 in `codex-exit.txt`; global-configured runtime verified in `stage1-runtime.json` and `runtime-identities.json` in that directory. This exact reviewer session verified both approvals and finalized only the stamp and status metadata.
> **Second reviewer:** Claude claude-sonnet-5-5, alias sonnet, effort high (`--model sonnet --effort high`), CLI 2.1.294, firstParty, session `a27c25b5-115e-4f7c-8244-dada6aacc0b6`; APPROVE for the same corrected candidate. Report: `build/reviews/d00-t02-s1-r2-9285/sonnet-review.json`; success, non-error, exit 0 (`sonnet-exit.txt`), no fallback model. Runtime and current official alias/minimum-CLI source receipts: `runtime-identities.json` in that directory.

## 2. The Visual Studio 2026 Toolchain Pins and the Setup Leg

MSVC stays machine-wide (`AGENTS.md`, the repo-portable toolchain rule), but the msvc leg must now find VS 2026 with the WinUI tools and refuse VS 2022, or a build silently uses the old toolset. The Windows App SDK and C++/WinRT come as NuGet packages, so they are pinned like the other tools.

- [x] `toolchain.json` `msvc`: `vswhereVersionRange` `[18.0,19.0)`, `fallbackToLatest` `false`, `requires` both `Microsoft.VisualStudio.Component.VC.Tools.x86.x64` and the Windows App SDK C++ component (`Microsoft.VisualStudio.Component.WindowsAppSdkSupport.Cpp`; **Corrected 2026-10-04:** the id `Microsoft.VisualStudio.ComponentGroup.WindowsAppSDK.Cpp` from older documentation does not exist in the VS 2026 18.10 catalog, and the installer ignored it silently; the operator's install log of 2026-10-04 lists `Microsoft.VisualStudio.Component.WindowsAppSdkSupport.Cpp`). Done when: the file names VS 2026 only.
- [x] `toolchain.json`: pin `nuget.exe` (URL, SHA-256, version) as a component, and the packages `Microsoft.WindowsAppSDK` 2.5.1 and `Microsoft.Windows.CppWinRT` (the latest stable, recorded with its date). Done when: `setup.ps1` downloads and hash-checks `nuget.exe` into `.tools/`.
- [x] `scripts/setup.ps1` msvc leg: report the v145 toolset and MSVC version from `VC\Tools\MSVC`, and print the VS Installer modify command (not `winget` Build Tools) when the WinUI component is missing. Done when: on a machine without the WinUI component the leg fails naming `WindowsAppSdkSupport.Cpp`.
- [x] `scripts/_common.ps1` `Enter-DevEnvironment`: enter the VS 2026 `vcvars64.bat`. Done when: `cl` in the entered environment prints `Version 19.50` or later.
- [x] Add `scripts/test-toolchain.ps1` to the full gate suite and CI, covering the old-version pin, missing compiler/component, raw executable provisioning, hash rejection, and contained cleanup. Done when: its ten probes pass without machine-wide changes.
- [x] Update `CONTRIBUTING.md`, `standards/cpp.md`, `docs/reference-conventions.md`, and each independently maintained build-and-test skill for VS 2026 and operator-owned installation. Done when: those current instructions contain no VS 2022/v143 or automatic `-InstallMsvc` guidance.
- [x] Commit: `"workspace: pin visual studio 2026, the windows app sdk, and c++/winrt (D00 T02 §2)"`

**Test checkpoint:** Driven run: `pwsh scripts/setup.ps1 -Verify` prints the VS 2026 path, MSVC 14.50 or later, and `nuget` at its pinned version, and ends `setup: all legs green`. Negative probe: with `vswhereVersionRange` set back to `[17.0,18.0)` and `fallbackToLatest` `false`, the leg fails (then restore the pin). `pwsh scripts/test-toolchain.ps1` performs that negative probe with an in-memory pin and disposable fixtures, ending `toolchain tests: 10 passed`. `rg -n "VS 2022|Visual Studio 2022|v143|InstallMsvc" CONTRIBUTING.md standards/cpp.md docs/reference-conventions.md .agents/skills/build-and-test/SKILL.md .claude/skills/build-and-test/SKILL.md` returns no matches (exit 1).

> **Verified:** 2026-10-08 | §2 | Independent `pwsh scripts/check-all.ps1` exited 0: "check-all: all gates passed", all 22 gates PASS, "100% tests passed out of 29" in Debug and Release, Release smoke exit 0, "lint.ps1: clang-tidy clean", "todo-graph validate: 17 files, 120 sections, 0 fatal, 0 warnings", and "plan --check: current". Exact checkpoint: `pwsh scripts/setup.ps1 -Verify` exited 0 with "v145, MSVC 14.51.36231", NuGet 7.9.0, and "setup: all legs green"; `pwsh scripts/test-toolchain.ps1` exited 0 with "toolchain tests: 10 passed", including the in-memory old-version/no-fallback rejection; entered `cl` reported "Version 19.51.36260 for x64"; the checkpoint's five-file stale-guidance search returned no matches, expected exit 1. Independent evidence: `build/reviews/d00-t02-s2-r2-9285/stage1-check-all.log`, `stage1-check-all.exit.txt`, `stage1-checkpoint.log`, and `stage1-checkpoint.exit.txt` in that directory. Writer provisioning and clean-build evidence in `build/toolchain-evidence/` records the hash-checked NuGet download, "Debug OK", and "Release OK"; no machine-wide installation was performed. All 189 candidate files matched before/after Stage 1 and again before finalization. Hosted CI remains subject to required verification of the exact pushed commit; Stage 2's bounded-probe and re-entry observations establish no unmet §2 contract. The app remains the bootstrap until §3.
> **Implementer:** Codex (gpt-6-astra).
> **Reviewer:** Codex gpt-6-astra, effort high, CLI 0.161.0, session `01a11c44-354d-7db2-84f7-f71fe3a84032`; APPROVE for base `e548e87adab178c1b639b8648650a745d8734477` plus `build/reviews/d00-t02-s2-r2-9285/candidate.json`, manifest SHA-256 `5cbfa33d9d9544ef21e187a4a8e5523ac786c97824173de42959e074e4c842bb`, tracked diff SHA-256 `86ed1f01d74a9f6c23ff6100dab639f1586359bdc8344436d6e1502ec10c1798`, including untracked `scripts/test-toolchain.ps1`. Reports: `build/reviews/d00-t02-s2-r2-9285/stage1-review.md` and `codex-review.md`; exit 0 in `codex-exit.txt`; global-configured runtime confirmed in `stage1-runtime.json`, `stage1-session-metadata.json`, and `runtime-identities.json` in that directory. This exact independent reviewer session confirmed both approvals and finalized only the stamp and derived plan metadata.
> **Second reviewer:** Claude claude-sonnet-5-5, alias sonnet, effort high (`--model sonnet --effort high`), CLI 2.1.294, firstParty, session `96f88861-8da7-4b90-a058-b476125a0fd6`; APPROVE for the same candidate. Report: `build/reviews/d00-t02-s2-r2-9285/sonnet-review.json`; success, non-error, completed, exit 0 (`sonnet-exit.txt`), no fallback model. Runtime and official alias/minimum-CLI receipts: `runtime-identities.json` in that directory; finalizer independently rechecked [official model routing](https://code.claude.com/docs/en/model-config).

## 3. The WinUI 3 Shell in the Hybrid Build

This section replaces the Win32 shell from `D00 T01 §5` with a WinUI 3 one at feature parity, and settles the two open questions from §1. The libraries do not change: `core` and `storage` keep their CMake targets and tests. The app is a C++/WinRT WinUI 3 `.vcxproj` that consumes the CMake-built `.lib` files and the vcpkg `installed` tree. Logic stays out of the app layer.

- [ ] `Spellbook.slnx` at the repository root and `src/app/Spellbook.vcxproj` (C++/WinRT, `PlatformToolset` v145, `LanguageStandard` stdcpp20, x64 only, `AppxPackage` false, `WindowsPackageType` None, `WindowsAppSDKSelfContained` true, `UNICODE`, `/W4 /WX`, `packages.config` with the §2 pins). Done when: `msbuild Spellbook.slnx -restore -p:Configuration=Debug -p:Platform=x64` builds.
- [ ] Link the app to `spellbook_core` and `spellbook_storage` from `artifacts/build/<preset>/` and to the vcpkg libraries from `artifacts/vcpkg_installed/<triplet>/`, through a `src/app/Spellbook.props` that maps Debug to the `debug` preset and Release to `release`. Done when: the app calls `spellbook::core::product_name()` and the storage migrator with no duplicate-symbol or CRT-mismatch link errors.
- [ ] Settle the CRT question from §1 by building and launching against `/MT`; if it fails, take the `x64-windows-static-md` fallback for every target. Done when: ADR 0002 records the result with the linker or launch output that decided it.
- [ ] `src/app/App.xaml` and `App.xaml.cpp`: parse `--data-dir` and `--smoke`, start logging (port `src/app/logging.cpp` and `app_paths.cpp` unchanged in behavior), open and migrate `spellbook.db`, create the main window. In `--smoke`, exit 0 after the first frame without any dialog, even on failure. Done when: `Spellbook.exe --smoke --data-dir <tmp>` exits 0 and `<tmp>\spellbook.db` reads `PRAGMA user_version` = 1.
- [ ] `src/app/MainWindow.xaml` and `.cpp`: title exactly `Spellbook`, Mica backdrop, custom title bar following the app theme, and the empty-grimoire state (a heading and one line of plain guidance, strings from one resource file). Done when: a launch shows the window with `MainWindowTitle` `Spellbook`.
- [ ] Window and Explorer icon: `src/app/res/spellbook.rc` keeps the `IDI_APP` icon and the version resource in the `.vcxproj`, and the window sets its icon through `AppWindow::SetIcon`. Done when: Explorer and the taskbar show the icon and the Details tab shows the git-tag version.
- [ ] Delete the Win32 shell (`src/app/main.cpp`, `main_window.cpp`, `main_window.hpp`, `res/spellbook.manifest` if the WinUI project replaces it) and drop the `Spellbook` target from `src/app/CMakeLists.txt` and the root `CMakeLists.txt`. Done when: `cmake --build --preset debug` builds `core`, `storage`, and the tests and no app.
- [ ] Settle the clang-tidy question from §1: run clang-tidy over one app source with the generated C++/WinRT headers; keep the default if it is unusable. Done when: ADR 0002 records the result.
- [ ] Commit: `"app: the winui 3 shell in a hybrid build (D00 T02 §3)"`

**Test checkpoint:** Driven run with evidence: copy the Release output folder to a path outside the repository and launch it on this machine with no Windows App SDK runtime package registered (`Get-AppxPackage *WindowsAppRuntime*` empty, or on a clean VM); the window opens titled `Spellbook`, `spellbook.log` holds the starting, schema, window, and exiting lines, and `--smoke --data-dir <tmp>` exits 0. Builds clean: Debug and Release under `/W4 /WX`.

**Job:** the user can open Spellbook and see that their (empty) grimoire is ready.
**Treatment:** a WinUI 3 window with Mica, a custom title bar, and an empty state with a heading and one line of guidance. Cheaper substitute that fails the checkpoint: the default template's "Click me" page, or a window that runs only with the Windows App SDK runtime installed.
**Chrome:** consume the WinUI theme resources and the system font ramp. Do not invent a theme system before `D05 T01 §1`.

## 4. Runners, CI, and the Portable Package on the New Stack

Every gate that ran on the Win32 build must run on the hybrid one, or `check-all.ps1` passes while the app is broken. CI must be green on the old stack first (`D00 T01 §10`) so a red run here is this change.

- [ ] `scripts/build.ps1`: configure and build the CMake preset, then `msbuild Spellbook.slnx -restore` for the matching configuration, logs under `build/`. Done when: `pwsh scripts/build.ps1 -Config Release` produces `Spellbook.exe` and exits 0; a deliberate warning in `MainWindow.xaml.cpp` fails it.
- [ ] `scripts/run.ps1` and `-Smoke`: launch the MSBuild output. Done when: `pwsh scripts/run.ps1 -Smoke` exits 0.
- [ ] `scripts/lint.ps1` and `check-all.ps1`: the analyzer split decided in §3, and the layering check extended to the `.vcxproj` sources. Done when: `pwsh scripts/check-all.ps1` exits 0.
- [ ] `scripts/package.ps1`: zip the self-contained output folder (not one exe) as `Spellbook-<version>-win-x64-portable.zip`, with `SHA256SUMS`. Done when: the ZIP unzipped to a temp folder launches with `--smoke`.
- [ ] `.github/workflows/ci.yml` and `release.yml`: build on `windows-latest` (VS 2026), with the NuGet package cache beside the existing tool and vcpkg caches. Done when: actionlint is clean.
- [ ] `docs/dev/` build guide: VS 2026 workloads, `Spellbook.slnx`, and the hybrid build. Done when: `python scripts/check-docs.py` passes.
- [ ] Commit: `"workspace: runners, ci, and the portable package on the winui stack (D00 T02 §4)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/check-all.ps1` exits 0 locally (quote its last lines), and the `ci` run on the pushed commit is green (quote its run id and duration).

## 5. The winui-patterns Skill, the UI Standard, and the Architecture Doc

The next sessions build M1 surfaces from the skill and the standard, not from memory. A Win32 skill left in place would steer them back to window procedures.

- [ ] Replace `.claude/skills/win32-ui-patterns/` with `.claude/skills/winui-patterns/SKILL.md`: the app object and window ownership, XAML plus code-behind, binding to view models that hold no logic, `x:Bind`, threading (`DispatcherQueue`, `co_await winrt::resume_foreground`), theme resources, Mica and the title bar, DPI (automatic), strings from `.resw`, and the pitfalls. Done when: it has `name` and `description` frontmatter and `validate` finds no dead ref.
- [ ] `AGENTS.md`: the skill list and the "Keep the Win32 layer thin" rule become "Keep the app layer thin". Done when: `grep -n "win32-ui-patterns\|Win32 layer" AGENTS.md` prints nothing.
- [ ] `standards/ui.md`: controls named by their WinUI types (`TreeView`, `ListView`, `TextBox`, `ContentDialog`, `NavigationView`, `InfoBar`), the theme from WinUI resources, the string table as `.resw` with the themed and plain vocabularies. Done when: no Win32 control name or message remains.
- [ ] `docs/architecture.md`: the layer diagram with the hybrid build, and where XAML sits. Done when: `python scripts/check-docs.py` passes.
- [ ] Commit: `"docs: winui patterns skill, ui standard, and architecture (D00 T02 §5)"`

**Test checkpoint:** Static evidence: `grep -rln "HWND\|WM_\|win32-ui-patterns" .claude standards docs AGENTS.md` prints nothing, and `python scripts/todo-graph.py validate` is clean.

## 6. Retarget the Open UI Sections of the Plan to WinUI

Open sections still name Win32 controls and messages, and the plan forbids silent reinterpretation. This section rewrites each one's treatment and items to WinUI equivalents, keeping its job and its proofs. Stamped sections are not touched.

- [ ] `D01 T01 §5`, `§6`, `§7` (`todo/01-library/TODO-01-library-crud.md`): TreeView and ListView become the WinUI `TreeView` and `ListView`, the edit controls `TextBox`, `EN_CHANGE` and `WM_KILLFOCUS` become `TextChanged` and `LostFocus`, the skill input becomes `winui-patterns`. Done when: `grep -n "EN_CHANGE\|WM_\|Common Controls\|win32-ui" todo/01-library/TODO-01-library-crud.md` prints nothing.
- [ ] `D02 T01 §4` (`todo/02-import/TODO-01-import-scrolls.md`): the folder picker becomes `Windows.Storage.Pickers.FolderPicker` initialised with the window handle (or `IFileOpenDialog`, recorded), the dialog a `ContentDialog`. Done when: the section names only WinUI or recorded COM APIs.
- [ ] `D03 T01 §5` and `§6` (`todo/03-find/TODO-01-find-and-cast.md`): the clipboard through `Windows.ApplicationModel.DataTransfer.Clipboard`; the global hotkey stays `RegisterHotKey` on the window handle and the tray icon stays `Shell_NotifyIcon` (WinUI has neither), each recorded as a deliberate Win32 interop. Done when: each Win32 call left in the section names why.
- [ ] `D04 T01 §3`, `§6` and `D05 T01 §1`, `§5` (`todo/04-templates/`, `todo/05-ship/TODO-01-polish.md`): the fill-in dialog a `ContentDialog`, dark mode through `RequestedTheme` and theme resources instead of `DarkMode_Explorer` and `WM_CTLCOLOR*`, accessibility through UI Automation peers. Done when: `grep -rn "DarkMode_Explorer\|WM_CTLCOLOR\|SetWindowTheme" todo/0[1-5]*` prints nothing.
- [ ] `D05 T02 §2` (`todo/05-ship/TODO-02-first-release.md`): the installer installs the app folder, not one exe. Done when: the item names the folder.
- [ ] Commit: `"todo: retarget the open ui sections to winui (D00 T02 §6)"`

**Test checkpoint:** Static evidence: `grep -rn "HWND\|WM_\|EN_CHANGE\|Common Controls\|DarkMode_Explorer" todo/0[1-5]*` prints only lines that name a recorded interop reason, and `python scripts/todo-graph.py validate` is clean.

## 7. Provision Missing WinUI Tools on Disposable CI Runners

Forward repair for §2: hosted CI run 37807805365 for `5a88f0ec8bc75feca4d68307fe88edd20cee38f5` failed at setup because its VS 2026 Enterprise installation lacks `WindowsAppSdkSupport.Cpp`. Local setup must continue to refuse machine-wide installation. A separate runner bootstrap may provision the missing component only on an explicitly identified GitHub-hosted disposable VM, before the unchanged setup verification.

- [x] `scripts/setup-ci.ps1`: refuse local and self-hosted execution, locate the existing VS 2026 C++ installation, add only the missing WinUI C++ component through the installed VS Installer, wait for completion, check the exit code, and repeat component discovery. Done when: a successful exit without the component still fails and an already complete installation is left alone.
- [x] `scripts/test-setup-ci.ps1`: exercise guard rejection, missing base tools, idempotence, installer failure, and post-install discovery with mocks that never invoke the installer. Add the probe to `scripts/check-all.ps1` and CI. Done when: every branch passes and local machine installation is never invoked.
- [x] `.github/workflows/ci.yml` and `release.yml`: call the guarded bootstrap before `scripts/setup.ps1`. Done when: an isolated candidate branch's hosted CI gets past the original missing-component failure and completes successfully for the exact candidate commit; actionlint passes. Do not tag or run release publication.
- [x] `docs/dev/build.md`, `docs/reference-conventions.md`, and `CHANGELOG.md`: distinguish disposable hosted provisioning from operator-owned local setup. Done when: the scope and failure behavior match the runner.
- [x] Commit: `"ci: provision missing winui tools on hosted runners (D00 T02 §7)"`

**Test checkpoint:** Driven run: `pwsh scripts/test-setup-ci.ps1` passes all guard/provisioning tests; the original failure is preserved in `build/toolchain-evidence/ci-37807805365-failed.log`; hosted `ci.yml` succeeds on the isolated candidate branch with its exact SHA recorded. `pwsh scripts/check-all.ps1` exits 0. No local installer invocation, self-hosted machine change, tag, or release publication occurs.

> **Verified:** 2026-10-08 | §7 | Independent `pwsh scripts/check-all.ps1` exited 0: "check-all: all gates passed", all 23 gates PASS, "100% tests passed out of 29" in both Debug and Release, Release smoke exit 0, actionlint PASS, "todo-graph validate: 17 files, 121 sections, 0 fatal, 0 warnings", and "plan --check: current". Independent `pwsh scripts/test-setup-ci.ps1` exited 0: "setup-ci tests: 10 passed", including "PASS: local execution is refused before installation" and self-hosted refusal. Evidence: `build/reviews/d00-t02-s7-9285/stage1-check-all.log`, `stage1-check-all.exit.txt`, `stage1-checkpoint.log`, and `stage1-checkpoint.exit.txt`; writer suite: `build/codex/d00-t02-s7-check-all.log`. Direct local refusal is preserved in `build/toolchain-evidence/setup-ci-local-refusal.log`; no real local installer was invoked. Original exact-base hosted failure remains in `build/toolchain-evidence/ci-37807805365-failed.log`. Isolated probe commit `e894946fda838ed335d242c3706032af147775ac` on `probe/codex-winui-ci-9285` completed hosted CI run 37808412174 successfully for that exact SHA: "setup-ci: WinUI C++ component verified (installer exit 0)", normal setup green, 29 tests per configuration, and smoke exit 0. Full hosted log: `build/toolchain-evidence/ci-37808412174.log`; readback: `stage1-hosted-live.json` in the review directory. `hosted-proof.json` and `stage1-probe-equality.json` prove that `scripts/setup-ci.ps1`, `scripts/test-setup-ci.ps1`, `scripts/check-all.ps1`, `.github/workflows/ci.yml`, and `.github/workflows/release.yml` equal the hosted commit byte-for-byte; native installer argument construction was exercised by that hosted run. All 191 candidate paths/hashes matched before and after Stage 1 and again before finalization. Preserve the probe branch as evidence; never merge it. No tag or release publication occurred.
> **Implementer:** Codex (gpt-6-astra).
> **Reviewer:** Codex gpt-6-astra, effort high, CLI 0.161.0, provider openai, session `01a11c5b-69c8-7150-af87-15de6cda9a53`; APPROVE for base `5a88f0ec8bc75feca4d68307fe88edd20cee38f5` plus `build/reviews/d00-t02-s7-9285/candidate.json`, manifest SHA-256 `2bb433fe9ceb07ea757475d789973930f1ec13797fcdd052298e7dce2c7ab185`, tracked diff SHA-256 `a384d247206e2d266e777b3b596bf27e1785bf4f64d42cecc8862cff1984a1cd`, including both untracked source scripts. Reports: `stage1-review.md` and `codex-review.md`; CLI exit 0 in `codex-exit.txt`; global-configured runtime verified in `stage1-runtime.json`, `codex-cli.log`, and `runtime-identities.json`, all in that review directory. This exact reviewer session confirmed both approvals and the unchanged manifest before finalizing only the stamp and derived plan metadata.
> **Second reviewer:** Claude claude-sonnet-5-5, alias sonnet, effort high (`--model sonnet --effort high`), CLI 2.1.294, provider firstParty, session `5dc332ff-b881-4db3-b84c-4c15ce3dc927`; APPROVE for the same candidate. Report: `build/reviews/d00-t02-s7-9285/sonnet-review.json`; success, non-error, completed, exit 0 (`sonnet-exit.txt`), no fallback model. Runtime, invocation, routing preflight, and official alias/minimum-CLI source receipt: `runtime-identities.json` in that directory. Non-blocking observations establish no missing requirement; hosted proof covers native argument construction.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `python scripts/todo-graph.py validate` clean
- [ ] The Release folder runs on a Windows 11 machine with no Windows App SDK runtime installed
