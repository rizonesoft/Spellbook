---
schema_version: 1
id: capture-and-jump-list
domain: 03-find
status: draft
title: "TODO-02 -- Capture and the Jump List: Save a Selection from Any App, Cast from the Taskbar"
depends_on: []
---

# TODO-02 -- Capture and the Jump List: Save a Selection from Any App, Cast from the Taskbar

> **Goal:** A prompt found anywhere becomes a spell in two keystrokes: a capture hotkey copies the selection in the current app, restores the user's clipboard, and opens a small capture flyout with a suggested title, a chapter, and the source app already filled in. Right-clicking Spellbook on the taskbar lists favourite and recent spells, and choosing one casts it.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** Nothing here exists. Operator decision 2026-10-04 (ADR 0003): capture selection and a Jump List are in v0.1.0; cast-and-paste and a command palette were not chosen (backlog). `D03 T01 §6` builds the hotkey registration, the borderless topmost popup, and the notification-area icon this file reuses. Jump List entries launch `Spellbook.exe --cast <id>`, which `D01 T02 §1` forwards to the running instance. The installer's shortcuts carry the same AppUserModelID as the process (`D05 T02 §2`). The default capture hotkey is a **default**: Win+Shift+C, chosen because no Windows 11 shortcut documented on Microsoft Learn's "Keyboard shortcuts in Windows" page uses it; changing it costs one constant and a docs line, and Settings can rebind it.

## Inputs

- Microsoft Learn: `RegisterHotKey`, `SendInput`, `GetClipboardSequenceNumber`, `EnumClipboardFormats`, `GetForegroundWindow`, `QueryFullProcessImageNameW`, `GetFileVersionInfoW` (FileDescription)
- Microsoft Learn: `ICustomDestinationList`, `IShellLinkW`, `SetCurrentProcessExplicitAppUserModelID`, "Application User Model IDs (AppUserModelIDs)"
- Microsoft Learn: "App notifications" (`Microsoft.Windows.AppNotifications.AppNotificationManager`) for unpackaged apps
- -> XREF: D03 T01 §6 -- the hotkey, popup, and tray infrastructure
- -> XREF: D01 T02 §1 -- forwarding `--cast` and `--quick-search` to the running instance
- -> XREF: D01 T02 §3 -- the `source` field capture fills
- -> XREF: D04 T01 §4 -- Cast through the fill-in dialog, which a Jump List cast must use
- -> XREF: D05 T02 §2 -- installer shortcuts with the AppUserModelID
- -> XREF: D04 T02 §3 -- `{{@selection}}` reuses §2's capture
- -> XREF: D06 T01 §8 -- AI suggestions in the capture flyout

## Outcome

- Win+Shift+C (rebindable) captures the selected text of the foreground app without changing the user's clipboard, and a capture flyout saves it as a spell with its source.
- The taskbar Jump List shows up to five favourites and five recent spells plus the tasks New spell and Quick search; choosing a spell casts it (through the fill-in dialog when it has runes) and confirms with a silent notification.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Capture rules in core | D01 T02 §3 |  [ ]   |
|   2   |   §2    | The capture hotkey and flyout | §1, D03 T01 §6 |  [ ]   |
|   3   |   §3    | The Jump List | D01 T02 §1, D03 T01 §3, D04 T01 §4 |  [ ]   |
|   4   |   §4    | The capture and Jump List guide | §2, §3 |  [ ]   |

---

## 1. Capture Rules in Core

- [ ] `src/core/include/spellbook/core/capture.hpp`: `suggest_title(std::string_view text) -> std::string` (first non-blank line, Markdown heading marks and surrounding quotes stripped, collapsed whitespace, cut at a word boundary to 80 characters with an ellipsis, "Captured spell" when empty) and `describe_source(std::string_view app_name, std::string_view window_title) -> std::string` (`"<app> - <window title>"`, the title trimmed to 120 characters, the app alone when the title is empty or equals it). Done when: tests in `tests/core/capture_tests.cpp` cover each rule, emoji, CRLF, and a 10,000-character first line.
- [ ] Commit: `"core: capture title and source rules (D03 T02 §1)"`

**Test checkpoint:** Unit test: `pwsh scripts/test.ps1 -Filter "core: .*capture"` passes.

## 2. The Capture Hotkey and Flyout

**Job:** the user can save a prompt they are looking at in any app without leaving it.
**Treatment:** Win+Shift+C copies the selection in the foreground app, restores the user's clipboard, and shows a capture flyout near the cursor (borderless, topmost, like the quick-search popup): Title (from `suggest_title`), Chapter (the last chapter used for a capture; the first time, a chapter named "Captured", created on save), the text (editable), the source line, and Save (Enter) or Cancel (Esc). Nothing selected shows "Nothing selected in <app>" in the flyout for 2 s. Cheaper substitute that fails the checkpoint: capturing whatever is already on the clipboard.
**Chrome:** consume the hotkey registration and conflict reporting of `D03 T01 §6`, the popup window pattern, `LibraryService`, and the vocabulary table. Do not register a second notification-area icon.

