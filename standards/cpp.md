# C++ Standards

How Spellbook's C++ is written. `.clang-format` and `.clang-tidy` are the enforced forms of the layout and analysis rules; this is the readable one.

## The stack

| Concern | Choice | Notes |
| ------- | ------ | ----- |
| Language | C++20, MSVC (v145 toolset, VS 2026) | `/W4 /WX /permissive- /utf-8 /Zc:__cplusplus /Zc:preprocessor` on our targets (`cmake/SpellbookWarnings.cmake`) |
| Build | CMake presets + Ninja | `debug`, `release`, `relwithdebinfo`; output under `artifacts/build/<preset>/` |
| Packages | vcpkg manifest, `x64-windows-static` | Static CRT; `Spellbook.exe` has no runtime prerequisite |
| Database | sqlite3 (FTS5, JSON1) | Behind `IPromptRepository` |
| Logging | spdlog over fmt | One default logger, configured in `src/app/logging.cpp` |
| JSON | nlohmann-json | Settings and export (M5) |
| Tests | Catch2 v3 through CTest | See [`testing.md`](testing.md) |

A package outside this table is added by a TODO section that records why and checks that its license is compatible with MIT.

## Layering

`core <- storage <- app`. Core is standard C++ and never includes a Windows, storage, or app header; storage never includes a Windows or app header; the app is thin. `scripts/check-layering.py` enforces the include rules. Interfaces a core service needs (a repository, a clock) are declared in core and implemented below it.

## Naming and layout

- Types `PascalCase`; functions, variables, and parameters `snake_case`; private members `trailing_underscore_`; constants `kPascalCase`; pure interfaces `IPascalCase`; macros `UPPER_CASE`, and only for resource ids and include guards' absence (`#pragma once` everywhere).
- One namespace per layer: `spellbook::core`, `spellbook::storage`, `spellbook::app`.
- Files `snake_case.cpp` and `.hpp`. A library's public headers live in `src/<layer>/include/spellbook/<layer>/`, its sources in `src/<layer>/src/`.
- Includes in the order `.clang-format` regroups them: the file's own header, `<windows.h>`, other C and Win32 headers, the standard library, third-party libraries, `spellbook/` headers, local headers.
- Sources are ASCII. Non-ASCII characters in literals are `\u` escapes.

## Writing the code

- RAII for every resource: SQLite connections and statements, GDI objects, icons, window ownership. Move-only wrappers; no naked `new` except the window-procedure ownership pattern (`MainWindow`, deleted in `WM_NCDESTROY`).
- `[[nodiscard]]` on functions whose result must be used; `noexcept` where nothing can throw.
- No magic numbers: a size, duration, or limit is a named `constexpr` or a setting.
- Prefer `std::string_view` and `std::span` parameters; return by value.
- No `using namespace` in headers.

## Unicode

Text is UTF-8 in every `std::string` the program holds. The Win32 boundary converts with `core::utf8_to_wide` and `core::wide_to_utf8` and calls W APIs only (`UNICODE` is defined for every target). File paths are `std::filesystem::path`, built from wide strings at the boundary and handed to SQLite as UTF-8 (`path.u8string()`). The app manifest sets the process code page to UTF-8, so a narrow API that slips through still works under a non-ASCII user name, but never rely on it in new code.

## Errors

- Storage throws `StorageError` with context ("opening <path>: <SQLite message>") and the SQLite code.
- Expected failures the user can cause (a duplicate folder name, an unreadable import file) are reported with a message that names the action, the item, and what it needed.
- `catch (...)` only at the top of an action or in `wWinMain`, and it logs.
- The app never shows a raw exception string alone: it says what Spellbook was doing.

## Logging

- spdlog's default logger, file sink at `%LOCALAPPDATA%\Spellbook\logs\spellbook.log` (5 files of 5 MB), the debugger sink in Debug.
- `{}` arguments, never string concatenation into the format.
- **One Information line per user action that changes data**, naming the action and the id. **Never log prompt text**: prompts can hold anything.

| Level | Use for |
| ----- | ------- |
| debug | Developer diagnostics (off in release) |
| info | Lifecycle and user actions: started, migrated, created, moved, imported, exported |
| warn | Recovered problems: a skipped file, a fallback taken |
| error | A failed action the app survived |
| critical | The app is going down |

## User data

- Every write is transactional; a failure leaves the previous state.
- Migrations are frozen once shipped. A schema change is a new `migrations/NNNN_name.sql` (see `.claude/skills/add-migration/SKILL.md`), tested on a database from the previous version.
- Files Spellbook writes outside SQLite (settings, exports) are written to a temporary file in the target folder and then replaced atomically.
- Destructive actions confirm with what and how many, and say how to undo where an undo exists.

## Performance

- Name the budget in the section: search under 50 ms for 10,000 prompts; the window responsive during an import of 2,000 files.
- Anything that can take longer than about 200 ms runs off the UI thread and can be cancelled.
- Prepared statements are reused in loops; bulk writes run in one transaction.
