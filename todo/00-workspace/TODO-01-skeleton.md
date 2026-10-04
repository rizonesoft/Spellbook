---
schema_version: 1
id: workspace-skeleton
domain: 00-workspace
status: active
title: "TODO-01 -- The M0 Skeleton"
depends_on: []
frozen: true
---

# TODO-01 -- The M0 Skeleton

> **Goal:** A clean clone becomes a working Spellbook in four commands (`setup`, `build`, `test`, `run`): the pinned toolchain provisions itself, the app opens an empty main window titled "Spellbook" with its icon, `%LOCALAPPDATA%\Spellbook\spellbook.db` is created at schema version 1, logging writes to disk, the gates run locally in one command, CI is green on GitHub, and the plan, standards, skills, and docs are in place for M1.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** Sections 1 to 9 were built and verified in the initialisation session on 2026-10-04; their stamps below quote the runs. §10 is in progress: the first `ci` run on `main` (37164511590, b39045c) was green in about 5 minutes and saved both caches; the cache-restore run is owed.

## Inputs

- [`../../docs/reference-conventions.md`](../../docs/reference-conventions.md) -- the Isotone, Resolute, and ScratchPad conventions this skeleton copies, and every divergence
- [`../../docs/adr/0001-tech-stack.md`](../../docs/adr/0001-tech-stack.md) -- the stack decisions
- -> XREF: D99 T01 §1 -- the GitHub repository and first push, without which §10 cannot run

## Outcome

