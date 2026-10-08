# AGENTS.md

The primary writer is selected by `writer.json`: either `codex` or `claude`, with equal implementation authority when selected. Human orientation lives in `README.md`. Claude Code has independent instructions in `CLAUDE.md`; it does not import this file.

Before implementation or resuming a run, execute `python scripts/writer.py assert codex`. If Claude is selected, Codex may inspect or independently review, but must not implement. On an explicit request to switch writers, either agent may run `python scripts/writer.py select codex` or `python scripts/writer.py select claude`; this administrative action changes only the selection, never launches a run or migrates agent state. Check selection again before each section and after a pause. Do not hand-edit the setting to bypass an active-run refusal.

Never run concurrent writers in this checkout. A session that launches the Codex supervisor monitors it; only the supervised worker writes implementation. Independent reviewers inspect and test without modifying implementation.

Codex uses only `.agents/skills/` and `.codex/` automation. Skills, lifecycle hooks, Git hooks, configuration, and runtime state are independently maintained files, never symlinked, imported, or automatically synchronized across agents. Shared repository build/test/format/lint/TODO scripts remain agent-neutral; keep agent-specific orchestration under its own agent directory. See `docs/dev/codex.md`.

The writer cannot approve its own work. Use a fresh-context Codex reviewer subagent, given only the section reference and candidate diff, for every implemented section. Record the actual implementer and reviewer model identities when available; never invent them. An unavailable reviewer blocks stamping and shipping.

Preserve user side changes. Before staging or committing, inspect `git status --short` and enough diff/content to understand every dirty file. Include small, safe, non-secret, non-generated side edits in the coherent commit. Stop only for a concrete conflict or unsafe change; never discard user edits. On Windows use `exec_command` with `tty: true` and hidden background processes.

## What this project is

