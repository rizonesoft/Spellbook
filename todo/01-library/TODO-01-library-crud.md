---
schema_version: 1
id: library-crud
domain: 01-library
status: draft
title: "TODO-01 -- The Library: Spells, Chapters, the Editor, and Autosave"
depends_on: []
frozen: true
---

# TODO-01 -- The Library: Spells, Chapters, the Editor, and Autosave

> **Goal:** Spellbook replaces the Notepad folder for day-to-day use: the main window shows the folder tree (Chapters), the prompt list (Spells), and an editor pane; the user creates, edits, renames, moves, and deletes prompts and folders; every edit is saved automatically within a second of the user pausing, and nothing typed is lost on close or crash. All labels come from one string table that can switch between the themed and the plain vocabulary.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** `IPromptRepository` (`src/storage/include/spellbook/storage/prompt_repository.hpp`) has only `schema_version()` and `prompt_count()`. Schema 1 already holds `folders`, `prompts`, and the FTS5 index (`migrations/0001_init.sql`). The main window (`src/app/main_window.cpp`) paints a static empty state; there are no child controls, menus, or accelerators. Domain types exist in `src/core/include/spellbook/core/domain.hpp` with no services.

## Inputs

- [`migrations/0001_init.sql`](../../migrations/0001_init.sql) -- the tables this file reads and writes; no schema change is expected
- [`standards/ui.md`](../../standards/ui.md) -- layout, DPI, keyboard, and the theme vocabulary
- [`.claude/skills/win32-ui-patterns/SKILL.md`](../../.claude/skills/win32-ui-patterns/SKILL.md) -- control creation, subclassing, and DPI handling
- -> XREF: D02 T01 §3 -- import writes through the folder and prompt operations §1 and §2 add
- -> XREF: D05 T01 §2 -- the settings store owns the persisted vocabulary choice §4 reads
- -> XREF: D00 T02 §6 -- the app moves to WinUI 3 (operator decision 2026-10-04); §5 to §7 are retargeted there before they are built

## Outcome

- The repository creates, reads, updates, lists, and deletes prompts and folders, each covered by storage tests.
- `LibraryService` in core holds the rules (titles, timestamps, autosave timing) and is unit-tested against a fake repository and a fake clock.
- The main window is a three-pane layout (Chapters tree, Spells list, editor) that works by keyboard and mouse at 100, 150, and 200 percent scaling.
- Autosave writes within one second of the last keystroke, on focus change, and on close; killing the process loses at most that second.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Prompt CRUD in the repository | D00 T01 §4 |  [ ]   |
|   2   |   §2    | Folder tree operations in the repository | §1 |  [ ]   |
|   3   |   §3    | LibraryService: rules, clock, and the autosave policy | §2 |  [ ]   |
|   4   |   §4    | The vocabulary string table | D00 T01 §3 |  [ ]   |
|   5   |   §5    | The three-pane main window | §3, §4, D00 T02 §6 |  [ ]   |
|   6   |   §6    | Create, rename, move, and delete commands | §5 |  [ ]   |
|   7   |   §7    | Autosave wiring and the status bar | §6 |  [ ]   |
|   8   |   §8    | The library user guide | §7 |  [ ]   |

---

## 1. Prompt CRUD in the Repository

The repository is the only writer of prompts. This section extends `IPromptRepository` with the prompt operations every later milestone uses, implemented over SQLite with prepared statements and covered by tests. Times are UTC milliseconds (`core::Timestamp`), passed in by the caller so tests control them.

- [ ] Add to `IPromptRepository`: `create_prompt(const NewPrompt&) -> Id`, `get_prompt(Id) -> std::optional<Prompt>`, `update_prompt(const Prompt&)`, `delete_prompt(Id)`, `list_prompts(const PromptQuery&) -> std::vector<PromptSummary>` (folder filter, sort by title or updated). Define `NewPrompt`, `PromptQuery`, `PromptSummary` in `src/core/include/spellbook/core/domain.hpp`. Done when: the interface compiles and `SqlitePromptRepository` implements every method.
- [ ] Implement them in `src/storage/src/sqlite_prompt_repository.cpp` with bound parameters only. Done when: no SQL string in the file is built by concatenating user data. Cheaper substitute: `std::format` into SQL, which a reviewer must refuse.
- [ ] `update_prompt` on a missing id and `delete_prompt` on a missing id throw `StorageError` naming the id. Done when: a test asserts each message.
- [ ] Tests in `tests/storage/prompt_crud_tests.cpp`: create then get round-trips every field including non-ASCII text; update changes `updated_at` only as given; delete cascades `prompt_tags`; list filters by folder and sorts. Done when: `pwsh scripts/test.ps1 -Filter "storage: .*prompt"` passes.
- [ ] Commit: `"storage: prompt create, read, update, delete, and list"`

