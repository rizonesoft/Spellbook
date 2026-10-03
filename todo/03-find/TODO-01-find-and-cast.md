---
schema_version: 1
id: find-and-cast
domain: 03-find
status: draft
title: "TODO-01 -- Find and Cast: Search, Sigils, Favourites, the Clipboard, and the Quick-Search Popup"
depends_on: []
---

# TODO-01 -- Find and Cast: Search, Sigils, Favourites, the Clipboard, and the Quick-Search Popup

> **Goal:** Any prompt is two seconds away from anywhere in Windows: a global hotkey summons a quick-search popup, typing filters by full-text search as you type, Enter copies the prompt (Cast) and dismisses the popup. In the main window the same search, tags (Sigils), favourites, and sorting by recent and most used find what the user needs without knowing where it was filed.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** `prompts_fts` (FTS5, unicode61 with diacritics removed) is created and kept in step by triggers (`migrations/0001_init.sql`), and `storage: FTS5 indexes prompts through the triggers` proves it. `tags`, `prompt_tags`, `is_favorite`, `use_count`, and `last_used_at` exist in schema 1 with no code using them. There is no clipboard code, no hotkey, and no popup window.

## Inputs

- SQLite FTS5 documentation (https://sqlite.org/fts5.html): query syntax, `bm25()`, `snippet()`, prefix queries
- Microsoft Learn: `RegisterHotKey`, `OpenClipboard` / `SetClipboardData(CF_UNICODETEXT)`, `SetForegroundWindow` rules
- -> XREF: D04 T01 §4 -- Cast of a template opens the fill-in dialog this file's copy path hands to

## Outcome

- Search is instant (under 50 ms for 10,000 prompts on the dev machine) and safe: any text the user types is a valid query.
- Tags can be created, renamed, deleted, and assigned; the list filters by tag and favourites.
- Cast (Ctrl+Enter) copies the prompt as Unicode text and records the use.
- Win+Shift+Space (configurable in `D05 T01 §2`) opens the popup over any app; Esc dismisses it and returns focus.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | The search query builder and ranked search | D01 T01 §1 |  [ ]   |
|   2   |   §2    | Tags (Sigils): storage, service, and assignment UI | D01 T01 §6 |  [ ]   |
|   3   |   §3    | Favourites, use tracking, and sort modes | D01 T01 §6 |  [ ]   |
|   4   |   §4    | The search box and filters in the main window | §1, §2, §3 |  [ ]   |
|   5   |   §5    | Cast: copy to the clipboard | §3 |  [ ]   |
|   6   |   §6    | The global hotkey and the quick-search popup | §4, §5 |  [ ]   |
|   7   |   §7    | Keyboard shortcuts and the find guide | §6 |  [ ]   |

---

## 1. The Search Query Builder and Ranked Search

User input is never passed to `MATCH` raw: an unbalanced quote or a bare `-` is an FTS5 syntax error. The builder tokenises the input and emits each term as a quoted prefix query (`"cod"*`), joined by AND.

- [ ] `src/core/include/spellbook/core/search_query.hpp`: `build_fts_query(std::string_view user_text) -> std::string`. Done when: tests cover quotes, `-`, `*`, `NEAR`, `AND`/`OR` typed as words, emoji, and empty input (which means "no filter").
- [ ] `search(const SearchRequest&) -> std::vector<SearchHit>` on the repository: ranked by `bm25(prompts_fts, 10.0, 1.0, 2.0)` (title weighted highest), with `snippet()` for the body, folder and tag filters, limit and offset. Done when: tests assert ranking order on a seeded set.
- [ ] A benchmark test seeds 10,000 prompts and asserts a search returns in under 50 ms in Release. Done when: it passes under `pwsh scripts/test.ps1 -Config Release -Filter perf`.
- [ ] Commit: `"core: the safe FTS5 query builder; storage: ranked search with snippets"`

**Test checkpoint:** Unit test: the query-builder and search cases pass; every string in a 200-entry fuzz list builds a query FTS5 accepts.

## 2. Tags (Sigils): Storage, Service, and Assignment UI

- [ ] Repository: `create_tag`, `rename_tag`, `delete_tag`, `list_tags`, `set_prompt_tags(Id, std::span<const Id>)`. Done when: storage tests cover each and the case-insensitive uniqueness.
- [ ] Editor pane gains a tag field with autocomplete over existing tags; Enter adds, Backspace on empty removes the last. Done when: a driven run assigns three tags and they read back.
- [ ] Commit: `"storage, app: sigils (tags) and their assignment"`

**Test checkpoint:** Driven run with evidence: tag two prompts, filter the list by the tag, see exactly those two.

**Job:** the user can label spells across chapters and filter by label.
**Treatment:** a token field in the editor and a Sigils node in the tree. Cheaper substitute that fails the checkpoint: a comma-separated text box.
**Chrome:** consume the vocabulary table (Sigil / Tag). Do not add a second list control style.

## 3. Favourites, Use Tracking, and Sort Modes

- [ ] Repository: `set_favorite(Id, bool)`, `record_use(Id, Timestamp)` (increments `use_count`, sets `last_used_at`), and sort keys title, updated, last used, most used. Done when: storage tests cover each.
- [ ] Main window: a star toggle (Ctrl+D) and a Favourites node; a sort menu. Done when: a driven run shows each sort order.
- [ ] Commit: `"storage, app: favourites, use tracking, and sort modes"`

**Test checkpoint:** Unit test plus driven run: record three uses out of order; "Most used" and "Recent" show the expected order.

**Job:** the user can keep the spells they use most at hand.
**Treatment:** star toggle, Favourites node, sort menu. Cheaper substitute that fails the checkpoint: a favourites folder the user maintains by hand.
**Chrome:** consume the vocabulary table. Do not store favourites outside the `is_favorite` column.

## 4. The Search Box and Filters in the Main Window

- [ ] A search box above the list (Ctrl+F or Ctrl+K focuses it) filters as you type, debounced to 100 ms; matches show the snippet. Done when: a driven run filters 10,000 seeded prompts without a visible stall.
- [ ] Clearing the box (Esc) restores the chapter view. Done when: shown.
- [ ] Commit: `"app: search as you type with snippets"`

**Test checkpoint:** Driven run with evidence: the capture shows the snippet highlighting; the log records no error.

**Job:** the user can find a spell by any word in it.
**Treatment:** an incremental search box with snippets. Cheaper substitute that fails the checkpoint: a Find dialog with a Search button.
**Chrome:** consume `search()` from §1. Do not filter in the UI layer.

## 5. Cast: Copy to the Clipboard

- [ ] `src/app/clipboard.cpp`: `copy_text(HWND, std::string_view utf8)` with `CF_UNICODETEXT`, retrying `OpenClipboard` briefly when another app holds it. Done when: a driven run pastes the exact text, emoji included, into Notepad.
- [ ] Cast (Ctrl+Enter, a toolbar button, and the context menu) copies the body, records the use, and shows "Cast to the clipboard" in the status bar. Done when: `use_count` increments.
- [ ] A prompt containing `{{runes}}` is cast as plain text until `D04 T01 §4` routes it to the fill-in dialog. Done when: noted in the status bar text.
- [ ] Commit: `"app: cast a spell to the clipboard"`

**Test checkpoint:** Driven run with evidence: cast a prompt with CRLF-sensitive text and emoji; the pasted text in Notepad matches the stored body (LF expanded to CRLF on copy, nothing else changed).

**Job:** the user can put a spell on the clipboard in one keystroke.
**Treatment:** Ctrl+Enter, plus button and menu. Cheaper substitute that fails the checkpoint: select-all and Ctrl+C in the editor.
**Chrome:** consume `copy_text`. Do not open the clipboard anywhere else.

## 6. The Global Hotkey and the Quick-Search Popup

- [ ] Register Win+Shift+Space with `RegisterHotKey` (MOD_NOREPEAT); a conflict is reported in the status bar and the log, never silently. Done when: a driven run shows both the working and the conflict path.
- [ ] A borderless, topmost popup centred on the monitor under the cursor: a search box and a results list, keyboard only (Up, Down, Enter casts and closes, Esc closes). Done when: focus returns to the previous window after closing.
- [ ] Spellbook keeps running in the notification area when the main window closes, so the hotkey works; a tray menu offers Open and Exit. Done when: closing the window leaves the hotkey live, Exit ends the process.
- [ ] Commit: `"app: the global hotkey and the quick-search popup"`

**Test checkpoint:** Driven run with evidence: from Notepad, press the hotkey, type three letters, Enter, Ctrl+V; the prompt is pasted and Notepad has focus again.

**Job:** the user can summon any spell from any app without switching windows.
**Treatment:** a global hotkey, a keyboard-only popup, and a tray icon. Cheaper substitute that fails the checkpoint: bringing the main window to the front.
**Chrome:** consume `search()` and `copy_text`. Do not create a second search implementation for the popup.

## 7. Keyboard Shortcuts and the Find Guide

- [ ] `docs/user/find-and-cast.md` and the README's Keyboard Shortcuts table cover every shortcut this file adds. Done when: `check-docs.py` is clean and the tables match the accelerator table in code.
- [ ] Commit: `"docs: the find and cast guide and the shortcut table"`

**Test checkpoint:** Static evidence: every accelerator in `src/app/` appears in the README table (a test greps both).

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `python scripts/todo-graph.py validate` clean
