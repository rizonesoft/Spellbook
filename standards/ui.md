# UI Standard

How every Spellbook surface looks and behaves. Implementation mechanics live in the [WinUI patterns skill](../.claude/skills/winui-patterns/SKILL.md); this file is the shared product policy.

## Principles and controls

- **Native first.** Use WinUI 3 controls and their built-in interaction/accessibility behavior: `TreeView` for chapters, `ListView` for spell collections, `TextBox` for ordinary editing, `ContentDialog` for modal decisions, `NavigationView` for navigation, and `InfoBar` for suitable nonmodal feedback. A richer editor requires its own planned contract.
- **Keyboard complete.** Every action has a keyboard path; Tab order follows reading order; focus is visible and returns to a sensible location after a dialog or deletion.
- **Fast.** The target is an interactive window within 300 ms on the dev machine; measure it rather than claiming it from the framework. Typing must not wait for database work.
- **Plain meaning always available.** Themed copy decorates without obscuring the action.
- **Thin presentation.** XAML and presentation models adapt tested service results; they do not own business rules, SQL, or persistence decisions.

## DPI and layout

- The manifest declares Per-Monitor-V2 awareness. XAML layout and text use DIPs and scale automatically; use adaptive `Grid` layouts and theme typography rather than fixed pixel positions or manually rebuilt fonts.
- Spacing uses 4-DIP steps (4, 8, 12, 16, 24). The shell starts at 960 by 640 DIP with a minimum of 480 by 320 DIP. Its native `AppWindow` size/presenter bounds are physical pixels, so convert only at that boundary and refresh limits when the window's rasterization scale changes.
- Verify that keyboard focus, text, and all actions remain reachable at minimum size and the section's DPI/text scaling values. Review captures at 100 and 150 percent as a baseline; honor any larger matrix in the surface contract.
- Prefer WinUI type-ramp styles and content wrapping. Do not clip translated or enlarged text to preserve a decorative layout.

## Themes and window chrome

- Consume WinUI brushes and styles through `{ThemeResource}` so the surface responds to theme changes. Default follows Windows; an explicit light/dark setting uses supported `RequestedTheme` on the content root. D05 T01 §1 owns the complete app-wide policy and its proof.
- Use the platform's high-contrast resources. Any custom theme dictionary must supply meaningful light, dark, and high-contrast values, using the user's system contrast colors in the latter. Do not hard-code a dark palette into controls.
- The current shell uses `MicaBackdrop` and a custom title-bar region registered with `SetTitleBar`. Preserve caption-button clearance, dragging, icon, title, system menu, keyboard access, and an opaque fallback when backdrop support is unavailable.
- UIA peers provide each control's role, state, and supported interactions. Give every interactive control a stable `AutomationProperties.AutomationId` for driven tests, and a meaningful accessible name through content or `AutomationProperties.Name`/`LabeledBy`. An ID is not a spoken label. Shared driver and visual acceptance infrastructure is owned by D00 T03 §§4 and 9.

## Copy

- Sentence case for labels and menu items ("Import scrolls", not "Import Scrolls").
- Confirmations name what, how many, and the consequence: "Delete the folder 'Code' and its 12 prompts?"
- Errors name the action and the reason: "Spellbook could not save 'Code review': the database is read-only."
- No exclamation marks, no jokes in errors.
- Normal visible copy and tooltips come from app `.resw` resources. The pre-XAML startup failure fallback is a deliberate exception so a missing PRI can still be reported. Unattended smoke reports failure through logs/exit status and never opens a dialog.

## Theme vocabulary

Spellbook's UI and docs use a light magic flavour, sparingly. **Code, schema, and logs use the plain words.** Every themed label carries a tooltip with its plain meaning. App resources in `src/app/Strings/en-US/Resources.resw` own the text, including themed/plain pairs; a presentation adapter chooses and refreshes them using the persisted Settings choice (D01 T01 §4 and D05 T01 §2). This adapter does not move localized strings or WinRT into core. Fixed XAML copy uses `x:Uid`; it does not automatically implement runtime vocabulary switching.

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

## Dialogs and asynchronous work

`ContentDialog` is attached to the live content root's `XamlRoot`, and dialogs are serialized per UI thread. Await the result before a destructive service action; cancel leaves data unchanged. A long-running action exposes progress/cancellation and remains keyboard accessible. Marshal service results and property notifications onto the UI thread, discard obsolete results, and handle window closure without invoking dead controls.

## Every control is accounted for

A surface ships with every control working or disabled with a tooltip naming the section that will make it work. A control that does nothing and says nothing is a defect. Disabled controls still need discoverable explanations; use the supported disabled-tooltip behavior or a nearby accessible explanation.

## Keyboard shortcuts

Maintain one app command/shortcut definition used to wire WinUI `KeyboardAccelerator` instances and the README Keyboard Shortcuts list; D03 T01 §7 adds the consistency check. Respect text-editing shortcuts and scope accelerators so they do not unexpectedly consume ordinary input. Global hotkeys and tray integration remain deliberate native interop in their owning plan sections.

## Primary references

[WinUI theme resources](https://learn.microsoft.com/en-us/windows/apps/develop/platform/xaml/xaml-theme-resources), [contrast themes](https://learn.microsoft.com/en-us/windows/apps/design/accessibility/high-contrast-themes), [keyboard accelerators](https://learn.microsoft.com/en-us/windows/apps/develop/input/keyboard-accelerators), and [title bar customization](https://learn.microsoft.com/en-us/windows/apps/develop/title-bar?tabs=winui3) define platform behavior. Verify API availability against the pinned packages when a current Learn example differs from the installed projection.