- [ ] `src/app/capture.cpp`: on the hotkey, record the foreground window and its process; snapshot every HGLOBAL clipboard format (`EnumClipboardFormats`, skipping GDI-handle formats and keeping `CF_DIB`); wait up to 1 s for Win and Shift to be released; `SendInput` Ctrl+C; wait up to 600 ms for `GetClipboardSequenceNumber` to change; read `CF_UNICODETEXT`; restore the snapshot. Done when: a driven run proves the clipboard's text and an image format are unchanged after a capture.
- [ ] The flyout with AutomationIds `capture-flyout`, `capture-title`, `capture-chapter`, `capture-body`, `capture-save`; Save creates the spell with `source` from `describe_source` (app name from the executable's FileDescription) and logs one line with the new id. Done when: the spell reads back with all fields.
- [ ] Hotkey conflict (another app owns Win+Shift+C) is reported in the status bar and the log, and the Settings dialog (`D05 T01 §2`) can rebind it. Done when: a driven run that pre-registers the hotkey from a helper process sees the conflict message.
- [ ] `tests/ui/scenarios/capture.ps1`: put known text and an image on the clipboard, select a line in a helper window (a PowerShell WinForms TextBox titled "Capture source"), press the hotkey, save, assert the spell's title, body, and source via `dbread.py`, and assert the clipboard still holds the original text and image. Done when: it exits 0.
- [ ] Commit: `"app: the capture hotkey and flyout (D03 T02 §2)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario capture` exits 0; a capture of the flyout under `docs/captures/capture/`.

## 3. The Jump List

**Job:** the user can cast a favourite or recent spell from the taskbar.
**Treatment:** the Jump List (right-click the taskbar button) has a Favourites category (up to 5, by title) and a Recent category (up to 5, by last cast), and Tasks: New spell (`--new`) and Quick search (`--quick-search`). Choosing a spell runs `Spellbook.exe --cast <id>` (plus `--data-dir` for a portable or non-default copy), which the running instance casts: through the fill-in dialog when the spell has runes, otherwise straight to the clipboard with a silent notification "Cast '<title>' to the clipboard". Cheaper substitute that fails the checkpoint: Tasks only, no spells.
**Chrome:** consume `D01 T02 §1` forwarding, the cast path of `D04 T01 §4`, and the favourites and use data of `D03 T01 §3`. Do not cast from the second process.

- [ ] `SetCurrentProcessExplicitAppUserModelID(L"Rizonesoft.Spellbook")` at process start, before any window. Done when: `docs/architecture.md` records the AUMID and the installer section references it.
- [ ] `src/app/jump_list.cpp` with `ICustomDestinationList`: rebuilt on start and after a favourite toggle or a cast (debounced 2 s), honouring `GetRemovedDestinations`. Done when: the list matches the library after each change.
- [ ] The cast confirmation through `AppNotificationManager` (silent, expires in 5 s), falling back to the main window's InfoBar when notifications are off. Done when: both paths are shown.
- [ ] A diagnostic switch `--dump-jump-list` (honoured only with `SPELLBOOK_TEST_HOOKS=1`) prints the categories and each link's title and arguments as JSON, from the same data the app gives `ICustomDestinationList`. Done when: documented in `docs/dev/` and refused without the variable.
- [ ] `tests/ui/scenarios/jump-list.ps1`: favourite two spells and cast three; assert the dump lists the two favourites and the three recent spells in order with `--cast <id>` arguments; then run one link's command line exactly as the shell would and assert the clipboard text and the use count. Done when: it exits 0.
- [ ] Commit: `"app: the taskbar Jump List (D03 T02 §3)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario jump-list` exits 0; the dump lists the two favourites and the three recent spells in order.

## 4. The Capture and Jump List Guide

- [ ] `docs/user/find-and-cast.md` gains Capture and Jump List sections; the README shortcut table gains Win+Shift+C. Done when: `check-docs.py` is clean and the shortcut test of `D03 T01 §7` passes.
- [ ] `CHANGELOG.md` Unreleased lists both. Done when: present.
- [ ] Commit: `"docs: capture and the Jump List (D03 T02 §4)"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` prints `0 findings`.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `pwsh scripts/drive.ps1 -Scenario capture` and `jump-list` exit 0
- [ ] `python scripts/todo-graph.py validate` clean
