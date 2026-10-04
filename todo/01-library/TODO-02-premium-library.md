---
schema_version: 1
id: premium-library
domain: 01-library
status: draft
title: "TODO-02 -- The Premium Library: Single Instance, Trash, Spell Metadata, and Tabs"
depends_on: []
frozen: true
---

# TODO-02 -- The Premium Library: Single Instance, Trash, Spell Metadata, and Tabs

> **Goal:** The library feels like a finished product: one Spellbook runs per data folder and every later launch, file, or Jump List entry is forwarded to it; deleting never destroys (a Trash keeps deleted spells and chapters for 30 days, with Undo and Restore); each spell carries searchable metadata (target model, source, notes, rating); and several spells open side by side in tabs, each autosaving on its own.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** Nothing here exists. Operator decision 2026-10-04 (ADR 0003): Trash with restore, spell metadata, and tabs are in v0.1.0. `D01 T01` builds the repository CRUD, `LibraryService`, the three-pane window, the commands, and autosave that this file extends; deleting there is a hard delete with a confirmation, which §4 here turns into Move to Trash. Schema 1 (`migrations/0001_init.sql`) has no `deleted_at` or metadata columns. The app is moving to WinUI 3 (`D00 T02`), so every surface here is written in WinUI terms; the `winui-patterns` skill (`.claude/skills/winui-patterns/SKILL.md`, from `D00 T02 §5`) is the pattern source. Migration numbers are taken in execution order: each migration here is "the next free number" when its section runs.

## Inputs

- [`../../migrations/0001_init.sql`](../../migrations/0001_init.sql) -- the tables the migrations here extend
- [`../../standards/ui.md`](../../standards/ui.md) -- vocabulary, keyboard, AutomationIds
- `.claude/skills/add-migration/SKILL.md` and `.claude/skills/add-feature/SKILL.md` -- the procedures for the storage and surface work
- Microsoft Learn: "App instancing with the app lifecycle API" (`Microsoft.Windows.AppLifecycle.AppInstance.FindOrRegisterForKey`, `RedirectActivationToAsync`) -- single instance for unpackaged apps
- Microsoft Learn: `TabView`, `RatingControl`, `InfoBar` (WinUI 3)
- -> XREF: D01 T01 §6 -- the delete command §4 turns into Move to Trash
- -> XREF: D03 T01 §1 -- search must exclude trashed spells and include the metadata §3 indexes
- -> XREF: D05 T01 §2 -- the settings store persists the open tabs §6 restores
- -> XREF: D02 T02 §2 -- opening a `.spell` file is forwarded through §1
- -> XREF: D03 T02 §2 -- the Jump List's entries are forwarded through §1
- -> XREF: D06 T01 §6 -- Write from a description opens its draft in a tab

## Outcome

- A second launch with the same data folder forwards its arguments to the first and exits; a portable copy and an installed copy can run side by side.
- Delete moves to Trash with an Undo bar; the Trash node lists, restores, and permanently deletes; items older than 30 days are purged on start, logged by count.
- Target model, source, notes, and rating are edited in a Details panel, autosaved, and searchable.
- Spells open in tabs; each tab autosaves independently; Ctrl+W, Ctrl+Tab, and Ctrl+1 to Ctrl+9 work.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Single instance and command-line forwarding | D01 T01 §5 |  [ ]   |
|   2   |   §2    | Trash in storage and core | D01 T01 §3 |  [ ]   |
|   3   |   §3    | Spell metadata in storage and core | §2 |  [ ]   |
|   4   |   §4    | The Trash surface and Move to Trash | §2, D01 T01 §6 |  [ ]   |
|   5   |   §5    | The Details panel: metadata in the editor | §3, D01 T01 §7 |  [ ]   |
|   6   |   §6    | Tabs | D01 T01 §7 |  [ ]   |
|   7   |   §7    | The premium library guide | §1, §4, §5, §6 |  [ ]   |

---

## 1. Single Instance and Command-Line Forwarding

Every later entry point (double-clicking a `.spell` file, a Jump List entry, the capture hotkey, a second Start menu click) must reach the running Spellbook instead of opening a second window over the same database. The instance key includes the data folder, so a portable copy and an installed copy are separate instances.

