# ADR 0001: The Tech Stack

- **Status:** Accepted
- **Date:** 2026-10-04
- **Deciders:** the operator (the project brief, and the toolchain question answered in session), the initialisation session

## Context

Spellbook replaces a folder of Notepad `.txt` prompts with a desktop app to store, organise, search, template, and copy them. It must start instantly, feel native on Windows 10 and 11, handle any Unicode text, work offline with no account, and stay small enough for one person to maintain. The brief fixed the main choices; this record states them with their reasons and the alternatives, so they are not re-argued later.

## Decisions

### Language and compiler: C++20 on MSVC (Visual Studio 2022, v143)

The Win32 API is a C API, and MSVC is its first-class compiler: the SDK headers, the resource compiler, and the debugger are built around it. C++20 gives `std::span`, `std::format`-era fmt, concepts, and `std::chrono` calendar types without exotic features. A newer VS with the C++ x64 tools is accepted, so a fresh CI image keeps working.

*Alternatives:* C# with WPF or WinUI (the stack of Isotone and ScratchPad) starts slower and needs a runtime; Rust has thinner Win32 tooling and no resource compiler story; clang-cl would work but adds a second compiler to support for no gain.

### UI: Win32 API, no framework

A native Win32 window starts in milliseconds, has no runtime to install, matches the system's controls, and gets accessibility, high contrast, and DPI behavior from Windows. The cost is more code per surface, which the layering rule contains: windows stay thin and logic lives in core. Per-Monitor-V2 DPI and Common Controls v6 come from the manifest; dark mode is done with `DwmSetWindowAttribute` and the `DarkMode_Explorer` theme where Windows supports it.

*Alternatives:* WinUI 3 (C++/WinRT) needs the Windows App SDK runtime and packaging; Qt 6 brings a large runtime and its own look; Dear ImGui does not look or behave like a Windows app and is weak on accessibility.

### Storage: SQLite with FTS5, behind `IPromptRepository`

An embedded database in one file needs no server, no credentials, and no setup, and SQLite's FTS5 gives ranked, diacritic-insensitive full-text search over thousands of prompts in milliseconds. WAL mode keeps the last committed state through a crash. Versioned migrations in `migrations/` are embedded into the binary and applied transactionally on open.

*Alternative recorded:* MySQL 8 through MySQL Connector/C++ behind the same interface. It would need a server, connection configuration with no hardcoded credentials (Windows Credential Manager or a gitignored config file), and setup documentation. It buys sharing a library across machines, which a single-user offline tool does not need. It stays possible because nothing above storage sees SQLite; it is backlog entry `B-001`.

### Libraries, through vcpkg in manifest mode

| Library | Why |
| ------- | --- |
| sqlite3 (features `fts5`, `json1`) | The database. The C API directly, wrapped in a small RAII layer, rather than SQLiteCpp: the wrapper is under 300 lines, matches the error style, and avoids a second dependency |
| spdlog with fmt | Fast, structured logging with a rotating file sink |
| nlohmann-json | Settings and export (M5); header-only |
| Catch2 v3 | Expressive tests with readable failure output and CTest discovery. Chosen over GoogleTest for its single-binary simplicity and natural-language test names |

The triplet is `x64-windows-static` with the static CRT, so `Spellbook.exe` is one self-contained file with no redistributable to install.

### Build: CMake presets, Ninja, and a repo-portable toolchain

CMake presets give one build definition for Visual Studio, VS Code, the scripts, and CI. Ninja is fast and works the same everywhere. The operator decided on 2026-10-04 to keep the toolchain portable: cmake, ninja, clang-format, clang-tidy, actionlint, and vcpkg are pinned in `toolchain.json` (URL, SHA-256, version) and provisioned into `.tools/` by `scripts/setup.ps1`, so every clone and CI run use the same versions. Only MSVC and the Windows SDK are machine-wide, because they cannot practically be portable. This matters most for clang-format: VS 2022 and VS 2026 bundle different LLVM versions that format differently.

### Layering

`core` (standard C++, no Windows headers) <- `storage` <- `app`. Core is unit-testable with no GUI and no database; storage is tested against in-memory and temporary databases; the app is proven by driven runs and the launch smoke.

### Packaging: Inno Setup 7

**Chosen: Inno Setup 7**, for the installer in M5 (`D05 T02 §2`), beside a portable ZIP from M0.

- It builds a classic `Setup.exe` that can install per-user without administrator rights or for all users, which suits a tool many people will want to try on a locked-down work machine.
- It handles the things Spellbook needs simply: a Start menu entry, an optional "start with Windows" task for the global hotkey, an uninstaller that keeps the user's data unless asked.
- The operator's other projects (Isotone, IsotoneStack, Notepad3) already use Inno Setup, so the scripts, signing, and release steps are known.
- It is one small, free tool that `toolchain.json` can pin.

*Alternatives:* WiX builds MSI packages, which suit enterprise deployment but are heavier to author and maintain for a single-exe app. MSIX gives clean installs and updates but needs signing for every install, runs the app in a container that complicates a global hotkey and `%LOCALAPPDATA%` access, and is a poor fit for a portable ZIP.

### Versioning

SemVer from git tags `v*` (`cmake/SpellbookVersion.cmake`), following Isotone's rule that no version string is typed into a project file.

## Consequences

- A contributor needs Visual Studio 2022 (or the Build Tools), PowerShell 7, Git, and Python 3; `scripts/setup.ps1` does the rest.
- Each surface costs more Win32 code than a framework would, so the layering rule and the `win32-ui-patterns` skill are load-bearing.
- Bumping a tool or the vcpkg baseline is a deliberate commit to `toolchain.json` (and `vcpkg.json` for the baseline) that passes `scripts/check-all.ps1`.
