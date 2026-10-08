---
name: add-feature
description: End-to-end checklist for building a feature -- plan entry, core, storage, UI, tests, docs, changelog, and the TODO and plan update -- in the layer order the architecture requires. Use when implementing any user-facing capability, alone or through process-todo-section.
---

# Add a Feature

A feature is built bottom-up, so each layer is tested before the next one leans on it, and logic ends up in core where it can be tested without a window.

## 0. Plan first

- Find the feature's section: `python scripts/todo-graph.py query ready`, or search `todo/`. No section? Capture it through `add-todo` before writing code.
- `python scripts/todo-graph.py resolve '<ref>'` must exit 0 (ready). Exit 4 names the unmet dependency; build that first.
- Read the whole section, its Inputs, and `standards/`. If the section is wrong about the code (a path moved, a function exists already), correct the section in the same commit and say so.

## 1. Core

- Domain types in `src/core/include/spellbook/core/domain.hpp`; services and pure functions in their own header and source.
- Dependencies arrive as interfaces declared in core (`IPromptRepository`, `IClock`), injected by reference.
- Unit tests in `tests/core/<unit>_tests.cpp` for **every public function**, including the failure cases.
- `pwsh scripts/test.ps1 -Filter "core:"` green before moving on.

## 2. Storage

- Schema change? Use `add-migration` first.
- Repository methods with bound parameters only; writes in one statement or one transaction.
- Tests in `tests/storage/` against `:memory:` or a temp folder, including the failure path.

## 3. UI

- Follow `win32-ui-patterns` and `standards/ui.md`. Labels from the vocabulary table.
- The window calls a core service; it never builds SQL or holds business rules.
- Account for every control: working, or disabled with a tooltip naming its owner section.
- Long work off the UI thread.

## 4. Prove it

- `pwsh scripts/check-all.ps1` green.
- Run the section's Test checkpoint exactly as written and keep its output.
- Surfaces: a driven run with `pwsh scripts/run.ps1 -DataDir build/dev-data`, the log lines quoted, the database read back (`scripts/migrate.ps1` prints the schema; query with `python -c "import sqlite3; ..."`), and captures under `docs/captures/<area>/` at 100 and 150 percent.

## 5. Document

- `docs/user/<area>.md` for anything a user sees; link it from `docs/user/README.md`.
- The README Features table and Keyboard Shortcuts section when they change.
- `docs/architecture.md` when a layer gains a new responsibility.
- `CHANGELOG.md` under `## [Unreleased]`, in user language.

## 6. Close the plan and commit

- Tick every item, write the `> **Verified:**` stamp with the evidence, flip the Implementation Order row to `[x]` (through `review-todo-section`).
- `python scripts/todo-graph.py plan --sync`, then `validate`.
- One commit, message from the section's `Commit:` item: `<area>: <summary> (DNN TNN §N)`.

Codex owns this independent skill. Use `git -c core.hooksPath=.codex/githooks commit` for commits; inspect every dirty file first and preserve safe user side edits.
