# Spellbook -- TODO Index

The live execution plan for Spellbook. Format spec: [README.md](./README.md). Ordered plan: [implementation-plan.md](./implementation-plan.md).

## How to use this tree

- **This file** carries domain order and the active TODOs. Keep it at that altitude: no checklists.
- **Each domain's `INDEX.md`** lists its own TODO files. Ideas that are not planned work live in [`backlog.md`](./backlog.md), never in a domain.
- Give every topic **one canonical home**. Cross-link with XREFs instead of duplicating scope.
- Numbering is local to a domain (`TODO-01`, `TODO-02`) and never reused.

## What this plan is

Spellbook is a native Windows prompt manager in C++20, moving from Win32 to WinUI 3 on Visual Studio 2026 (operator decision 2026-10-04, [`00-workspace/TODO-02-winui-stack.md`](./00-workspace/TODO-02-winui-stack.md)), replacing a folder of Notepad `.txt` files. The plan runs six milestones: M0 the skeleton (this initialisation), M1 the library, M2 importing the existing `.txt` files (the operator's migration path, so it comes before search), M3 search and the quick-search popup, M4 templates and revisions, and M5 polish and the first release. Each milestone is one domain and one phase of [`implementation-plan.md`](./implementation-plan.md).

## Domain order

Domains are numbered in allocation order. `DNN TNN §N` references encode the number, so a new domain appends after the last one.

| No. | Domain | Phase | Purpose |
| :-: | ------ | :---: | ------- |
| 00 | [Workspace](./00-workspace/INDEX.md) | 0 | Toolchain, build, runners, CI, the TODO system, agent rules, docs, and the core, storage, and app skeletons. |
| 01 | [Library](./01-library/INDEX.md) | 1 | Prompts and folders, the three-pane window, the editor, autosave, and the vocabulary table. |
| 02 | [Import](./02-import/INDEX.md) | 2 | Import scrolls: encoding detection, preview, duplicate skipping, the transactional commit, and undo. |
| 03 | [Find](./03-find/INDEX.md) | 3 | Full-text search, tags, favourites, sorting, Cast to the clipboard, and the global quick-search popup. |
| 04 | [Templates](./04-templates/INDEX.md) | 4 | Runes, the fill-in dialog, revisions, and diff. |
| 05 | [Ship](./05-ship/INDEX.md) | 5 | Dark mode, settings, export and restore, accessibility, the installer, and v0.1.0. |
| 99 | [Manual](./99-manual/INDEX.md) | 0, 2, 5 | Operator-only steps: the GitHub repository and settings, ownership, and accepting the real import. |

Current dependency-safe work comes from `python scripts/todo-graph.py query ready`, not from this table.

## Active TODOs

| TODO | Domain | Title |
| ---- | ------ | ----- |
| [TODO-01](./00-workspace/TODO-01-skeleton.md) | 00-workspace | The M0 Skeleton (one section open: CI green on GitHub) |
| [TODO-02](./00-workspace/TODO-02-winui-stack.md) | 00-workspace | The WinUI 3 Stack (next: ADR 0002, then the VS 2026 workloads) |
| [TODO-01](./99-manual/TODO-01-operator.md) | 99-manual | Operator Steps |
| [TODO-01](./01-library/TODO-01-library-crud.md) | 01-library | The Library: Spells, Chapters, the Editor, and Autosave (next) |
