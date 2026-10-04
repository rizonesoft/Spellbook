---
schema_version: 1
id: spell-files-and-duplicates
domain: 02-import
status: draft
title: "TODO-02 -- Spell Files and Duplicates: Share, Open, Find, and Merge"
depends_on: []
---

# TODO-02 -- Spell Files and Duplicates: Share, Open, Find, and Merge

> **Goal:** A spell (or a chapter of them) can be shared as a small `.spell` file and opened by double-click, drag and drop, or File > Open, with a preview that flags duplicates; and a Find duplicates tool finds exact and near-identical spells across the library and merges them without losing tags, favourites, use counts, or metadata (the extras go to Trash, restorable).

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** Nothing here exists. Operator decision 2026-10-04 (ADR 0003): `.spell` files and Find duplicates are in v0.1.0. The import planner (`D02 T01 §2`) defines the body normalisation and hash that exact-duplicate detection reuses; the import batch commit (`D02 T01 §3`) is the write path a `.spell` import reuses, so Undo last import covers it. Tags arrive in `D03 T01 §2`, so the sections that read or write tags run in Phase 3. The installer registers the `.spell` type (`D05 T02 §2`); opening a file while Spellbook runs is forwarded by `D01 T02 §1`.

## Inputs

- -> XREF: D02 T01 §2 -- the normalisation and hash for exact duplicates
- -> XREF: D02 T01 §3 -- the transactional import commit a `.spell` import reuses
- -> XREF: D01 T02 §2 -- Trash, where merged-away spells go
- -> XREF: D01 T02 §3 -- the metadata a `.spell` carries and a merge combines
- -> XREF: D03 T01 §2 -- tags, which a `.spell` carries and a merge unions
- -> XREF: D05 T02 §2 -- the installer registers the `.spell` file type
- Microsoft Learn: `FileSavePicker` and `FileOpenPicker` in desktop apps (`InitializeWithWindow`), drag and drop in WinUI 3
- -> XREF: D05 T04 §1 -- the starter grimoire ships as a `.spell` file

## Outcome

- `write_spell_file` and `read_spell_file` round-trip any set of spells byte for byte; a newer format version is refused with a message.
- Share as .spell, File > Open spell file, drag and drop, and double-click all reach one preview dialog that imports in one transaction as an undoable batch.
- Find duplicates groups exact and near duplicates (with a similarity percentage) in under 2 s for 5,000 spells and merges a group in one transaction.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | The .spell format in core | D01 T02 §3 |  [ ]   |
|   2   |   §2    | Share and open .spell files | §1, D01 T02 §1, D02 T01 §3, D03 T01 §2 |  [ ]   |
|   3   |   §3    | Duplicate detection and merge in core | D02 T01 §2, D01 T02 §2, D03 T01 §3 |  [ ]   |
|   4   |   §4    | The Find duplicates surface | §3 |  [ ]   |
|   5   |   §5    | The sharing and duplicates guide | §2, §4 |  [ ]   |

---

## 1. The .spell Format in Core

A `.spell` file is the unit of sharing, so it carries what another person needs (the text, the tags, the metadata) and nothing personal (ids, timestamps, use counts, revisions).

- [ ] `src/core/include/spellbook/core/spell_file.hpp`: `write_spell_file(std::span<const SharedSpell>) -> std::string` and `read_spell_file(std::string_view) -> SpellFileResult`. The document is UTF-8 JSON without a BOM, LF line endings, two-space indent, keys in a fixed order: `{"format": "spellbook-spell", "version": 1, "spells": [{"title", "body", "description", "tags", "target_model", "source", "notes", "rating", "chapter"}]}` (`chapter` is an optional suggested path like `Writing/Email`). Done when: it compiles in core with nlohmann-json and no Windows header.
- [ ] Validation: a wrong `format` or a `version` above 1 is refused with a message naming it; a file over 5 MiB, a non-string title, or a rating outside 0 to 5 is refused naming the spell index; unknown keys are ignored. Done when: tests cover each.
- [ ] Fixtures in `tests/fixtures/spell-files/` (one spell, a chapter of five with runes and emoji, a version-2 file, a malformed file) and tests in `tests/core/spell_file_tests.cpp`. Done when: they pass.
- [ ] Commit: `"core: the .spell file format (D02 T02 §1)"`

**Test checkpoint:** Round-trip proof: each valid fixture reads and writes back byte-identical; a mutant that reorders keys fails it.

## 2. Share and Open .spell Files