- [ ] `src/core/include/spellbook/core/command_line.hpp`: `parse_command_line(std::span<const std::string>) -> CommandLine` with `data_dir`, `smoke`, `open_file` (a path), `open_spell` (`--open <id>`), `cast_spell` (`--cast <id>`), `new_spell` (`--new`), `quick_search` (`--quick-search`), and `errors` for unknown or malformed arguments. Done when: tests in `tests/core/command_line_tests.cpp` cover each, quoting, and a bad id.
- [ ] `src/app/instance.cpp`: key `spellbook-` plus the first 16 hex digits of a SHA-256 of the canonical data-folder path; the second instance calls `RedirectActivationToAsync` with its arguments and exits 0; the first instance's `Activated` handler parses them with `parse_command_line` and acts (bring the window forward, then open, cast, or start a new spell). `--smoke` never redirects. Done when: a second launch brings the first window forward within 1 s.
- [ ] Every forwarded action writes one Information log line naming the action and any id. Done when: the driven run's log shows them.
- [ ] Commit: `"core, app: single instance and command-line forwarding (D01 T02 §1)"`

**Test checkpoint:** Unit test: `pwsh scripts/test.ps1 -Filter "core: .*command line"` passes. Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario single-instance` starts Spellbook, runs `Spellbook.exe --data-dir <same> --open <id>` as a second process, asserts that process exits 0 within 2 s, that only one Spellbook window exists, and that the spell list's selection is `<id>`.

## 2. Trash in Storage and Core

Deleting a user's prompt is the most destructive thing the app does, so it stops being immediate. A trashed spell or chapter keeps every row (body, tags, revisions) until it is restored, emptied, or 30 days old.

- [ ] The next free migration (`migrations/NNNN_trash.sql`): `deleted_at INTEGER NULL` and `trash_batch INTEGER NULL` on `prompts` and `folders`, with indexes; nothing else changes. Done when: `storage: migrate takes a new database to the latest version` passes and a database from the previous version upgrades with every prompt intact.
- [ ] Repository: `trash_prompt(Id, Timestamp)`, `trash_folder(Id, Timestamp)` (the folder and its whole subtree share one `trash_batch`), `restore(TrashItem)` (a batch restores together; a missing or trashed parent restores the item to the root and says so in the result), `list_trash() -> std::vector<TrashItem>`, `purge_trash(Timestamp older_than) -> count`, `empty_trash() -> count`, each in one transaction; every existing read (`list_prompts`, `list_folders`, `get_prompt`, counts) excludes trashed rows. Done when: storage tests cover each, including a nested folder restored as a unit.
- [ ] `LibraryService::remove` trashes instead of deleting; `LibraryService::purge_expired(now)` purges items older than 30 days. Done when: core tests with a fake clock assert the 30-day boundary (29 days 23 hours kept, 30 days purged).
- [ ] Commit: `"storage, core: trash, restore, and purge (D01 T02 §2)"`

**Test checkpoint:** Unit test: the trash cases pass under `pwsh scripts/test.ps1 -Filter "(storage|core): .*trash"`.

**Freeze check:** `purge_trash` and `empty_trash` delete only rows with `deleted_at` set, in one transaction; a test seeds live and trashed rows, purges, and asserts every live row and its tags and revisions are untouched.

## 3. Spell Metadata in Storage and Core

Metadata turns a pile of text into a library: which model a spell is for, where it came from, what to remember about it, and how good it is. Notes are searchable.

- [ ] The next free migration (`migrations/NNNN_spell_metadata.sql`): `target_model TEXT`, `source TEXT`, `notes TEXT`, `rating INTEGER NOT NULL DEFAULT 0 CHECK (rating BETWEEN 0 AND 5)` on `prompts`; rebuild `prompts_fts` to index `title`, `body`, `description`, and `notes` with its triggers, and repopulate it inside the migration. Done when: an upgraded fixture database finds a word that only appears in a note.
- [ ] Domain and repository: the four fields on `Prompt` and `PromptSummary` (rating and target model), read and written by the existing CRUD; `list_target_models() -> std::vector<std::string>` (distinct, most used first). Done when: storage tests round-trip each field with non-ASCII text.
- [ ] Commit: `"storage, core: spell metadata, searchable notes (D01 T02 §3)"`

**Test checkpoint:** Unit test: the metadata cases pass; a search for a note-only word returns the spell (asserted through the FTS table directly until `D03 T01 §1` ships `search`).

**Freeze check:** the migration's FTS rebuild keeps every existing prompt findable by title and body: a test upgrades a fixture with 50 prompts and asserts each is found by a word from its body.

## 4. The Trash Surface and Move to Trash

**Job:** the user can delete without fear and get anything back for 30 days.
**Treatment:** Delete moves to Trash at once with an InfoBar ("Moved 'Code review' to Trash", Undo, auto-dismiss after 8 s); a Trash node at the bottom of the tree with a count; in Trash the list shows deleted date and original chapter, and the commands are Restore, Delete permanently, and Empty Trash (the last two confirm with what and how many). Cheaper substitute that fails the checkpoint: keeping the confirmation dialog and hard delete.
**Chrome:** consume the vocabulary table, the existing list and tree templates, and the theme resources. Do not invent a second list control for Trash.

- [ ] Rewire Delete (Del, menu, context menu) to `LibraryService::remove` with the Undo InfoBar; Undo calls `restore`. Done when: Del then Undo leaves the library as it was, read back.
- [ ] The Trash node and view with Restore (Ctrl+Z inside Trash too), Delete permanently, and Empty Trash; AutomationIds `trash-node`, `trash-restore`, `trash-delete-permanently`, `trash-empty`. Done when: every command works on spells and chapters.
- [ ] On start, `purge_expired` runs and logs "Purged N items older than 30 days from Trash" when N > 0. Done when: a seeded 31-day-old item is gone after a launch.
- [ ] `tests/ui/scenarios/trash.ps1`: delete a spell and a chapter of three spells, undo the spell, open Trash, restore the chapter, empty Trash after re-deleting one spell; assert rows via `tests/ui/dbread.py` after each step; capture the Trash view. Done when: `pwsh scripts/drive.ps1 -Scenario trash` exits 0.
- [ ] Commit: `"app: move to Trash, undo, and the Trash view (D01 T02 §4)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario trash` exits 0; the capture is under `docs/captures/trash/`; the log has one line per action.