- `pwsh scripts/setup.ps1`, `build.ps1`, `test.ps1`, and `run.ps1` work on a clean clone.
- `Spellbook.exe` opens an empty main window titled "Spellbook" with a placeholder icon, and creates `spellbook.db` in `%LOCALAPPDATA%\Spellbook\` at schema version 1.
- Core and storage each have passing unit tests; `pwsh scripts/check-all.ps1` runs every local gate.
- `.github/workflows/ci.yml` is valid and green on `main`.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Repository config and the repo-portable toolchain | -- |  [x]   |
|   2   |   §2    | CMake presets, vcpkg manifest, warning policy, tag-derived version | §1 |  [x]   |
|   3   |   §3    | Core: version info, UTF-8 and UTF-16 text, the domain model | §2 |  [x]   |
|   4   |   §4    | Storage: SQLite wrapper, migration runner, schema 1 with FTS5 | §3 |  [x]   |
|   5   |   §5    | The Win32 shell: window, icon, manifest, logging, smoke mode | §4 |  [x]   |
|   6   |   §6    | The PowerShell runners and check-all | §5 |  [x]   |
|   7   |   §7    | The TODO system, its tooling, and the M0 to M5 plan | §6 |  [x]   |
|   8   |   §8    | Agent infrastructure: AGENTS.md, standards, skills, hooks | §7 |  [x]   |
|   9   |   §9    | README, docs, ADR, and the GitHub templates | §8 |  [x]   |
|  10   |   §10   | CI green on GitHub | §9, D99 T01 §1 |  [ ]   |

---

## 1. Repository Config and the Repo-Portable Toolchain

The toolchain must be the same on every machine, or `format -Check` and configure results differ by who ran them. Operator decision 2026-10-04 ("Let's create a repo portable toolset or would you recommend installing globally in windows?", answered with the hybrid below): cmake, ninja, clang-format, clang-tidy, and vcpkg are pinned and downloaded into `.tools/`; MSVC and the Windows SDK are machine-wide by necessity and checked, never installed silently.

- [x] Add `.gitignore`, `.gitattributes` (LF for scripts and docs, CRLF for C++ and resources, as Isotone), `.editorconfig`, `LICENSE` (MIT), `.clang-format`, and `.clang-tidy` (Resolute's check families). Done when: `git check-attr eol -- src/core/src/text.cpp` prints `crlf`.
- [x] Pin the tools in `toolchain.json` (URL, SHA-256, probe, version match) and vcpkg's commit. Done when: the file names cmake 4.4.4, ninja 1.13.2, clang-format 23.1.2, clang-tidy 22.1.8, and vcpkg `5dd2e16`.
- [x] Write `scripts/_common.ps1` (`Invoke-Native`, `Enter-DevEnvironment` through vswhere and vcvars64, `Get-ToolPath`) and `scripts/setup.ps1` (legs msvc, tools, vcpkg, hooks, python; `-Verify`, `-InstallMsvc`, `-Help`). Done when: `pwsh scripts/setup.ps1` on a machine with only VS 2022 installs every other leg and ends `setup: all legs green`.
- [x] Commit: `"workspace: pin a repo-portable toolchain and add the setup runner"`

**Test checkpoint:** Driven run: `pwsh scripts/setup.ps1` from an empty `.tools/` downloads and hash-checks four archives, clones and bootstraps vcpkg, sets `core.hooksPath`, and prints `setup: all legs green`; `-Verify` then exits 0. A tampered SHA-256 in `toolchain.json` makes the download leg throw naming the component.

> **Verified:** 2026-10-04 | §1 | setup from empty .tools: cmake 4.4.4, ninja 1.13.2, clang-format 23.1.2, clang-tidy 22.1.8 hash-checked, vcpkg 5dd2e1600d04 bootstrapped, msvc 14.44.35207 found, "setup: all legs green"; first run exposed and fixed the single-argument splat bug inherited from Isotone's Invoke-Native
> **Implementer:** Claude (claude-opus-5-5)

## 2. CMake Presets, vcpkg Manifest, Warning Policy, Tag-Derived Version

One build definition for every machine and CI: Ninja presets over MSVC with the vcpkg toolchain, a static triplet so `Spellbook.exe` is self-contained, `/W4 /WX` on our targets only, and a version that comes from git tags (the Isotone rule: no version string is typed into a project file).

- [x] Write `CMakePresets.json` with `debug`, `release`, `relwithdebinfo` configure, build, and test presets (binary dir `artifacts/build/<preset>`, triplet `x64-windows-static`). Done when: `cmake --list-presets` lists the three.
- [x] Write `vcpkg.json` (sqlite3 with fts5 and json1, fmt, spdlog, nlohmann-json, catch2; `builtin-baseline` equal to the `toolchain.json` commit). Done when: the first configure installs all five.
- [x] Write `cmake/SpellbookWarnings.cmake` (per-target `/W4 /WX /permissive- /utf-8`, `UNICODE`, and a configure-time audit, copied from Resolute's `ResoluteWarnings.cmake`). Done when: a target without `spellbook_set_warnings()` fails the configure naming it.
- [x] Write `cmake/SpellbookVersion.cmake` (`git describe --match v*`) and `cmake/EmbedMigrations.cmake` (migrations as byte arrays, sequence checked). Done when: the build prints `Spellbook version 0.0.0-alpha.N`.
- [x] Commit: `"workspace: the M0 skeleton: cmake build, core, storage at schema 1, and the win32 shell"`

**Test checkpoint:** Builds clean: `pwsh scripts/build.ps1 -Config Debug` exits 0 with zero warnings under `/W4 /WX`.

> **Verified:** 2026-10-04 | §2 | first configure built the five vcpkg ports; build Debug 44/44 steps, 0 warnings; version 0.0.0-alpha.0 before the first commit
> **Implementer:** Claude (claude-opus-5-5)

## 3. Core: Version Info, UTF-8 and UTF-16 Text, the Domain Model

`spellbook_core` is standard C++ with no Windows headers, so everything in it is unit-testable without a GUI. M0 puts in what every later milestone needs first: the product identity, the text conversion the Win32 boundary uses, and the domain types the schema mirrors.

- [x] `src/core/include/spellbook/core/version.hpp`: `app_name()`, `version()`, `version_banner()` over the generated `build_info.hpp`. Done when: `core: version_banner joins the name and the version` passes.
- [x] `src/core/include/spellbook/core/text.hpp`: `is_valid_utf8`, `utf8_to_wide`, `wide_to_utf8` with U+FFFD substitution of maximal subparts. Done when: the six `core: ...` text cases pass, including overlong, surrogate, and above-U+10FFFF inputs.
- [x] `src/core/include/spellbook/core/domain.hpp`: `Prompt`, `Folder`, `Tag`, `PromptVersion`, `TemplateVariable`. Done when: the field names match `migrations/0001_init.sql`.
- [x] Commit: `"workspace: the M0 skeleton: cmake build, core, storage at schema 1, and the win32 shell"`

**Test checkpoint:** Unit test: `pwsh scripts/test.ps1 -Filter "core:"` passes every core case.

> **Verified:** 2026-10-04 | §3 | 9 core cases pass (text conversion, validity, version); check-layering 0 findings
> **Implementer:** Claude (claude-opus-5-5)

## 4. Storage: SQLite Wrapper, Migration Runner, Schema 1 with FTS5

The database is where users' prompts live, so the migration path is frozen behavior from its first commit: each step runs in one transaction with its `PRAGMA user_version` bump, a database newer than the build is refused, and a shipped migration is never edited.

- [x] `src/storage/.../database.hpp`: RAII `Database` and `Statement`, `StorageError` with the SQLite code, UTF-8 paths. Done when: `storage: Database::open creates a file under a non-ASCII path` passes.
- [x] `src/storage/.../migrations.hpp` and `src/storage/src/migrator.cpp`: `embedded_migrations()`, `migrate()`. Done when: the rollback, downgrade-refusal, and gap cases pass.
- [x] `migrations/0001_init.sql`: folders, prompts, tags, prompt_tags, prompt_versions, and an external-content FTS5 index with sync triggers. Done when: `storage: FTS5 indexes prompts through the triggers, with diacritics folded` passes.
- [x] `IPromptRepository` and `SqlitePromptRepository` (foreign keys, WAL, busy timeout, migrate on open). Done when: `storage: a new in-memory repository is at schema version 1 with no prompts` passes.
- [x] Commit: `"workspace: the M0 skeleton: cmake build, core, storage at schema 1, and the win32 shell"`

**Test checkpoint:** Unit test: `pwsh scripts/test.ps1 -Filter "storage:"` passes every storage case.

**Freeze check:** `storage: a failing step rolls back and leaves the last complete version` proves a failed migration leaves the database at the previous version with no partial tables.

> **Verified:** 2026-10-04 | §4 | 20 storage cases pass, including rollback on a failing step and refusal of a newer database; FTS5 match, update, and delete through the triggers
> **Implementer:** Claude (claude-opus-5-5)

## 5. The Win32 Shell: Window, Icon, Manifest, Logging, Smoke Mode

The app layer is thin by rule: a window, messages, and resources. M0 proves the boundary: Unicode W APIs, Per-Monitor-V2 DPI, Common Controls v6, the UTF-8 process code page, a dark title bar when apps are dark, and a log on disk.

- [x] `src/app/res/spellbook.manifest`, `spellbook.rc`, `version.rc.in`, and `assets/spellbook.ico` (drawn by `scripts/generate-icon.py`). Done when: Explorer shows the icon on `Spellbook.exe` and its Details tab shows the version.
- [x] `src/app/main_window.cpp`: class registration, DPI-aware size and fonts, `WM_DPICHANGED`, dark title bar through `DwmSetWindowAttribute`, the empty-grimoire placeholder. Done when: the window title is exactly `Spellbook`.
- [x] `src/app/logging.cpp` and `app_paths.cpp`: spdlog rotating file at `%LOCALAPPDATA%\Spellbook\logs\spellbook.log`. Done when: a launch writes the starting, schema, window, and exiting lines.
- [x] `src/app/main.cpp`: `--data-dir` and `--smoke`. Done when: `Spellbook.exe --smoke --data-dir <tmp>` exits 0 without a message box, even on failure.
- [x] Commit: `"workspace: the M0 skeleton: cmake build, core, storage at schema 1, and the win32 shell"`

**Test checkpoint:** Driven run with evidence: a normal launch shows a window whose `MainWindowTitle` is `Spellbook`; `%LOCALAPPDATA%\Spellbook\spellbook.db` then reads `PRAGMA user_version` = 1 with every table; `pwsh scripts/run.ps1 -Smoke` exits 0.

**Job:** the user can open Spellbook and see that their (empty) grimoire is ready.
**Treatment:** an empty state with a heading and one line of plain-language guidance. Cheaper substitute that fails the checkpoint: a blank white window.
**Chrome:** consume the system message font at the window's DPI and the system app-mode colours. Do not invent a theme system before `D05 T01 §1`.

> **Verified:** 2026-10-04 | §5 | launch: MainWindowTitle "Spellbook", log "Main window created at 144 DPI (dark theme)"; %LOCALAPPDATA%\Spellbook\spellbook.db user_version 1 with folders, prompts, tags, prompt_tags, prompt_versions, prompts_fts; smoke exit 0
> **Implementer:** Claude (claude-opus-5-5)

## 6. The PowerShell Runners and check-all

Every runner is PowerShell 7 with comment-based help and `-Help`, dot-sources `scripts/_common.ps1`, and fails by name. `check-all.ps1` is Isotone's one-command gate.

- [x] `scripts/build.ps1` (`-Config`, `-Clean`), `test.ps1` (`-Filter`, `-NoBuild`), `run.ps1` (`-Smoke`, `-DataDir`). Done when: each `-Help` prints its synopsis and parameters.
- [x] `scripts/format.ps1` (`-Check`) and `lint.ps1` (clang-tidy plus `scripts/check-layering.py`). Done when: both are clean on the tree.
- [x] `scripts/migrate.ps1` (dev database under `build/dev-data/`, `-Reset`). Done when: it prints `user_version: 1` and the tables.
- [x] `scripts/package.ps1` (portable ZIP and `SHA256SUMS`; installer stubbed to `D05 T02 §2`) and `release.ps1` (changelog, commit, tag; `-DryRun`). Done when: `package.ps1` writes the ZIP.
- [x] `scripts/check-all.ps1`. Done when: it runs every gate and exits 0.
- [x] Commit: `"workspace: build, test, run, format, lint, migrate, package, release, and check-all runners"`

**Test checkpoint:** Driven run: `pwsh scripts/check-all.ps1` exits 0 with every gate PASS.

> **Verified:** 2026-10-04 | §6 | check-all 16 gates PASS: toolchain, layering self-test, layering, format -Check, build Debug, build Release, test Debug (29), test Release (29), smoke Release, lint (clang-tidy 14 files clean), actionlint, check-docs self-test, check-docs, todo-graph self-test, validate, plan --check; clang-tidy's first run found 12 findings, 11 fixed and performance-no-int-to-ptr disabled with its reason in .clang-tidy; a fresh clone in another folder ran setup (all legs green, 48 s), build (vcpkg ports compiled from source, done at 267 s), test (29 passed), and run -Smoke (exit 0); migrate -Reset printed user_version 1 and the six tables; package wrote Spellbook-0.0.0-alpha.9-win-x64-Portable.zip (1.0 MB) and SHA256SUMS; all ten -Help switches print their synopsis after moving #Requires below the help block
> **Implementer:** Claude (claude-opus-5-5)

## 7. The TODO System, Its Tooling, and the M0 to M5 Plan

The plan lives in the repository, in the format all three reference repos share, with a validator so it cannot drift.

- [x] `todo/README.md` (the format spec), `TODO-00-INDEX.md`, `implementation-plan.md`, `backlog.md`, one domain per milestone, and `99-manual`. Done when: every M1 to M5 scope item in the initialisation brief has a section.
- [x] `scripts/todo-graph.py` (validate, plan --sync and --check, query, resolve, self-test). Done when: `self-test` passes every fixture.
- [x] Commit: `"todo: the TODO system, its validator, and the M0 to M5 plan"`

**Test checkpoint:** Static evidence: `python scripts/todo-graph.py self-test` prints `0 failed`; `validate` prints `0 fatal`; flipping an unstamped row to `[x]` makes `validate` exit 1 with `unstamped-flip`.

> **Verified:** 2026-10-04 | §7 | todo-graph self-test 13 passed 0 failed; validate 8 files, 51 sections, 0 fatal, 0 warnings; plan --check current; query ready lists 7 sections, D01 T01 §1 first
> **Implementer:** Claude (claude-opus-5-5)

## 8. Agent Infrastructure: AGENTS.md, Standards, Skills, Hooks

- [x] `AGENTS.md` with `CLAUDE.md` as its import stub, and `standards/` (shared, cpp, ui, testing, release). Done when: AGENTS.md carries the stack, commands, layering, style, definition of done, and the rule that every change updates its TODO section and the plan.
- [x] `.claude/skills/`: build-and-test, add-migration, win32-ui-patterns, add-feature, fix-bug, release, add-todo, create-todo (with its template), process-todo-section, review-todo-section. Done when: each has `name` and `description` frontmatter and `validate` finds no dead ref in them.
- [x] `tools/githooks/pre-commit` (validate on the staged tree) and `commit-msg` (strips AI attribution), and `.claude/settings.json`. Done when: a commit with a broken plan is refused.
- [x] Commit: `"workspace: agent rules, standards, skills, and git hooks"`

**Test checkpoint:** Driven run: a staged `todo/` edit that breaks parity is refused by the pre-commit hook with the validate finding.

> **Verified:** 2026-10-04 | §8 | pre-commit refused a probe that flipped D01 T01 §1 to [x] unstamped (partial-flip, unstamped-flip, plan-stale; commit exit 1), tree restored; both hooks at index mode 100755; 10 skills with name and description; validate checks their refs, 0 fatal
> **Implementer:** Claude (claude-opus-5-5)

## 9. README, Docs, ADR, and the GitHub Templates

- [x] `README.md` in the Isotone style, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`. Done when: no placeholder prose remains.
- [x] `docs/architecture.md`, `docs/adr/0001-tech-stack.md`, `docs/reference-conventions.md`, `docs/user/README.md`, `docs/dev/build.md`. Done when: each is linked from `docs/README.md`.
- [x] `.github/`: `ci.yml`, `release.yml`, issue forms, PR template, `dependabot.yml`, `labels.yml`, `FUNDING.yml`. Done when: the pinned actionlint (added to `toolchain.json` for this) reports nothing.
- [x] `scripts/check-docs.py`: dead relative links, issue-form keys, and em dashes. Done when: its self-test passes and the tree has 0 findings.
- [x] Commit: `"docs: README, architecture, ADR 0001, reference conventions, and the GitHub setup"`