**Job:** the user can hand a spell to someone and open one they were given.
**Treatment:** "Share as .spell..." on a spell, a multi-selection, or a chapter (context menu and File menu) saves through a `FileSavePicker` (name defaults to the title or chapter); "Open spell file..." (Ctrl+O), dropping `.spell` files on the window, and launching with a path all open one preview `ContentDialog`: each spell with title, tags, and a Duplicate badge when its normalised body already exists, a target-chapter picker (defaulting to the file's suggested chapter), and Import; duplicates start unticked. Cheaper substitute that fails the checkpoint: importing without a preview.
**Chrome:** consume `read_spell_file`, the import batch commit (`D02 T01 §3`), the vocabulary table, and `D01 T02 §1` forwarding. Do not write a second import transaction.

- [ ] Share and Open commands with AutomationIds `share-spell`, `open-spell-file`, `spell-file-preview`, `spell-file-import`; drag and drop on the main window. Done when: each path reaches the preview.
- [ ] Import commits through `commit_import` as one batch (tags created as needed), so File > Undo last import removes it. Done when: undo after a `.spell` import restores the previous library exactly.
- [ ] A forwarded `open_file` (from `D01 T02 §1`) opens the same preview in the running instance. Done when: launching `Spellbook.exe <file.spell>` as a second process shows the preview in the first.
- [ ] `tests/ui/scenarios/spell-files.ps1`: share a chapter of three, open the file into an empty data folder, assert the three spells and their tags via `dbread.py`, re-open it and assert all three are flagged Duplicate. Done when: it exits 0.
- [ ] Commit: `"app: share and open .spell files (D02 T02 §2)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario spell-files` exits 0; the shared file equals `write_spell_file` of the same spells (the scenario compares bytes); captures under `docs/captures/spell-files/`.

## 3. Duplicate Detection and Merge in Core

- [ ] `src/core/include/spellbook/core/duplicates.hpp`: `find_duplicates(std::span<const PromptText>) -> std::vector<DuplicateGroup>`. Exact groups share the `D02 T01 §2` normalised hash. Near groups: for bodies of 20 words or more, word 5-gram shingles compared by MinHash (128 hashes, 32 bands of 4) with candidates confirmed by exact Jaccard of 0.85 or more; for shorter bodies, a normalised edit-distance similarity of 0.9 or more. Each group lists members and a similarity percentage. Done when: tests cover exact, near, a one-word change in a long prompt (near), and two unrelated prompts (no group).
- [ ] Performance: 5,000 generated prompts are grouped in under 2 s in Release. Done when: a `perf` test passes under `pwsh scripts/test.ps1 -Config Release -Filter perf`.
- [ ] `LibraryService::merge(Id keep, std::span<const Id> others)`: unions tags, sets favourite if any was, sums use counts, keeps the latest last-used time, fills the kept spell's empty metadata from the others, and moves the others to Trash, in one transaction. Done when: core and storage tests assert every field and that a failure leaves nothing changed.
- [ ] Commit: `"core: duplicate detection and merge (D02 T02 §3)"`

**Test checkpoint:** Unit test: `pwsh scripts/test.ps1 -Filter "core: .*duplicate"` passes; the perf test passes in Release.

## 4. The Find Duplicates Surface

**Job:** the user can clean up a library that grew by copy and paste.
**Treatment:** Tools > Find duplicates runs the scan with a progress ring and Cancel, then lists groups (exact first, then near by similarity); selecting a group shows its members side by side with title, chapter, tags, and use count; the user picks which to keep (default: most used) and clicks Merge, or Skip; a summary names the counts. Cheaper substitute that fails the checkpoint: a list of exact matches with Delete buttons.
**Chrome:** consume `find_duplicates` and `LibraryService::merge` on a worker thread, the vocabulary table, and the theme resources. Do not delete anything outside Trash.

- [ ] The surface with AutomationIds `find-duplicates`, `duplicate-groups`, `duplicate-keep-<id>`, `duplicate-merge`, `duplicate-skip`; the scan runs off the UI thread. Done when: the window stays responsive over 5,000 seeded spells.
- [ ] `tests/ui/scenarios/duplicates.ps1`: seed two exact pairs and one near pair, merge all three groups, assert via `dbread.py` that three spells remain live, three are in Trash, and the kept spells carry the union of tags. Done when: it exits 0.
- [ ] Commit: `"app: find and merge duplicates (D02 T02 §4)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario duplicates` exits 0; captures under `docs/captures/duplicates/`.

## 5. The Sharing and Duplicates Guide

- [ ] `docs/user/sharing.md` (`.spell` files: what they contain and do not, opening, duplicates) and a Find duplicates section in `docs/user/library.md`; README Features rows. Done when: linked from `docs/user/README.md`.
- [ ] `CHANGELOG.md` Unreleased lists both. Done when: present.
- [ ] Commit: `"docs: sharing spells and finding duplicates (D02 T02 §5)"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` prints `0 findings`.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `pwsh scripts/drive.ps1 -Scenario spell-files` and `duplicates` exit 0
- [ ] `python scripts/todo-graph.py validate` clean
