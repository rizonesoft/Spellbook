# UI Standard

How every Spellbook surface looks and behaves. The Win32 mechanics are in [`.claude/skills/win32-ui-patterns/SKILL.md`](../.claude/skills/win32-ui-patterns/SKILL.md); this file is the policy.

## Principles

- **Native first.** Standard Win32 and Common Controls v6, themed by the system. No custom-drawn imitation of a control Windows already has.
- **Keyboard complete.** Every action has a keyboard path; Tab order follows reading order; focus is always visible.
- **Fast.** The window is interactive within 300 ms of launch on the dev machine; typing never waits on the database.
- **Plain meaning always available.** Themed words decorate; they never hide what a control does.

## DPI and layout

- Per-Monitor-V2 (from the manifest). Every size is written in DIPs and scaled with `MulDiv(dip, dpi, 96)` at the window's DPI (`GetDpiForWindow`); `WM_DPICHANGED` rebuilds fonts and icons and applies the suggested rectangle.
- Fonts come from `SystemParametersInfoForDpi(SPI_GETNONCLIENTMETRICS)`, the message font; headings derive from it.
- Spacing grid: 4 DIP steps (4, 8, 12, 16, 24). Minimum window 480 by 320 DIP.
- Captures for review are taken at 100 and 150 percent.

## Themes

- Follow the Windows app mode (`AppsUseLightTheme`) and repaint on `WM_SETTINGCHANGE` "ImmersiveColorSet". M0 themes the title bar and the client background; M5 themes every control (`D05 T01 §1`).
- Dark palette (M0 values, kept until M5 replaces them with a `Theme`): background `#202020`, text `#F3F3F3`, secondary text `#A0A0A0`. Light uses the system colours (`COLOR_WINDOW`, `COLOR_WINDOWTEXT`) with secondary text `#5F5F5F`.
- High contrast: when `SPI_GETHIGHCONTRAST` is on, use system colours only.

## Copy

- Sentence case for labels and menu items ("Import scrolls", not "Import Scrolls").
- Confirmations name what, how many, and the consequence: "Delete the chapter 'Code' and its 12 spells?"
- Errors name the action and the reason: "Spellbook could not save 'Code review': the database is read-only."
- No exclamation marks, no jokes in errors.

## Theme vocabulary

Spellbook's UI and docs use a light magic flavour, sparingly. **Code, schema, and logs use the plain words.** Every themed label carries a tooltip with its plain meaning, and the Settings dialog (`D05 T01 §2`) switches every label to the plain column. All labels come from one string table in core (`D01 T01 §4`), never from string literals in the app layer.

| Code / domain | Themed UI label | Plain UI label | Tooltip (plain meaning) |
| ------------- | --------------- | -------------- | ----------------------- |
| Prompt | Spell | Prompt | A saved prompt |
| Folder | Chapter | Folder | A folder of prompts |
| Tag | Sigil | Tag | A tag you can filter by |
| Copy rendered text | Cast (Ctrl+Enter) | Copy (Ctrl+Enter) | Copy the prompt to the clipboard, with its variables filled in |
| Template variable | Rune (`{{name}}`) | Variable (`{{name}}`) | A placeholder filled in when you copy |
| Version history | Revisions | History | Earlier versions of this prompt |
| Import .txt files | Import scrolls | Import text files | Import prompts from .txt files |

Use the theme in labels, headings, and empty states. Do not use it in error messages, confirmations of destructive actions, or anything a user must understand under stress: those say "prompt" and "folder" in either mode.

## Every control is accounted for

A surface ships with every control working or disabled with a tooltip naming the section that will make it work. A control that does nothing and says nothing is a defect.

## Keyboard shortcuts

Shortcuts are listed in one accelerator table in `src/app/` and in the README's Keyboard Shortcuts section, and the two must match (`D03 T01 §7` adds the check).
