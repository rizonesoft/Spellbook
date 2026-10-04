---
schema_version: 1
id: ship-polish
domain: 05-ship
status: draft
title: "TODO-01 -- Polish: Dark Mode, Settings, Export, Backup, and Accessibility"
depends_on: []
frozen: true
---

# TODO-01 -- Polish: Dark Mode, Settings, Export, Backup, and Accessibility

> **Goal:** Spellbook feels finished: the whole window follows the Windows app mode, every tunable value lives in one settings dialog backed by an atomic settings file, the library can be exported to JSON and Markdown and restored from a JSON backup without loss, and every surface works with the keyboard and a screen reader.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** Only the title bar follows dark mode (`MainWindow::apply_theme` in `src/app/main_window.cpp`); the client area is painted with fixed colours. There is no settings file; `nlohmann-json` is in `vcpkg.json` and unused. No export or backup exists.

## Inputs

- Microsoft Learn: "Support Dark and Light themes in Win32 apps" (`DwmSetWindowAttribute`, the `DarkMode_Explorer` visual style for list and tree views, `WM_CTLCOLOR*`)
- -> XREF: D01 T01 §4 -- the vocabulary table whose Themed or Plain choice §2 persists
- -> XREF: D01 T02 §6 -- open tabs restored through the settings store
- -> XREF: D05 T03 §4 -- the Privacy page joins the Settings dialog
- -> XREF: D06 T01 §2 -- the AI settings join the Settings dialog
- -> XREF: D99 T01 §10 -- Narrator and high-contrast checks moved to the operator's pass

## Outcome

- Light and dark render correctly for every control at 100, 150, and 200 percent.
- `%LOCALAPPDATA%\Spellbook\settings.json` holds every setting, written atomically; each setting has a default, a consumer, and a log line when it changes.
- Export writes `spellbook-export-<date>.json` (lossless) and a Markdown folder (one file per prompt); Restore reads the JSON back into an empty or existing library with a preview.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Dark mode for every control | D01 T01 §5 |  [ ]   |
|   2   |   §2    | The settings store and the Settings dialog | §1 |  [ ]   |
|   3   |   §3    | Export to JSON and Markdown | D04 T01 §5 |  [ ]   |
|   4   |   §4    | Restore from a JSON backup | §3 |  [ ]   |
|   5   |   §5    | The accessibility pass | §2, D03 T01 §6 |  [ ]   |

---

## 1. Dark Mode for Every Control

- [ ] A `Theme` in `src/app/theme.cpp` with the palette for light and dark (values in `standards/ui.md`), applied to every pane: `SetWindowTheme(hwnd, L"DarkMode_Explorer", nullptr)` for tree and list views, `WM_CTLCOLOREDIT` and `WM_CTLCOLORSTATIC` for edits, owner-drawn splitters and status bar. Done when: a capture in dark mode shows no light control.
- [ ] Follows `WM_SETTINGCHANGE` "ImmersiveColorSet" live, and a setting (§2) can force light or dark. Done when: switching Windows app mode repaints without restart.
- [ ] Commit: `"app: dark mode for every control"`

**Test checkpoint:** Driven run with evidence: captures in light and dark at 150 percent under `docs/captures/theme/`.

**Job:** the user can work in the app mode they chose for Windows.
**Treatment:** full-window theming that follows the system. Cheaper substitute that fails the checkpoint: a dark title bar over light controls.
**Chrome:** consume one `Theme` object. Do not hard-code a colour in a pane.

## 2. The Settings Store and the Settings Dialog

