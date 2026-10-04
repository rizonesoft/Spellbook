---
schema_version: 1
id: workspace-winui-stack
domain: 00-workspace
status: draft
title: "TODO-02 -- The WinUI 3 Stack: Visual Studio 2026, Windows App SDK, and the Hybrid Build"
depends_on: []
---

# TODO-02 -- The WinUI 3 Stack: Visual Studio 2026, Windows App SDK, and the Hybrid Build

> **Goal:** Spellbook's app layer is a WinUI 3 desktop app in C++/WinRT on the latest stable Windows App SDK, built with the Visual Studio 2026 toolset (v145). `core`, `storage`, and their tests keep building through the CMake presets with Ninja. The app is an MSBuild `.vcxproj` in `Spellbook.slnx` that links those libraries. It ships unpackaged and self-contained as a folder (portable ZIP, Inno Setup 7 later). The runners, CI, ADR, standards, skills, and every open UI section of the plan speak WinUI, and the Win32 shell from `D00 T01 §5` is gone.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** The operator decided the change on 2026-10-04: "VS C++ (2026 - latest) with WinGUI 3 (latest)" (read as WinUI 3), with a **hybrid** build and **unpackaged, self-contained** packaging, both chosen over the alternatives (all-MSBuild; MSIX). Nothing is built yet. The app today is the Win32 shell in `src/app/` (`main.cpp`, `main_window.cpp`, `logging.cpp`, `app_paths.cpp`, about 530 lines) built by CMake. `toolchain.json` pins MSVC to `[17.0,18.0)` (VS 2022) with fallback to latest. The machine has Visual Studio Professional 2026 18.10.3 at `C:\Program Files\Microsoft Visual Studio\18\Professional` with **only** the Core Editor and Web workloads: no `VC\Tools\MSVC` folder and no WinUI component, so builds still use VS 2022 17.14 (MSVC 14.44). The latest stable Windows App SDK is **2.5.1** (2026-09-16). GitHub's `windows-latest` (Windows Server 2025) image carries VS 2026 since the June 2026 migration; `windows-2025-vs2026` also exists.

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

## Outcome

- `pwsh scripts/setup.ps1 -Verify` reports Visual Studio 2026 with the v145 toolset and the Windows App SDK C++ tools, and the pinned Windows App SDK 2.5.1 and C++/WinRT packages.
- `pwsh scripts/build.ps1` builds `core` and `storage` through CMake and then `Spellbook.slnx` through MSBuild, under `/W4 /WX` on our code.
- `Spellbook.exe` is a WinUI 3 window titled "Spellbook" that keeps every M0 behavior (icon, `--data-dir`, `--smoke`, the log lines, schema 1 on first start), and runs from its output folder on a machine with no Windows App SDK runtime installed.
- `check-all.ps1`, CI, and `package.ps1` hold on the new stack; the portable ZIP holds the app folder.
- ADR 0002, `AGENTS.md`, `standards/ui.md`, `docs/architecture.md`, and a `winui-patterns` skill describe WinUI; no open plan section asks for a Win32 control.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | ADR 0002 and the decision record | -- |  [ ]   |
|   2   |   §2    | The Visual Studio 2026 toolchain pins and the setup leg | §1, D99 T01 §5 |  [ ]   |
|   3   |   §3    | The WinUI 3 shell in the hybrid build | §2 |  [ ]   |
|   4   |   §4    | Runners, CI, and the portable package on the new stack | §3, D00 T01 §10 |  [ ]   |
|   5   |   §5    | The winui-patterns skill, the UI standard, and the architecture doc | §3 |  [ ]   |
|   6   |   §6    | Retarget the open UI sections of the plan to WinUI | §5 |  [ ]   |

---

## 1. ADR 0002 and the Decision Record

The operator changed the stack on 2026-10-04. This section records that decision before any code moves, so a later session never reads ADR 0001 and rebuilds the Win32 shell. Two questions stay open until §3 proves them; each gets a default and its cost here, and §3 replaces the default with the measured answer.

