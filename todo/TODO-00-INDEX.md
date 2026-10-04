# Spellbook -- TODO Index

The live execution plan for Spellbook. Format spec: [README.md](./README.md). Ordered plan: [implementation-plan.md](./implementation-plan.md).

## How to use this tree

- **This file** carries domain order and the active TODOs. Keep it at that altitude: no checklists.
- **Each domain's `INDEX.md`** lists its own TODO files. Ideas that are not planned work live in [`backlog.md`](./backlog.md), never in a domain.
- Give every topic **one canonical home**. Cross-link with XREFs instead of duplicating scope.
- Numbering is local to a domain (`TODO-01`, `TODO-02`) and never reused.

## What this plan is

Spellbook is a premium native Windows prompt manager in C++20, moving from Win32 to WinUI 3 on Visual Studio 2026 ([`00-workspace/TODO-02-winui-stack.md`](./00-workspace/TODO-02-winui-stack.md)), replacing a folder of Notepad `.txt` files. The plan runs eight milestones to v0.1.0 and a channels phase after it: M0 the skeleton, the stack, and the unattended runner; M1 the library (with Trash, metadata, and tabs); M2 importing the existing `.txt` files plus the safety nets (backups, restore, crash recovery); M3 search, cast, capture, and sharing; M4 templates, rich runes, revisions, and the smart editor; M5 polish (settings, privacy, the update check, first run, portable mode); M6 AI assist (OpenRouter and ACP agents); M7 the installer and the release; then Phase 8, the package channels. Operator decisions of 2026-10-04 are in [`../docs/adr/0003-v0.1.0-scope-and-distribution.md`](../docs/adr/0003-v0.1.0-scope-and-distribution.md) and [`../docs/adr/0004-ai-assist.md`](../docs/adr/0004-ai-assist.md). Phases are in [`implementation-plan.md`](./implementation-plan.md); `process-plan` runs them unattended once `D00 T03` has shipped.

## Domain order

Domains are numbered in allocation order. `DNN TNN §N` references encode the number, so a new domain appends after the last one.

| No. | Domain | Phase | Purpose |
| :-: | ------ | :---: | ------- |
| 00 | [Workspace](./00-workspace/INDEX.md) | 0 | Toolchain, build, runners, CI, the TODO system, the unattended runner and UI driver, agent rules, docs, and the core, storage, and app skeletons. |
| 01 | [Library](./01-library/INDEX.md) | 1 | Prompts and folders, the main window, the editor, autosave, the vocabulary table, single instance, Trash, metadata, and tabs. |
| 02 | [Import](./02-import/INDEX.md) | 2, 3 | Import scrolls, `.spell` files, and finding and merging duplicates. |
| 03 | [Find](./03-find/INDEX.md) | 3, 4 | Full-text search, tags, favourites, sorting, Cast, the quick-search popup, capture from any app, and the Jump List. |
| 04 | [Templates](./04-templates/INDEX.md) | 4 | Runes, rich runes, composition, the fill-in dialog, the smart editor, revisions, and diff. |
| 05 | [Ship](./05-ship/INDEX.md) | 0, 2, 5, 7, 8 | The icon, dark mode, settings, privacy, backups and recovery, the update check, first run, export and restore, accessibility, portable mode, the installer, the release, and the channels. |
| 06 | [AI](./06-ai/INDEX.md) | 6 | AI assist through OpenRouter or an ACP agent: refine, adapt, write, rune-ify, critique, suggest, and semantic search. |
| 99 | [Manual](./99-manual/INDEX.md) | 0, 2, 5, 7, 8 | Operator-only steps, never run by an agent: the repository and its settings, the VS 2026 workloads, ownership, the real import, the clean-machine and visual passes, the live AI trial, the release approval, channel accounts, signing, and the Store. |

Current dependency-safe work comes from `python scripts/todo-graph.py query ready`, not from this table.

## Active TODOs

| TODO | Domain | Title |
| ---- | ------ | ----- |
| [TODO-01](./00-workspace/TODO-01-skeleton.md) | 00-workspace | The M0 Skeleton (one section open: CI green on GitHub) |
| [TODO-03](./00-workspace/TODO-03-unattended-runner.md) | 00-workspace | The Unattended Runner (next: §1 to §3 need no compiler) |
| [TODO-02](./00-workspace/TODO-02-winui-stack.md) | 00-workspace | The WinUI 3 Stack (next: ADR 0002, then the VS 2026 workloads) |
| [TODO-01](./99-manual/TODO-01-operator.md) | 99-manual | Operator Steps (blocking now: §5, the VS 2026 workloads) |
| [TODO-01](./01-library/TODO-01-library-crud.md) | 01-library | The Library: Spells, Chapters, the Editor, and Autosave |