- [ ] `src/core/include/spellbook/core/settings.hpp`: a typed `Settings` struct with defaults and JSON (nlohmann) load and save; unknown keys are kept, a corrupt file is renamed `settings.corrupt-<time>.json` and defaults are used with a warning. Done when: core tests cover defaults, round trip, unknown keys, and corruption.
- [ ] Atomic write: write `settings.json.tmp` in the same folder, flush, `ReplaceFileW` (or `MoveFileExW` with `MOVEFILE_REPLACE_EXISTING`) in the app layer. Done when: killing the process mid-write leaves the old file intact (driven probe).
- [ ] Settings dialog: vocabulary (Themed or Plain), theme (System, Light, Dark), hotkey, ANSI code page for import, autosave delay. Done when: each change logs one line and takes effect without restart.
- [ ] **Added 2026-10-04** (ADR 0003): "Start with Windows" (off by default; writes or removes `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` with `--background`; `D05 T02 §6` hides it for a portable copy), the capture hotkey (`D03 T02 §2`), and restoring the open tabs on start (`D01 T02 §6`, through `TabsHost::open_spell_ids()`). The dialog is a `NavigationView` of pages (General, Editor, Hotkeys, and later Privacy and AI) so `D05 T03 §4` and `D06 T01 §2` add pages without reshaping it. Done when: each setting persists, takes effect, and has an AutomationId.
- [ ] Commit: `"core: the settings store; app: the Settings dialog"`

**Test checkpoint:** Unit test plus driven run with evidence: switch to Plain; every menu and label reads Prompt, Folder, Tag; restart keeps it.

**Freeze check:** the settings write is atomic; the probe above proves it.

**Job:** the user can tune Spellbook in one place.
**Treatment:** one dialog over one file. Cheaper substitute that fails the checkpoint: registry values scattered per feature.
**Chrome:** consume `Settings` and the vocabulary table. Do not read settings anywhere but through the store.

## 3. Export to JSON and Markdown

- [ ] `src/core/include/spellbook/core/export.hpp`: a versioned JSON document (`"format": "spellbook-export", "version": 1`) with folders, prompts, tags, and revisions; Markdown export writes one `<title>.md` per prompt in folder paths, with front matter for tags and favourite. Done when: core tests round-trip a seeded library through JSON with every field equal.
- [ ] File > Export, with a folder picker and a summary. Done when: a driven run exports.
- [ ] Commit: `"core, app: export to JSON and Markdown"`

**Test checkpoint:** Round-trip proof: export a seeded library to JSON, import it into an empty database (§4's reader), export again; the two files are byte-identical.

## 4. Restore from a JSON Backup

- [ ] Restore reads an export, validates its format and version, previews counts, and writes in one transaction, merging into an existing library by skipping exact duplicates (the `D02 T01 §2` hash). Done when: tests cover an empty target, a merge, and a corrupt file refused with a message.
- [ ] Commit: `"core, storage, app: restore from a JSON backup"`

**Test checkpoint:** Round-trip proof as in §3, plus a driven run restoring into the dev database.

**Freeze check:** restore runs in one transaction; a failure mid-way leaves the library unchanged.

## 5. The Accessibility Pass

- [ ] Every control has an accessible name (labels, `SetWindowTextW` on unlabelled controls, or `IAccessible` names through `SetProp`/Dynamic Annotation where needed); focus is always visible; no action needs a mouse. Done when: `scripts/a11y-scan.ps1` (Axe.Windows CLI, pinned in `toolchain.json`) scans the main window, the popup, the fill-in dialog, and Settings with no error. **Corrected 2026-10-04:** an automated scanner replaces the Accessibility Insights FastPass a person would run; Narrator and the high-contrast look moved to `D99 T01 §10`.
- [ ] High contrast: system colours are used when `SPI_GETHIGHCONTRAST` is on. Done when: a capture in a high-contrast theme is committed.
- [ ] Commit: `"app: accessibility pass"`

**Test checkpoint:** Driven run with evidence: the Axe.Windows reports saved under `docs/captures/accessibility/` with zero errors, and `pwsh scripts/drive.ps1 -Scenario keyboard-only` completes create, find, and cast without a mouse event.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `python scripts/todo-graph.py validate` clean