- [ ] Write `docs/adr/0002-winui-3.md`: context (the operator's request, quoted), the decision (WinUI 3 on Windows App SDK 2.5.1 through C++/WinRT; VS 2026 v145; hybrid build with CMake + Ninja for `core`, `storage`, and tests, MSBuild `.vcxproj` in `Spellbook.slnx` for the app; unpackaged self-contained), the alternatives refused with the operator's choice (all-MSBuild; MSIX packaged; framework-dependent with the runtime installer), and the consequences (a folder not a single exe; two build systems; the app layer can no longer be compiled by CMake). Done when: the ADR has Status `Accepted` and a date.
- [ ] Record the two open questions in the ADR with defaults. **CRT:** default keeps `x64-windows-static` and the static CRT for `core` and `storage`; if the WinUI app cannot link or start against `/MT`, switch every target to the `x64-windows-static-md` triplet and the dynamic CRT, shipping the VC++ runtime app-local in the folder (cost: the triplet change rebuilds the vcpkg cache and every gate). **clang-tidy on the app:** default keeps clang-tidy on `core` and `storage` only (they have `compile_commands.json`) and uses MSVC Code Analysis on the `.vcxproj` (cost: the app gets a different analyzer than the libraries). Done when: both are in the ADR under "Open until §3".
- [ ] Mark ADR 0001's UI framework, app build, and single-file sections "Superseded by ADR 0002" in place, without deleting them. Done when: `grep -n "Superseded by ADR 0002" docs/adr/0001-tech-stack.md` prints a line per superseded section.
- [ ] Update "The decisions this project runs on" in `AGENTS.md` (C++20 on MSVC bullet, the Win32 bullet, the packaging bullet) and the `src/app/` row of the path table to point at ADR 0002. Done when: `grep -n "Win32, no UI framework" AGENTS.md` prints nothing.
- [ ] Commit: `"docs: adr 0002, winui 3 on visual studio 2026 with a hybrid build (D00 T02 §1)"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` passes on the new ADR (no em dash, one line per paragraph), and `grep -rn "Win32, no UI framework\|single self-contained file" AGENTS.md docs/adr/0002-winui-3.md` prints nothing.

## 2. The Visual Studio 2026 Toolchain Pins and the Setup Leg

MSVC stays machine-wide (`AGENTS.md`, the repo-portable toolchain rule), but the msvc leg must now find VS 2026 with the WinUI tools and refuse VS 2022, or a build silently uses the old toolset. The Windows App SDK and C++/WinRT come as NuGet packages, so they are pinned like the other tools.

- [ ] `toolchain.json` `msvc`: `vswhereVersionRange` `[18.0,19.0)`, `fallbackToLatest` `false`, `requires` both `Microsoft.VisualStudio.Component.VC.Tools.x86.x64` and the Windows App SDK C++ component group (`Microsoft.VisualStudio.ComponentGroup.WindowsAppSDK.Cpp`; confirm the id with `vswhere -version [18.0,19.0) -include packages -format json` after D99 T01 §5). Done when: the file names VS 2026 only.
- [ ] `toolchain.json`: pin `nuget.exe` (URL, SHA-256, version) as a component, and the packages `Microsoft.WindowsAppSDK` 2.5.1 and `Microsoft.Windows.CppWinRT` (the latest stable, recorded with its date). Done when: `setup.ps1` downloads and hash-checks `nuget.exe` into `.tools/`.
- [ ] `scripts/setup.ps1` msvc leg: report the v145 toolset and MSVC version from `VC\Tools\MSVC`, and print the VS Installer modify command (not `winget` Build Tools) when the WinUI component is missing. Done when: on a machine without the WinUI component the leg fails naming `WindowsAppSDK.Cpp`.
- [ ] `scripts/_common.ps1` `Enter-DevEnvironment`: enter the VS 2026 `vcvars64.bat`. Done when: `cl` in the entered environment prints `Version 19.50` or later.
- [ ] Commit: `"workspace: pin visual studio 2026, the windows app sdk, and c++/winrt (D00 T02 §2)"`

**Test checkpoint:** Driven run: `pwsh scripts/setup.ps1 -Verify` prints the VS 2026 path, MSVC 14.50 or later, and `nuget` at its pinned version, and ends `setup: all legs green`. Negative probe: with `vswhereVersionRange` set back to `[17.0,18.0)` and `fallbackToLatest` `false`, the leg fails (then restore the pin).

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

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `python scripts/todo-graph.py validate` clean
- [ ] The Release folder runs on a Windows 11 machine with no Windows App SDK runtime installed