## 5. The Details Panel: Metadata in the Editor

**Job:** the user can record what a spell is for, where it came from, and how well it works.
**Treatment:** a collapsible Details panel under the body: Target model (an editable ComboBox suggesting Claude, ChatGPT, Gemini, Copilot, Any, and every model already used), Source (text; a URL shows an Open link), Notes (multi-line), Rating (`RatingControl`, clearable); collapsed state remembered for the session; the spell list gains an optional Model column. Cheaper substitute that fails the checkpoint: a single free-text "metadata" box.
**Chrome:** consume `AutosavePolicy` exactly as the body does, the vocabulary table, and the theme resources. Do not add a Save button.

- [ ] The panel with AutomationIds `details-toggle`, `details-model`, `details-source`, `details-notes`, `details-rating`; every field autosaves through the existing policy. Done when: editing each field and switching spells persists it.
- [ ] The Model column (off by default, toggled from the list's header context menu). Done when: shown in a capture.
- [ ] `tests/ui/scenarios/details.ps1`: set all four fields, switch spell, kill the process 1.5 s later, relaunch, assert the values via the UI and `dbread.py`. Done when: it exits 0.
- [ ] Commit: `"app: the Details panel for spell metadata (D01 T02 §5)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario details` exits 0; captures under `docs/captures/details/`.

## 6. Tabs

**Job:** the user can work on several spells at once without losing their place.
**Treatment:** a `TabView` hosts the editor: Enter or a single click opens a spell in the current tab; Ctrl+click, middle-click, or "Open in new tab" opens another; Ctrl+W closes (saving first), Ctrl+Tab and Ctrl+Shift+Tab cycle, Ctrl+1 to Ctrl+8 jump, Ctrl+9 goes to the last; the tab header shows the title and a saving dot; a trashed spell's tab closes itself. Cheaper substitute that fails the checkpoint: a recent-spells dropdown.
**Chrome:** consume the editor pane from `D01 T01 §5` unchanged inside each tab, one `AutosavePolicy` per tab. Do not duplicate the editor's code per tab.

- [ ] `TabView` in the editor area, AutomationIds `tabs` and `tab-<spell id>`; every shortcut above. Done when: each works.
- [ ] Each tab owns its `AutosavePolicy`; closing a tab or the window saves every dirty tab. Done when: two tabs edited within 1 s of each other both persist after a kill 1.5 s later.
- [ ] The open tab list is handed to the settings store when it exists (`D05 T01 §2` restores it on start); until then tabs last for the session. Done when: the hand-off point is one function, `TabsHost::open_spell_ids()`.
- [ ] `tests/ui/scenarios/tabs.ps1`: open three spells in tabs, edit two, cycle and close with shortcuts, kill and relaunch, assert both edits via `dbread.py`. Done when: it exits 0.
- [ ] Commit: `"app: tabs with independent autosave (D01 T02 §6)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario tabs` exits 0; a capture with three tabs under `docs/captures/tabs/`.

## 7. The Premium Library Guide

- [ ] `docs/user/library.md` gains Trash, Details, and Tabs sections with the captures; the README Features table lists them. Done when: linked from `docs/user/README.md`.
- [ ] `CHANGELOG.md` Unreleased lists Trash, metadata, tabs, and single instance. Done when: present.
- [ ] Commit: `"docs: trash, details, and tabs in the library guide (D01 T02 §7)"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` prints `0 findings`.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `pwsh scripts/drive.ps1 -Scenario single-instance`, `trash`, `details`, and `tabs` each exit 0
- [ ] `python scripts/todo-graph.py validate` clean