**Test checkpoint:** Static evidence: `.tools/actionlint/actionlint.exe` exits 0 over both workflows; `python scripts/check-docs.py` prints `0 findings`; a probe link to a missing file makes it exit 1 with `dead-link`.

> **Verified:** 2026-10-04 | §9 | actionlint 1.7.12 exit 0 over ci.yml and release.yml; check-docs self-test 1 passed 0 failed; check-docs 0 findings over every tracked Markdown file
> **Implementer:** Claude (claude-opus-5-5)

## 10. CI Green on GitHub

The workflows only count once GitHub has run them. This needs the repository to exist (`D99 T01 §1`).

- [x] Push `main` and watch `ci` run. Done when: the `ci` run on `main` is green, and its log shows the vcpkg cache saved.
- [ ] Re-run `ci` and confirm the vcpkg cache restores. Done when: the second run's configure step takes under five minutes.
- [ ] Commit: `"ci: record the first green run"` (the README badge goes live; no code change expected)

**Test checkpoint:** Driven run with evidence: `gh run list --workflow ci.yml --branch main --limit 1` shows `completed success`; a probe branch with a misformatted file fails the `format` step.

**Needs:** GitHub repository (`D99 T01 §1`)

## Verification

- [x] `pwsh scripts/check-all.ps1` exits 0
- [x] `python scripts/todo-graph.py validate` clean
- [ ] `ci` green on `main` (§10)
