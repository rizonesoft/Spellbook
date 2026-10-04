---
schema_version: 1
id: rich-runes-and-smart-editor
domain: 04-templates
status: draft
title: "TODO-02 -- Rich Runes, Spell Composition, and the Smart Editor"
depends_on: []
---

# TODO-02 -- Rich Runes, Spell Composition, and the Smart Editor

> **Goal:** Runes grow from plain blanks into a small, safe template language: choice lists, multi-line runes, and built-ins (`{{@clipboard}}`, `{{@date}}`, `{{@time}}`, `{{@selection}}`); one spell can include another (`{{> Spell title}}`) so shared preambles live once, with renames kept in step; the fill-in dialog gives each kind its proper control; and the editor highlights runes, includes, and Markdown, and shows word count and an offline token estimate.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** Nothing here exists. Operator decision 2026-10-04 (ADR 0003): rich runes, spell composition, and the smart editor are in v0.1.0. `D04 T01 §1` decided the base syntax: `{{name}}` is a rune, `{{name|default text}}` gives it a default, `{{{{` is a literal `{{`, and names are letters, digits, spaces, `_`, and `-`. This file extends it without changing any of that, using only characters a name cannot contain: a second `|` makes a choice (`{{tone|formal|casual}}`, the first option is the default; a literal bar inside a default or option is `\|`), `:long` makes a multi-line rune (`{{notes:long}}`, `{{notes:long|default}}`), an `@` prefix makes a built-in (`{{@clipboard}}`, `{{@date}}`, `{{@date:yyyy-MM-dd}}`, `{{@time}}`, `{{@selection}}`), and `>` makes an include (`{{> Spell title}}`). Built-ins are resolved by the app at cast time; `{{@selection}}` reuses the capture mechanism of `D03 T02 §2`.

## Inputs

- -> XREF: D04 T01 §1 -- the base parser this file extends
- -> XREF: D04 T01 §3 -- the fill-in dialog this file upgrades
- -> XREF: D03 T02 §2 -- the selection capture `{{@selection}}` reuses
- -> XREF: D01 T01 §5 -- the editor pane the smart editor replaces the body box of
- Microsoft Learn: `RichEditBox` and `ITextDocument` / `ITextRange` character formatting (WinUI 3); `ComboBox`; `CalendarDatePicker` is not used (dates are built-ins)
- -> XREF: D05 T04 §1 -- the starter grimoire demonstrates composition
- -> XREF: D06 T01 §1 -- Rune-ify must produce §1's syntax

## Outcome

- `parse_template` recognises every form above; malformed input stays literal and never throws; parse then render with every rune at its own literal text returns the input unchanged.
- Includes resolve recursively (depth 8), refuse cycles with a message, merge the included spells' runes into the fill-in dialog, and are rewritten when an included spell is renamed.
- The fill-in dialog shows a ComboBox for a choice, a multi-line box for a long rune, and read-only previews for built-ins.
- The editor colours runes, includes, built-ins, and Markdown headings, emphasis, and code; its footer shows words, characters, and "about N tokens".

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Rich rune syntax in the parser and renderer | D04 T01 §2 |  [ ]   |
|   2   |   §2    | Spell composition: includes, cycles, and rename tracking | §1, D01 T01 §3 |  [ ]   |
|   3   |   §3    | Built-ins at cast time and the upgraded fill-in dialog | §1, D04 T01 §4, D03 T02 §2 |  [ ]   |
|   4   |   §4    | The smart editor: highlighting and counts | §1, D01 T01 §7 |  [ ]   |
|   5   |   §5    | The rich runes and composition guide | §2, §3, §4 |  [ ]   |

---

## 1. Rich Rune Syntax in the Parser and Renderer

- [ ] Extend `src/core/include/spellbook/core/template.hpp`: a rune segment carries `kind` (`Text`, `Long`, `Choice`, `Builtin`, `Include`), `name`, `default_value`, `options`, and `format`; `runes()` lists user runes only (not built-ins or includes), unique, first-seen order, first definition wins. Done when: the existing `D04 T01` tests still pass unchanged.
- [ ] Grammar rules, each tested in `tests/core/template_rich_tests.cpp`: whitespace around `|` and `:` is trimmed; `\|` inside a default or option is a literal bar; `{{name|a}}` is a text rune with the default `a` and `{{name|a|b}}` a choice; an unknown `@name` or an unknown `:kind` is literal text; `{{> }}` with an empty title is literal. Done when: every rule has a case, including emoji in option text.
- [ ] `render()` takes a `RuneValues` map plus a `BuiltinProvider` interface (`clipboard()`, `selection()`, `now()`); a missing choice value uses the first option; includes render through an `IncludeResolver` interface (§2). Done when: tests with a fake provider and resolver cover each kind.
- [ ] Commit: `"core: rich runes: choices, long runes, built-ins, includes (D04 T02 §1)"`

**Test checkpoint:** Unit test: `pwsh scripts/test.ps1 -Filter "core: .*template"` passes, including the round trip over a 300-entry generated corpus.

## 2. Spell Composition: Includes, Cycles, and Rename Tracking