**Spellbook** is a native Windows prompt manager: a fast desktop app to store, organise, search, template, and copy AI prompts, replacing a folder of Notepad `.txt` files. Tagline: *Your grimoire of AI prompts.* C++20, Win32, SQLite with FTS5. Executable `Spellbook.exe`, C++ namespace `spellbook`, data in `%LOCALAPPDATA%\Spellbook\` (`spellbook.db`, `logs\spellbook.log`).

| Path | Purpose |
| ---- | ------- |
| `src/core/` | `spellbook_core`: the domain model and services. Standard C++ only: no Windows headers, no storage, no UI |
| `src/storage/` | `spellbook_storage`: `IPromptRepository`, `SqlitePromptRepository`, the SQLite wrapper, and the migration runner |
| `src/app/` | `Spellbook.exe`: the Win32 shell (entry point, windows, resources, manifest). Thin by rule |
| `migrations/` | `NNNN_name.sql` schema steps, embedded into the binary at build time; a shipped one is never edited |
| `tests/` | Catch2 suites, one executable per library (`tests/core/`, `tests/storage/`), run through CTest |
| `scripts/` | The PowerShell 7 runners (`setup`, `build`, `test`, `run`, `format`, `lint`, `migrate`, `package`, `release`, `check-all`) and the stdlib Python gates (`todo-graph.py`, `check-layering.py`, `check-docs.py`) |
| `toolchain.json` | The pinned repo-portable tools (cmake, ninja, clang-format, clang-tidy, actionlint, vcpkg); `scripts/setup.ps1` provisions them into `.tools/` |
| `cmake/` | The warning policy, the git-tag version, and the migration embedder |
| `todo/` | The live execution plan; read `todo/README.md` before authoring or implementing; domains `00` to `06` plus `99` (operator-only) |
| `todo/implementation-plan.md` | Phases 0 to 5 (milestones M0 to M5); boxes derived by `scripts/todo-graph.py plan --sync` |
| `standards/` | Coding, UI, testing, and release standards |
| `docs/` | Architecture, ADRs, the reference conventions, the developer build guide, and the user guide |
| `.agents/skills/` | Codex-only skills, discovered by Codex |
| `.codex/` | Codex-only hooks, configuration, supervisor, and tests |
| `.claude/` | Independent Claude Code workflow |
| `.codex/githooks/` | `pre-commit` (validates the staged TODO tree) and `commit-msg` (strips AI attribution) |
| `artifacts/` | Build output (every preset builds under `artifacts/build/<preset>/`); ignored, never authoritative |
| `build/` | Scratch: logs, smoke data, dev databases; ignored, never authoritative |
| `.tools/` | The provisioned toolchain and the vcpkg binary cache; ignored |

Everything here is Windows-only. The Python gates are stdlib Python 3 (`python` on Windows) and need no install step.

## The decisions this project runs on

- **C++20 on MSVC** (the VS 2022 v143 toolset; a newer VS with the C++ x64 tools is accepted), **CMake presets** (`debug`, `release`, `relwithdebinfo`) with **Ninja**, **vcpkg in manifest mode** with the `x64-windows-static` triplet and the static CRT, so `Spellbook.exe` is one self-contained file. See `docs/adr/0001-tech-stack.md`.
- **Win32, no UI framework.** Unicode W APIs only (`UNICODE`), UTF-16 at the API boundary and UTF-8 everywhere else (`core::utf8_to_wide` and `wide_to_utf8`), Per-Monitor-V2 DPI, Common Controls v6, the UTF-8 process code page, dark-mode-aware.
- **SQLite with FTS5** behind `IPromptRepository`. Versioned migrations in `migrations/`, one transaction per step, `PRAGMA user_version` as the schema version, a newer database refused rather than downgraded.
- **Libraries:** sqlite3, spdlog (with fmt), nlohmann-json, Catch2. **A dependency is a decision:** a new one is added by a TODO section that records why and checks its license is MIT-compatible.
- **The toolchain is repo-portable** (operator decision 2026-10-04): cmake, ninja, clang-format, clang-tidy, actionlint, and vcpkg are pinned in `toolchain.json` and live in `.tools/`; only MSVC and the Windows SDK are machine-wide. A tool from PATH is never used in their place.
- **Version from git tags** (`v<SemVer>`, `cmake/SpellbookVersion.cmake`); no version string is typed into a project file.
- **Packaging:** one **Inno Setup 7** installer with three modes (install for me, install for all users, portable) plus the portable ZIP; a `Spellbook.portable` marker beside the exe keeps all data in `Data\` beside it. Unsigned for v0.1.0. Channels: GitHub Releases, winget, Scoop, Chocolatey; the Microsoft Store waits for code signing. See `docs/adr/0003-v0.1.0-scope-and-distribution.md`.
- **Network:** the update check (on by default, at most daily, GitHub Releases API, no user data) and the opt-in AI features (OpenRouter with the user's key in Windows Credential Manager, or an ACP agent the user runs), both governed by the Privacy page in Settings; AI costs show per result with a monthly cap. Nothing else touches the network, and there are **no secrets in the repository**. See ADR 0003 and ADR 0004.
- **v0.1.0 is the premium release** (ADR 0003): M1 to M5 plus capture, Jump List, Trash, backups, `.spell` files, duplicates, rich runes, composition, the smart editor, tabs, the starter grimoire, metadata, and crash safety. Windows 10 (1809+) and 11. Start with Windows is opt in.
- **Unattended runs** (`process-plan`) push `main` after each stamped section, never force-push, never amend a pushed commit, and never tag; operator-only work lives in `todo/99-manual/` and is never run by an agent.
- **Theme in UI copy and docs only:** Spell, Chapter, Sigil, Cast, Rune, Revisions, Import scrolls in labels; Prompt, Folder, Tag, copy, TemplateVariable, PromptVersion, import in code and schema. Every themed label has a tooltip with the plain meaning, and all labels come from one string table that can switch to plain words (`standards/ui.md`).
- **Repository:** https://github.com/rizonesoft/Spellbook, public, default branch `main`, created by the operator on 2026-10-04 (`D99 T01 §1`).
- **Ownership:** MIT License, "Copyright (c) 2026 Rizonetech (Pty) Ltd", publisher Rizonesoft, following Isotone. Pending the operator's confirmation in `D99 T01 §4`.

## Layering

```
core  <-  storage  <-  app
```

- `core` depends on the standard library only (plus header-only nlohmann-json from M5). It never includes a Windows, storage, or app header.
- `storage` depends on core and SQLite. It never includes a Windows or app header.
- `app` depends on both and on Win32. It holds windows, messages, and resources: **logic belongs in core.** A function in `src/app/` that a test would want to call is in the wrong layer.
- `python scripts/check-layering.py` enforces the include rules; `lint.ps1`, `check-all.ps1`, and CI run it.

## Code style

- `.clang-format` is the format; run `pwsh scripts/format.ps1`, never format by hand. `.clang-tidy` is the analysis level.
- Naming: `PascalCase` types, `snake_case` functions and variables, `trailing_underscore_` private members, `kPascalCase` constants, `I` prefix on pure interfaces (`IPromptRepository`), `UPPER_CASE` macros only for resource ids. Files `snake_case.cpp` and `.hpp`; public headers under `include/spellbook/<layer>/`.
- C++ sources are ASCII: write non-ASCII characters as `\u` escapes in literals.
- RAII for every handle (SQLite, GDI, Win32); no naked `new` outside the window-procedure ownership pattern in `main_window.cpp`.
- Errors: storage throws `StorageError`; the app catches at the top of an action and tells the user what failed and why. Never swallow an exception silently.
- Logging: spdlog, structured `{}` arguments, one Information line per user action that changes data, naming the action and the id, **never the prompt text**.
- Detail: `standards/cpp.md`.

## The TODO system

`todo/` is the live execution plan; **format spec: `todo/README.md`.** Domains follow the milestones: `00-workspace` (M0), `01-library` (M1), `02-import` (M2), `03-find` (M3), `04-templates` (M4), `05-ship` (M5), and `99-manual` (operator-only). Files are `todo/NN-domain/TODO-NN-short-name.md`; references are `§N`, `TNN §N`, `DNN TNN §N`. The **Implementation Order table is the dependency graph**, a row flips to `[x]` only with a `Verified:` stamp, and every section sits in exactly one phase row of `todo/implementation-plan.md`.

**Update the TODO section and the plan as part of every change.** A change that implements plan work ticks its items, writes its stamp, flips its row, and runs `python scripts/todo-graph.py plan --sync` in the same commit. A change outside the plan (a bug fix, a small doc fix) either names the section it belongs to or files new work through the `add-todo` skill. The pre-commit hook refuses a commit whose staged tree fails `validate`.

## Choose the work contract

Use the Codex skill under `.agents/skills/` that fits: capture work through `add-todo`, author a file through `create-todo`, build a section through `process-todo-section`, stamp it through `review-todo-section`. To run the plan unattended, `process-plan` (which chains `process-phase` inside the Codex supervisor, with separate native Stop and Interrupt hooks); close a finished file with `process-todo-file`; harden the tree before a long run with `groom-plan`. Codex run records live in `docs/codex-runs/`. For the engineering itself: `build-and-test`, `add-feature` (core, then storage, then UI, then tests, docs, and the plan), `fix-bug`, `add-migration`, `win32-ui-patterns`, and `release`.

**One section = one commit.** Each section must be executable with zero conversation context.

## What counts as proof

A Test checkpoint cites one or more of the five proofs in `todo/README.md`: builds clean, static analysis clean, unit test (cited by name), driven run with evidence (a log line, a database row read back, a capture), and round-trip proof (owed by every importer and exporter). A checkpoint citing a gate that does not exist is not allowed. Report only commands actually run, and quote their output.

## Definition of done

A change is done when all of these hold:

1. `pwsh scripts/check-all.ps1` exits 0 (toolchain, layering, format, Debug and Release builds with `/W4 /WX`, tests, the launch smoke, clang-tidy, actionlint, docs, the plan gates, and the run guard probe).
2. Every new public core function has a unit test; a bug fix has a test that failed before the fix.
3. The Test checkpoint ran and its evidence is quoted in the stamp.
4. User-visible changes update `docs/user/` and the `CHANGELOG.md` Unreleased section.
5. The TODO section is ticked and stamped, its row flipped, and `plan --sync` run, in the same commit.
6. The commit message follows the convention below.

## Working rules

- **Bound every command's output** (`| Select-Object -Last 30`, `ctest -R`, `--quiet`); keep full logs under `build/`.
- **Act, then report:** complete authorized work and report evidence. Explicit operator stop instructions take effect immediately.
- **User data first:** the database is the user's work. Every write is transactional, every migration is tested on a database from the previous version, destructive actions confirm with what and how many, and tests never touch the real `%LOCALAPPDATA%\Spellbook` (they use `--data-dir`, temp folders, or `:memory:`).
- **Keep the Win32 layer thin.** If a window procedure grows logic, move it to core and test it there.
- **No em dashes** in authored prose: use `--`, a colon, or a new sentence. One line per paragraph and list item in Markdown. `scripts/check-docs.py` checks the em dash.
- **Source of truth:** Win32 behavior from Microsoft Learn, SQLite behavior from sqlite.org, plan state from `todo/`. Disagreements are recorded decisions, not silent reinterpretations.
- **Unknowns:** answer from source first. When an open question would change the implementation, take a justified default, record that it is a default and what changing it costs, and carry on.

## Commits

Trunk-based `main`. Messages are `<area>: <imperative lowercase summary>`, the convention of all three reference repositories, with the plan reference in the body or in parentheses: `storage: prompt create, read, update, delete, and list (D01 T01 §1)`. Areas: `workspace`, `core`, `storage`, `app`, `todo`, `docs`, `ci`, `installer`, `brand`, `release`. Never bypass the hooks with `--no-verify`, amend a pushed commit, or force-push `main`.

## The commit hooks

`.codex/githooks/pre-commit` validates the staged TODO tree and Codex workflow layout. `.codex/githooks/commit-msg` strips AI attribution. They are independent executable LF files. Use `git -c core.hooksPath=.codex/githooks commit ...` for every Codex commit; do not change the clone-wide hook setting or bypass hooks. Repository setup retains the separate legacy hook path for Claude and human use. A red hook is a defect to fix.

## Validation

```powershell
pwsh scripts/setup.ps1 -Verify          # the pinned toolchain is present
pwsh scripts/check-all.ps1              # every gate, the same as CI
pwsh scripts/build.ps1 -Config Debug    # the build alone (Release, RelWithDebInfo; -Clean)
pwsh scripts/test.ps1 -Filter "storage:"   # tests matching a CTest regex
pwsh scripts/run.ps1 -Smoke             # start, migrate, paint, exit 0, against build/smoke/
pwsh scripts/format.ps1 -Check          # clang-format gate
pwsh scripts/lint.ps1                   # clang-tidy and the layering check
pwsh scripts/migrate.ps1 -Reset         # apply every migration to build/dev-data/spellbook.db
```

```bash
python scripts/todo-graph.py validate       # FATAL fails
python scripts/todo-graph.py plan --sync    # after any TODO edit
python scripts/todo-graph.py query ready    # dependency-safe work right now
python scripts/todo-graph.py resolve 'D01 T01 §1'
python scripts/check-layering.py
python scripts/check-docs.py
```

## Credentials

Credentials never enter tracked files, arguments, logs, or handoff prose. The app stores none. A future code-signing certificate is supplied to the packaging script from outside the repository.
