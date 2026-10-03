# Spellbook -- Implementation Plan

The order to run every section in, from the M0 skeleton to the first public release, v0.1.0.

> **Progress:** **9 of 51 sections complete (17%).** Derived from the Implementation Order tables by `python scripts/todo-graph.py plan --sync` -- never edited by hand.

Seeded 2026-10-04 by the initialisation session from the project brief (milestones M0 to M5) and the conventions of Isotone, Resolute, and ScratchPad (recorded in [`../docs/reference-conventions.md`](../docs/reference-conventions.md)).

**How to use this.** Take the first `[ ]` row whose dependencies have shipped (`python scripts/todo-graph.py query ready` lists them), and run it through the `process-todo-section` skill, then `review-todo-section`. One row is one section and one commit. A row is a complete instruction when pasted:

```
process todo section: | [ ] | `D01 T01 §1` | Prompt CRUD in the repository | 5 |
```

> [!IMPORTANT]
> **The boxes are derived. Never tick one by hand.** They mirror each TODO's Implementation Order table, whose rows flip only with a `Verified:` stamp.
>
> ```bash
> python scripts/todo-graph.py plan --sync     # rewrite the boxes, item counts, and progress
> python scripts/todo-graph.py plan --check    # fail if they have gone stale
> ```

---

## The acceptance bar

v0.1.0 is **a native Windows prompt manager the operator uses instead of Notepad**: it imports the existing `.txt` library without loss, finds any prompt from anywhere in two seconds, fills and copies templates, keeps every revision, never loses typed text, follows the Windows theme and scaling, and installs and uninstalls cleanly on a machine that has never seen it.

<!-- no-align -->

| Aim | Owned by |
| --- | --- |
| A clean clone builds and tests in four commands | `D00 T01 §1` · `D00 T01 §6` |
| CI holds every gate | `D00 T01 §10` · `D99 T01 §2` |
| Nothing typed is ever lost | `D01 T01 §3` · `D01 T01 §7` |
| The existing .txt library arrives intact | `D02 T01 §1` · `D02 T01 §3` · `D99 T01 §3` |
| Any prompt is two seconds away | `D03 T01 §1` · `D03 T01 §6` |
| Templates and revisions | `D04 T01 §4` · `D04 T01 §5` |
| Themed but never obscure | `D01 T01 §4` · `D05 T01 §2` |
| Ships alone, installs clean | `D05 T02 §2` · `D05 T02 §5` |

---

## The phases

### Phase 0 -- The Skeleton (M0)

Everything later builds on a toolchain that provisions itself, a build with warnings as errors, a database that migrates, a window that opens, and gates that run in one command. The operator's repository steps sit here because CI cannot go green without them.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [x] | `D00 T01 §1` | Repository config and the repo-portable toolchain | 4 |
| [x] | `D00 T01 §2` | CMake presets, vcpkg manifest, warning policy, tag-derived version | 5 |
| [x] | `D00 T01 §3` | Core: version info, UTF-8 and UTF-16 text, the domain model | 4 |
| [x] | `D00 T01 §4` | Storage: SQLite wrapper, migration runner, schema 1 with FTS5 | 5 |
| [x] | `D00 T01 §5` | The Win32 shell: window, icon, manifest, logging, smoke mode | 5 |
| [x] | `D00 T01 §6` | The PowerShell runners and check-all | 6 |
| [x] | `D00 T01 §7` | The TODO system, its tooling, and the M0 to M5 plan | 3 |
| [x] | `D00 T01 §8` | Agent infrastructure: AGENTS.md, standards, skills, hooks | 4 |
| [x] | `D00 T01 §9` | README, docs, ADR, and the GitHub templates | 5 |
| [ ] | `D99 T01 §1` | Create the GitHub repository and push main | 3 |
| [ ] | `D00 T01 §10` | CI green on GitHub | 3 |
| [ ] | `D99 T01 §2` | Repository settings: labels, security, branch protection | 4 |

### Phase 1 -- The Library (M1)