- [ ] `IncludeResolver` over the library: an include names a spell by exact title (case-insensitive, trimmed); not found or ambiguous renders a visible marker `[missing spell: <title>]` and is reported to the caller; recursion stops at depth 8; a cycle is refused with a message naming the chain (`A > B > A`). Done when: core tests cover found, missing, ambiguous, depth, and cycle.
- [ ] The fill-in dialog's rune list includes the runes of every included spell, deduplicated by name, in first-seen order. Done when: a test asserts the merged list for a spell including two others that share a rune.
- [ ] `LibraryService::rename` rewrites `{{> Old title}}` to `{{> New title}}` in every spell that includes it, in the same transaction, and returns the count; each rewritten spell gets a revision. Done when: storage and core tests assert the rewrite and that a failure changes nothing.
- [ ] Commit: `"core: spell composition with includes and rename tracking (D04 T02 §2)"`

**Test checkpoint:** Unit test: the composition cases pass; renaming a spell included by three others rewrites exactly three bodies (read back).

**Freeze check:** the rename rewrite runs in one transaction with the rename; a test forces a failure on the third rewrite and asserts the title and all three bodies are unchanged.

## 3. Built-ins at Cast Time and the Upgraded Fill-In Dialog

**Job:** the user can fill a rich template quickly and correctly.
**Treatment:** the fill-in dialog shows each user rune with the control its kind needs (TextBox; multi-line TextBox for `long`; ComboBox for a choice, editable so a one-off value is possible), lists built-ins as read-only rows with their current values, shows includes expanded in the live preview, and warns (InfoBar) about missing includes. `{{@selection}}` captures the selection of the window that was in front before Spellbook. Cheaper substitute that fails the checkpoint: every rune as a single-line text box.
**Chrome:** consume `render()`, the `BuiltinProvider` implemented in the app over the clipboard and capture code, and the dialog of `D04 T01 §3`. Do not add a second dialog.

- [ ] `src/app/builtin_provider.cpp`: clipboard text, the selection (through `D03 T02 §2`'s capture, without changing the clipboard), and local time; `{{@date}}` defaults to the user's short date format. Done when: each is shown in the dialog.
- [ ] The upgraded dialog with AutomationIds `rune-<name>` per field; Tab order follows rune order. Done when: a 12-rune mixed spell is usable at the native scale.
- [ ] `tests/ui/scenarios/rich-runes.ps1`: cast a spell with a choice, a long rune, `{{@date}}`, and an include; fill values; assert the clipboard equals `render()` of the same values with a fixed date injected through a test hook (`--fake-now <iso>`). Done when: it exits 0.
- [ ] Commit: `"app: built-ins and the rich fill-in dialog (D04 T02 §3)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario rich-runes` exits 0; a capture of the dialog under `docs/captures/rich-runes/`.

## 4. The Smart Editor: Highlighting and Counts

**Job:** the user can see the structure of a spell while writing it.
**Treatment:** the body becomes a `RichEditBox` that stores and autosaves plain text only, coloured from a core tokenizer: runes, built-ins, and includes in the accent colour (an include with a missing target underlined in the error colour), Markdown headings bold, `**emphasis**`, and `` `code` `` in a monospace face; a footer shows "N words, N characters, about N tokens". Typing stays smooth on a 20,000-character spell. Cheaper substitute that fails the checkpoint: a plain TextBox with a separate preview pane.
**Chrome:** consume `highlight_spans()` and `estimate_tokens()` from core, the theme resources for colours (legible in light and dark), and the existing `AutosavePolicy`. Do not store formatting in the database.

- [ ] `src/core/include/spellbook/core/highlight.hpp`: `highlight_spans(std::string_view) -> std::vector<Span>` (kind, UTF-16 offset, length) reusing the template lexer; `estimate_tokens(std::string_view) -> int` (the larger of characters / 4 and words x 1.33, rounded; documented as an estimate). Done when: tests cover each span kind, offsets with emoji (surrogate pairs), and the estimate on fixed samples.
- [ ] The editor applies spans incrementally (only the edited paragraph and its neighbours) on a 150 ms idle timer. Done when: a driven run types 2,000 characters into a 20,000-character spell with no keystroke taking longer than 50 ms (measured by the scenario through UIA event timestamps).
- [ ] `tests/ui/scenarios/smart-editor.ps1`: open a spell with every span kind, capture in light and dark (switching the app theme setting), type, assert the footer counts. Done when: it exits 0.
- [ ] Commit: `"core: highlighting and token estimate; app: the smart editor (D04 T02 §4)"`

**Test checkpoint:** Unit test plus driven run with evidence: the highlight tests pass and `pwsh scripts/drive.ps1 -Scenario smart-editor` exits 0 with captures under `docs/captures/smart-editor/`.

## 5. The Rich Runes and Composition Guide

- [ ] `docs/user/runes.md` gains choices, long runes, built-ins, includes, and the editor colours, every example also a case in `template_rich_tests.cpp`. Done when: linked from `docs/user/README.md`.
- [ ] `CHANGELOG.md` Unreleased lists rich runes, composition, and the smart editor. Done when: present.
- [ ] Commit: `"docs: rich runes, composition, and the smart editor (D04 T02 §5)"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` prints `0 findings`; a test asserts every fenced example in `runes.md` parses without a literal-fallback warning.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `pwsh scripts/drive.ps1 -Scenario rich-runes` and `smart-editor` exit 0
- [ ] `python scripts/todo-graph.py validate` clean
