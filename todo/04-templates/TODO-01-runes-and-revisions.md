---
schema_version: 1
id: runes-and-revisions
domain: 04-templates
status: draft
title: "TODO-01 -- Runes and Revisions: Templates, the Fill-In Dialog, Version History, and Diff"
depends_on: []
frozen: true
---

# TODO-01 -- Runes and Revisions: Templates, the Fill-In Dialog, Version History, and Diff

> **Goal:** A prompt can carry `{{name}}` placeholders (Runes) with optional defaults; casting it opens a fill-in dialog with one field per rune, previews the rendered text, and copies the result. Every saved edit keeps the previous text as a revision, and any two revisions can be compared side by side and restored.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** `core::TemplateVariable` exists (`src/core/include/spellbook/core/domain.hpp`) with no parser. `prompt_versions` exists in schema 1 with no writer. Cast copies plain text (`D03 T01 §5`).

## Inputs

- -> XREF: D03 T01 §5 -- the Cast path this file routes through the fill-in dialog

## Outcome

- The rune syntax is decided, documented, and parsed in core with full test coverage.
- Cast on a prompt with runes opens the dialog; Ctrl+Enter in the dialog copies the rendered text.
- Each save that changes text writes a revision; History lists them; Compare shows a line diff; Restore makes an old revision current (itself recorded as a new revision).

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | The rune syntax and the template parser | D00 T01 §3 |  [ ]   |
|   2   |   §2    | The renderer | §1 |  [ ]   |
|   3   |   §3    | The fill-in dialog | §2, D01 T01 §5 |  [ ]   |
|   4   |   §4    | Cast through the fill-in dialog | §3, D03 T01 §5 |  [ ]   |
|   5   |   §5    | Revisions: written on save, listed, restored | D01 T01 §7 |  [ ]   |
|   6   |   §6    | The line diff and the Compare view | §5 |  [ ]   |
|   7   |   §7    | The runes and revisions guide | §4, §6 |  [ ]   |

---

## 1. The Rune Syntax and the Template Parser

A justified default, recorded with its cost of changing: `{{name}}` is a rune; `{{name|default text}}` gives it a default; `{{{{` is a literal `{{`. Names are letters, digits, spaces, `_`, and `-`, trimmed and compared case-insensitively, so `{{ Topic }}` and `{{topic}}` are one rune. The default is the text after the first `|`. Changing the syntax later means a migration of stored bodies, so it is decided here and documented in `docs/user/runes.md`.

- [ ] `src/core/include/spellbook/core/template.hpp`: `parse_template(std::string_view) -> ParsedTemplate` (literal and rune segments, in order) and `runes(const ParsedTemplate&) -> std::vector<TemplateVariable>` (unique, first-seen order, first default wins). Done when: it compiles in core.
- [ ] Malformed input never throws: an unclosed `{{` is literal text, an empty name is literal text. Done when: tests cover each.
- [ ] Tests in `tests/core/template_tests.cpp`: basic, repeated, defaults, escapes, whitespace, unicode names, unclosed, nested braces. Done when: they pass.
- [ ] Commit: `"core: the rune syntax and the template parser"`

**Test checkpoint:** Unit test: the template cases pass; parse then render with every rune at its own literal text returns the input unchanged (round trip).

## 2. The Renderer

- [ ] `render(const ParsedTemplate&, const std::map<std::string, std::string>& values) -> std::string`: missing values use the default, else stay as `{{name}}`. Done when: tests cover each case.
- [ ] Commit: `"core: render a template from rune values"`

**Test checkpoint:** Unit test: the render cases pass.

## 3. The Fill-In Dialog

**Job:** the user can fill in a spell's runes and see the result before casting.
**Treatment:** a modal dialog with one labelled edit per rune (prefilled with its default), a read-only live preview, and Cast and Cancel; Tab order follows rune order. Cheaper substitute that fails the checkpoint: one prompt box per rune in sequence.
**Chrome:** consume the vocabulary table (Rune / Variable), the DPI helpers, and `render()`. Do not render in the app layer.

- [ ] `src/app/dialogs/fill_in_dialog.cpp` with controls created at runtime per rune, scrolling past eight. Done when: a driven run with 12 runes is usable at 150 percent.
- [ ] Remember the last values per prompt for the session. Done when: reopening the dialog prefills them.
- [ ] Commit: `"app: the rune fill-in dialog"`

**Test checkpoint:** Driven run with evidence: a capture of the dialog for a three-rune prompt, and the preview text matching `render()` for the same values (asserted in a core test with the same inputs).

## 4. Cast Through the Fill-In Dialog

- [ ] Cast (main window and popup) on a prompt with runes opens the dialog; on a prompt without runes it copies directly. Done when: both paths are shown in a driven run.
- [ ] Ctrl+Shift+Enter casts the raw template text. Done when: shown.
- [ ] Commit: `"app: cast runes through the fill-in dialog"`

**Test checkpoint:** Driven run with evidence: from the popup, cast a rune prompt, fill two values, paste into Notepad; the pasted text equals `render()` of those values.

## 5. Revisions: Written on Save, Listed, Restored

- [ ] On a save that changes title, body, or description, the repository writes the previous text to `prompt_versions` with the next `version_no`, in the same transaction as the update. Done when: a storage test proves both rows change together or neither does.
- [ ] Autosave bursts do not flood history: a revision is written when the previous revision is older than 5 minutes or the edit session changed (prompt switched, window closed). Done when: core tests on `AutosavePolicy` prove it.
- [ ] History panel lists revisions with time and a first-line preview; Restore makes one current. Done when: a driven run restores and the restore itself appears as a revision.
- [ ] Commit: `"storage, app: revisions written on save, listed, and restored"`

**Test checkpoint:** Unit test plus driven run with evidence: edit a prompt in three sessions, see three revisions, restore the first, read the body back.

**Freeze check:** an update that fails after the revision insert rolls both back; the test forces the failure.

**Job:** the user can see and undo how a spell changed.
**Treatment:** a History panel with Restore. Cheaper substitute that fails the checkpoint: an undo stack that dies with the session.
**Chrome:** consume the vocabulary table (Revisions / History).

## 6. The Line Diff and the Compare View

- [ ] `src/core/include/spellbook/core/diff.hpp`: Myers line diff returning insert, delete, and equal runs. Done when: tests cover empty, identical, all-new, and interleaved changes, and a 5,000-line diff finishes in under 100 ms.
- [ ] Compare view: two revisions side by side with changed lines tinted (colours from `standards/ui.md`, legible in light and dark). Done when: a capture is committed.
- [ ] Commit: `"core: the line diff; app: compare revisions"`

**Test checkpoint:** Unit test: the diff cases pass, including the timing case in Release.

## 7. The Runes and Revisions Guide

- [ ] `docs/user/runes.md` (syntax with examples, escaping, defaults) and `docs/user/revisions.md`. Done when: linked from `docs/user/README.md`.
- [ ] Commit: `"docs: the runes and revisions guide"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` prints `0 findings`; every example in `runes.md` is also a case in `template_tests.cpp`.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `python scripts/todo-graph.py validate` clean
