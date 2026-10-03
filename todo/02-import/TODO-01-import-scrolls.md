---
schema_version: 1
id: import-scrolls
domain: 02-import
status: draft
title: "TODO-01 -- Import Scrolls: Bulk Import of Notepad .txt Prompts"
depends_on: []
frozen: true
---

# TODO-01 -- Import Scrolls: Bulk Import of Notepad .txt Prompts

> **Goal:** The operator's existing prompt library, a tree of Notepad `.txt` files, moves into Spellbook in one pass with nothing lost and nothing doubled: each file becomes a prompt titled from its file name, each folder a chapter, every encoding Notepad writes is detected and decoded, exact duplicates are skipped, the whole import is previewed before anything is written, and the commit is one transaction that can be undone as a batch. This is the operator's migration path, so it ranks above search and templates.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** Nothing imports yet. `core::is_valid_utf8` and `utf8_to_wide` exist and are tested (`src/core/include/spellbook/core/text.hpp`); there is no code-page decoder. Schema 1 has no record of import batches. Folder and prompt writes arrive with `D01 T01 §1` and `D01 T01 §2`.

## Inputs

- [`src/core/include/spellbook/core/text.hpp`](../../src/core/include/spellbook/core/text.hpp) -- the UTF-8 validity check §1 builds on
- Notepad's encodings (Windows 11): UTF-8 (default since 2019), UTF-8 with BOM, UTF-16 LE and BE with BOM, and ANSI (the user's code page, Windows-1252 on English systems)
- -> XREF: D01 T01 §2 -- folder creation and prompt creation this import writes through

## Outcome

- `ImportPlanner` in core turns a scanned file tree into a preview: one row per file with title, target chapter, detected encoding, size, and a status (new, duplicate, unreadable, too large).
- The preview dialog lets the user untick rows, pick the target chapter, and see totals before committing.
- The commit is one transaction recorded as an import batch; "Undo last import" removes exactly that batch.
- A round-trip fixture set proves every encoding decodes to the expected text byte for byte.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Encoding detection and decoding in core | D00 T01 §3 |  [ ]   |
|   2   |   §2    | The import planner: titles, chapters, duplicates | §1, D01 T01 §3 |  [ ]   |
|   3   |   §3    | Migration 0002 and the transactional batch commit | §2, D01 T01 §2 |  [ ]   |
|   4   |   §4    | The Import scrolls preview dialog | §3, D01 T01 §5 |  [ ]   |
|   5   |   §5    | Undo last import, the report, and the user guide | §4 |  [ ]   |

---

## 1. Encoding Detection and Decoding in Core