The library is what every later milestone reads and writes: storage first, then the core service that holds the rules, then the window. The vocabulary table lands before the first label is drawn, so no label is ever hard-coded.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D01 T01 §1` | Prompt CRUD in the repository | 5 |
| [ ] | `D01 T01 §2` | Folder tree operations in the repository | 5 |
| [ ] | `D01 T01 §3` | LibraryService: rules, clock, and the autosave policy | 5 |
| [ ] | `D01 T01 §4` | The vocabulary string table | 3 |
| [ ] | `D01 T01 §5` | The three-pane main window | 5 |
| [ ] | `D01 T01 §6` | Create, rename, move, and delete commands | 5 |
| [ ] | `D01 T01 §7` | Autosave wiring and the status bar | 3 |
| [ ] | `D01 T01 §8` | The library user guide | 3 |

### Phase 2 -- Import Scrolls (M2)

The operator's prompts live in `.txt` files today, so importing them is the migration path and outranks search: a library is only useful once it holds the real prompts. The operator's acceptance of the real import closes the phase.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D02 T01 §1` | Encoding detection and decoding in core | 5 |
| [ ] | `D02 T01 §2` | The import planner: titles, chapters, duplicates | 5 |
| [ ] | `D02 T01 §3` | Migration 0002 and the transactional batch commit | 3 |
| [ ] | `D02 T01 §4` | The Import scrolls preview dialog | 3 |
| [ ] | `D02 T01 §5` | Undo last import, the report, and the user guide | 4 |
| [ ] | `D99 T01 §3` | Accept the import of the real prompt library | 2 |

### Phase 3 -- Find and Cast (M3)

With real prompts in the library, finding and using them is the daily job: search, tags, favourites, the clipboard, then the global popup that makes Spellbook faster than opening a file.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D03 T01 §1` | The search query builder and ranked search | 4 |
| [ ] | `D03 T01 §2` | Tags (Sigils): storage, service, and assignment UI | 3 |
| [ ] | `D03 T01 §3` | Favourites, use tracking, and sort modes | 3 |
| [ ] | `D03 T01 §4` | The search box and filters in the main window | 3 |
| [ ] | `D03 T01 §5` | Cast: copy to the clipboard | 4 |
| [ ] | `D03 T01 §6` | The global hotkey and the quick-search popup | 4 |
| [ ] | `D03 T01 §7` | Keyboard shortcuts and the find guide | 2 |

### Phase 4 -- Runes and Revisions (M4)

Templates build on Cast, and revisions build on autosave; both need the earlier phases in place.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D04 T01 §1` | The rune syntax and the template parser | 4 |
| [ ] | `D04 T01 §2` | The renderer | 2 |
| [ ] | `D04 T01 §3` | The fill-in dialog | 3 |
| [ ] | `D04 T01 §4` | Cast through the fill-in dialog | 3 |
| [ ] | `D04 T01 §5` | Revisions: written on save, listed, restored | 4 |
| [ ] | `D04 T01 §6` | The line diff and the Compare view | 3 |
| [ ] | `D04 T01 §7` | The runes and revisions guide | 2 |

### Phase 5 -- Polish and Ship (M5)

Polish comes last because it touches every surface the earlier phases built; the release sections close the plan.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D05 T01 §1` | Dark mode for every control | 3 |
| [ ] | `D05 T01 §2` | The settings store and the Settings dialog | 4 |
| [ ] | `D05 T01 §3` | Export to JSON and Markdown | 3 |
| [ ] | `D05 T01 §4` | Restore from a JSON backup | 2 |
| [ ] | `D05 T01 §5` | The accessibility pass | 3 |
| [ ] | `D99 T01 §4` | Confirm ownership, branding, and the publisher | 2 |
| [ ] | `D05 T02 §1` | The designed icon and the README banner | 3 |
| [ ] | `D05 T02 §2` | The Inno Setup 7 installer | 4 |
| [ ] | `D05 T02 §3` | A draft run of the release pipeline | 3 |
| [ ] | `D05 T02 §4` | The complete user guide | 2 |
| [ ] | `D05 T02 §5` | Release v0.1.0 | 3 |

---

## What this plan deliberately does not do

- **No network calls in the app** for v0.1.0: no sync, no telemetry, no update check, no AI provider integration. Ideas for after v0.1.0 are in [`backlog.md`](./backlog.md).
- **No MySQL backend.** `IPromptRepository` keeps the door open (see [`../docs/adr/0001-tech-stack.md`](../docs/adr/0001-tech-stack.md)); SQLite is the only implementation planned.