**Test checkpoint:** Unit test: the new `storage:` cases pass; `prompts_fts` finds an updated body and not the old one (proves the triggers fire through the repository path).

**Freeze check:** every write runs inside one statement or one transaction; a test that throws between two writes of `update_prompt` (through a failing trigger on a scratch table) leaves the row unchanged.

## 2. Folder Tree Operations in the Repository

Folders (Chapters) are hierarchical through `folders.parent_id`. Sibling names are unique case-insensitively (enforced by the schema's partial unique indexes).

- [ ] Add `create_folder`, `rename_folder`, `move_folder(Id, std::optional<Id> new_parent)`, `delete_folder(Id, FolderDelete mode)` (`mode`: move contents to parent, or delete contents), and `list_folders() -> std::vector<Folder>` to `IPromptRepository`. Done when: implemented in `SqlitePromptRepository`.
- [ ] `move_folder` refuses to move a folder into itself or a descendant, checked with a recursive CTE. Done when: a test asserts the refusal and that nothing moved.
- [ ] A duplicate sibling name surfaces as `StorageError` with a message naming the folder, translated from the SQLite constraint error. Done when: a test asserts the message.
- [ ] Tests in `tests/storage/folder_tests.cpp` cover create, rename, move, both delete modes, and the cycle refusal. Done when: they pass.
- [ ] Commit: `"storage: folder tree create, rename, move, delete, and list"`

**Test checkpoint:** Unit test: the folder cases pass, including deleting a folder that holds prompts in each mode and reading the prompts back.

## 3. LibraryService: Rules, Clock, and the Autosave Policy

Logic belongs in core (AGENTS.md), so the UI calls one service and never the repository directly. The service takes an `IPromptRepository&` and an `IClock&` so tests fake both.

- [ ] `src/core/include/spellbook/core/clock.hpp`: `IClock` with `now() -> Timestamp`, plus `SystemClock`. Done when: core still includes no Windows header (`check-layering.py` 0 findings).
- [ ] Move `IPromptRepository` to `src/core/include/spellbook/core/prompt_repository.hpp` so core services can depend on it without depending on storage; storage implements it. Done when: `check-layering.py` reports 0 findings and `docs/architecture.md` shows the interface in core.
- [ ] `src/core/include/spellbook/core/library_service.hpp`: `new_prompt(folder)`, `save_edit(id, title, body, description)`, `rename`, `move`, `remove`; a blank title becomes "Untitled spell" plus a number; titles are trimmed. Done when: unit tests in `tests/core/library_service_tests.cpp` cover each rule against a fake repository.
- [ ] `AutosavePolicy` in core: given edit and focus events with timestamps, says when to save (1000 ms after the last edit, immediately on focus loss or close, never for an unchanged buffer). Done when: tests drive it with a fake clock and assert every case.
- [ ] Commit: `"core: library service, clock, and the autosave policy"`

**Test checkpoint:** Unit test: `pwsh scripts/test.ps1 -Filter "core: .*(library|autosave)"` passes; a mutant that saves on every keystroke fails the debounce case.

## 4. The Vocabulary String Table

Every UI label comes from one table, so the themed words (Spell, Chapter, Sigil, Cast, Rune, Revisions, Import scrolls) can be switched to plain words (Prompt, Folder, Tag, Copy, Variable, History, Import text files) in settings, and every themed label has a tooltip with its plain meaning (`standards/ui.md`, "Theme vocabulary").

- [ ] `src/core/include/spellbook/core/vocabulary.hpp`: `enum class Term`, `enum class Vocabulary { Themed, Plain }`, `label(Term, Vocabulary) -> std::string_view`, `tooltip(Term) -> std::string_view`. Done when: every term in `standards/ui.md` has both labels and a tooltip.
- [ ] Tests in `tests/core/vocabulary_tests.cpp`: every `Term` has a non-empty themed label, plain label, and tooltip, and the plain labels contain no themed word. Done when: they pass.
- [ ] Commit: `"core: the vocabulary string table with themed and plain labels"`

**Test checkpoint:** Unit test: the vocabulary cases pass; adding a `Term` without labels fails the completeness case.

## 5. The Three-Pane Main Window

**Job:** the user can browse their chapters and spells and read or edit one spell.
**Treatment:** a TreeView (Chapters), a ListView in report mode (Spells: title, updated), and an editor pane (title edit, multi-line body edit, description edit) separated by draggable splitters, all sized in DIPs. Cheaper substitute that fails the checkpoint: a single list with a modal edit dialog.
**Chrome:** consume the vocabulary table (§4), the window's DPI helpers in `src/app/main_window.cpp`, and Common Controls v6. Do not invent a second label source or hard-code a pixel size.

- [ ] Split `src/app/main_window.cpp` into a layout pass and child panes (`src/app/panes/chapter_tree.cpp`, `spell_list.cpp`, `spell_editor.cpp`). Done when: each pane owns its HWND and handles its own notifications.
- [ ] Splitters persist their positions for the session (settings persistence lands in `D05 T01 §2`). Done when: dragging a splitter resizes both neighbours and the layout survives a DPI change.
- [ ] Keyboard: Tab and Shift+Tab cycle panes, F6 cycles too, arrow keys move in the tree and list, Enter opens the selected spell in the editor. Done when: every pane is reachable without a mouse.
- [ ] Every control on the surface is accounted for: working, or disabled with a tooltip naming its owner section. Done when: the section's evidence lists each.
- [ ] Commit: `"app: the three-pane main window"`

**Test checkpoint:** Driven run with evidence: with a dev database holding 3 folders and 20 prompts (seeded by a test fixture through `scripts/migrate.ps1`), the window shows all of them; captures at 100 and 150 percent committed under `docs/captures/library/`; the log records no error.

## 6. Create, Rename, Move, and Delete Commands

- [ ] Menu bar and accelerators: New spell (Ctrl+N), New chapter (Ctrl+Shift+N), Rename (F2), Delete (Del), Move to chapter (Ctrl+M). Done when: each runs `LibraryService` and the panes refresh.
- [ ] Delete asks for confirmation naming what and how many ("Delete the chapter 'Code' and its 12 spells?"); Del on a spell with an empty body skips the prompt. Done when: a driven run shows both. Cheaper substitute: a generic "Are you sure?".
- [ ] Drag a spell from the list onto a chapter in the tree to move it. Done when: the move is logged and the list refreshes.
- [ ] Every command writes one Information log line naming the action and the id (never the prompt text). Done when: a driven run's log shows them.
- [ ] Commit: `"app: create, rename, move, and delete commands"`

**Test checkpoint:** Driven run with evidence: create, rename, move, and delete a spell and a chapter; the database rows read back through `scripts/migrate.ps1` match; the log has one line per action.

**Job:** the user can file, rename, and remove spells and chapters.
**Treatment:** menu, accelerators, context menus on tree and list, and drag to move. Cheaper substitute that fails the checkpoint: buttons only.
**Chrome:** consume the vocabulary table for every menu label. Do not add a second command dispatcher.

## 7. Autosave Wiring and the Status Bar

- [ ] Wire `AutosavePolicy` (§3) to the editor: `EN_CHANGE` restarts a 1000 ms timer; `WM_KILLFOCUS`, selection change, and `WM_CLOSE` save at once. Done when: no path leaves the editor without a save.
- [ ] A status bar shows "Saved" with the time, "Saving...", or the error naming the reason. Done when: a forced failure (database opened read-only by a probe) shows the error and keeps the text in the editor.
- [ ] Commit: `"app: autosave and the status bar"`

**Test checkpoint:** Driven run with evidence: type into a spell, wait 1.5 s, kill the process with `Stop-Process -Force`; on relaunch the text is there.

**Freeze check:** a save that fails leaves the previous row intact and the editor dirty; the test for this forces `SQLITE_READONLY`.

**Job:** the user never presses Save and never loses text.
**Treatment:** debounced autosave plus a status bar line. Cheaper substitute that fails the checkpoint: saving only on close.
**Chrome:** consume `LibraryService::save_edit`. Do not write to the repository from the app layer.

## 8. The Library User Guide

- [ ] `docs/user/library.md`: chapters, spells, the editor, autosave, keyboard shortcuts, with the captures from §5. Done when: linked from `docs/user/README.md` and the README's Usage section.
- [ ] Update the README Features table rows for M1 from planned to working. Done when: the rows say what works.
- [ ] Commit: `"docs: the library user guide"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` prints `0 findings`.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] Every new public core and storage function has a named test
- [ ] `python scripts/todo-graph.py validate` clean