Detection order, as Notepad itself reads: a BOM wins (EF BB BF is UTF-8; FF FE is UTF-16 LE; FE FF is UTF-16 BE); otherwise valid UTF-8 is UTF-8; otherwise the file is ANSI, decoded as Windows-1252 (the operator's code page; a different code page is a setting in `D05 T01 §2`). Decoding lives in core with a built-in 1252 table, so it is testable without Windows.

- [ ] `src/core/include/spellbook/core/encoding.hpp`: `enum class Encoding { Utf8, Utf8Bom, Utf16Le, Utf16Be, Windows1252 }`, `detect_encoding(std::span<const std::byte>)`, `decode_to_utf8(std::span<const std::byte>, Encoding) -> std::string`. Done when: the header compiles in core with no Windows include.
- [ ] Decode CRLF to LF on import and strip the BOM; keep every other character. Done when: a test asserts a CRLF file decodes to LF text with nothing else changed.
- [ ] Fixtures in `tests/fixtures/import/encodings/`: the same prompt saved by Notepad in each of the five encodings, plus one empty file and one with a lone 0x81 (undefined in 1252, decoded to U+FFFD). A `README.md` beside them records how each was produced. Done when: committed.
- [ ] Tests in `tests/core/encoding_tests.cpp` compare each decoded fixture with `expected.utf8.txt` byte for byte. Done when: they pass.
- [ ] Commit: `"core: encoding detection and decoding for imported text files"`

**Test checkpoint:** Round-trip proof: every fixture decodes to `expected.utf8.txt` exactly; a mutant that skips BOM detection fails the UTF-16 cases.

## 2. The Import Planner: Titles, Chapters, Duplicates

- [ ] `src/core/include/spellbook/core/import_planner.hpp`: input is a list of `{relative path, bytes}` (the app layer reads the disk); output is `ImportPlan` rows. Done when: it has no file-system dependency and tests feed it in memory.
- [ ] Title from the file name: drop `.txt`, turn `_` and `-` runs into spaces, trim, keep case. Folder path becomes the chapter path under a chosen root chapter. Done when: tests cover `code_review-v2.txt` to `code review v2` and nested folders.
- [ ] Duplicates: normalise the body (LF line endings, trailing whitespace trimmed per line, trailing blank lines dropped) and hash it; a row is `duplicate` when an existing prompt or an earlier row in the batch has the same hash. Done when: tests prove both cases and that a one-character difference is not a duplicate.
- [ ] Files over 1 MiB are `too large` and skipped by default; a file that fails decoding is `unreadable` with the reason. Done when: tests assert both statuses.
- [ ] Commit: `"core: the import planner with titles, chapters, and duplicate detection"`

**Test checkpoint:** Unit test: `pwsh scripts/test.ps1 -Filter "core: .*import"` passes.

## 3. Migration 0002 and the Transactional Batch Commit

Undo needs to know which rows an import created, so the schema gains an `import_batches` table and a nullable `prompts.import_batch_id`. This is the first migration after 0001 and follows `.claude/skills/add-migration/SKILL.md`.

- [ ] `migrations/0002_import_batches.sql`: `import_batches(id, source_root, started_at, file_count)`, `ALTER TABLE prompts ADD COLUMN import_batch_id INTEGER REFERENCES import_batches(id) ON DELETE SET NULL`, and an index. Done when: `storage: migrate takes a new database to the latest version` passes at version 2, and a version-1 database fixture upgrades with its rows intact.
- [ ] `commit_import(const ImportPlan&, root chapter) -> ImportResult` on the repository: one `BEGIN IMMEDIATE` transaction creates chapters as needed, inserts every accepted row with the batch id, and commits. Done when: tests assert counts and that a failure mid-way leaves no rows and no batch.
- [ ] Commit: `"storage: import batches (migration 0002) and the transactional import commit"`

**Test checkpoint:** Unit test: the commit and rollback cases pass; a committed version-1 fixture database upgrades to version 2 and keeps every prompt.

**Freeze check:** killing the process during `commit_import` (simulated by a throwing hook between inserts) leaves the database byte-identical in content to before the import.

## 4. The Import Scrolls Preview Dialog

**Job:** the user can bring a folder of `.txt` prompts into Spellbook and see exactly what will happen first.
**Treatment:** File > Import scrolls opens a folder picker (`IFileOpenDialog` with `FOS_PICKFOLDERS`), then a resizable dialog with a ListView (checkbox, title, chapter, encoding, size, status), a target-chapter picker, totals ("214 new, 9 duplicates skipped, 1 unreadable"), and Import and Cancel. Cheaper substitute that fails the checkpoint: importing straight from the picker with no preview.
**Chrome:** consume the vocabulary table (`Import scrolls` / `Import text files`), the DPI helpers, and `ImportPlanner`. Do not decode files in the app layer.

- [ ] Read files on a worker thread with a progress line and Cancel; the UI thread only builds the list. Done when: a 2,000-file fixture tree stays responsive.
- [ ] Untick and tick rows; duplicates and unreadable rows start unticked. Done when: totals update live.
- [ ] Commit: `"app: the Import scrolls preview dialog"`

**Test checkpoint:** Driven run with evidence: import `tests/fixtures/import/tree/` (nested folders, mixed encodings, two duplicates) into an empty dev database; the log records the batch id and counts; every prompt body read back matches its fixture's expected text.

## 5. Undo Last Import, the Report, and the User Guide

- [ ] File > Undo last import deletes the prompts of the latest batch that have not been edited since, and the chapters it created that are now empty, after a confirmation naming the counts. Done when: a driven run removes exactly the batch.
- [ ] After an import, a summary names the counts and offers to open the log entry listing skipped files. Done when: shown in a driven run.
- [ ] `docs/user/import.md` with the encoding rules, duplicate rules, and undo. Done when: linked from `docs/user/README.md`.
- [ ] Commit: `"app: undo last import, the import report, and the import guide"`

**Test checkpoint:** Driven run with evidence: import, edit one imported prompt, undo; every other imported prompt is gone, the edited one stays, and the log says why.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] The operator's real prompt folder imports with a preview the operator approves (recorded in `D99 T01 §3`)
- [ ] `python scripts/todo-graph.py validate` clean
