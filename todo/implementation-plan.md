# Spellbook -- Implementation Plan

The order to run every section in, from the M0 skeleton through the premium first release, v0.1.0, to the package channels after it.

> **Progress:** **16 of 117 sections complete (13%).** Derived from the Implementation Order tables by `python scripts/todo-graph.py plan --sync` -- never edited by hand.

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

v0.1.0 is **a premium native Windows prompt manager the operator uses instead of Notepad**: it imports the existing `.txt` library without loss, finds any prompt from anywhere in two seconds, captures prompts from any app, fills and copies rich templates, keeps every revision and every deleted spell for 30 days, backs itself up, helps write better prompts with the AI provider the user chooses, follows the Windows theme and scaling, and installs for one user, for everyone, or portably, and uninstalls cleanly.

<!-- no-align -->

| Aim | Owned by |
| --- | --- |
| A clean clone builds and tests in four commands | `D00 T01 §1` · `D00 T01 §6` · `D00 T02 §4` |
| The plan runs unattended | `D00 T03 §1` · `D00 T03 §3` · `D00 T03 §4` |
| CI holds every gate | `D00 T01 §10` · `D99 T01 §2` |
| Nothing typed is ever lost | `D01 T01 §7` · `D01 T02 §2` · `D05 T03 §1` · `D05 T03 §3` |
| The existing .txt library arrives intact | `D02 T01 §1` · `D02 T01 §3` · `D99 T01 §3` |
| Any prompt is two seconds away | `D03 T01 §1` · `D03 T01 §6` · `D03 T02 §3` |
| Prompts come in from anywhere | `D03 T02 §2` · `D02 T02 §2` |
| Templates, composition, and revisions | `D04 T01 §4` · `D04 T02 §2` · `D04 T01 §5` |
| AI that helps and never surprises | `D06 T01 §5` · `D06 T01 §2` · `D05 T03 §4` |
| Themed but never obscure | `D01 T01 §4` · `D05 T01 §2` |
| Installs three ways, uninstalls clean | `D05 T02 §2` · `D05 T02 §8` · `D05 T02 §5` |

---

## The phases

### Phase 0 -- The Skeleton, the Stack, and the Runner (M0)

Everything later builds on a toolchain that provisions itself, a build with warnings as errors, a database that migrates, a window that opens, and gates that run in one command. On 2026-10-04 the operator moved the app to WinUI 3 on Visual Studio 2026 (`D00 T02`) and asked for a plan that runs unattended (`D00 T03`); both land here, before the first M1 surface, so no Win32 UI is built only to be rewritten and every later surface can be proven by the UI driver. The run skills and the graph's operator split come first because they need no compiler; the Visual Studio 2026 workloads (`D99 T01 §5`) are the operator's one blocking step. The approved icon closes the phase.

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
| [x] | `D99 T01 §1` | Create the GitHub repository and push main | 3 |
| [ ] | `D00 T01 §10` | CI green on GitHub | 3 |
| [x] | `D99 T01 §2` | Repository settings: labels, security, branch protection | 5 |
| [x] | `D00 T03 §1` | Operator-only work in the graph: runnable now and elsewhere | 4 |
| [x] | `D00 T03 §2` | The run skills: process-plan, process-phase, process-todo-file, groom-plan | 5 |
| [x] | `D00 T03 §3` | The run guard: the Stop hook and its probe | 4 |
| [x] | `D00 T03 §6` | Independent Codex writer workflow and supervised runner | 7 |
| [ ] | `D00 T02 §1` | ADR 0002 and the decision record | 5 |
| [x] | `D99 T01 §5` | Install the Visual Studio 2026 C++ and WinUI workloads | 2 |
| [ ] | `D00 T02 §2` | The Visual Studio 2026 toolchain pins and the setup leg | 5 |
| [ ] | `D00 T02 §3` | The WinUI 3 shell in the hybrid build | 9 |
| [ ] | `D00 T03 §4` | The UI driver for driven runs | 6 |
| [ ] | `D00 T02 §4` | Runners, CI, and the portable package on the new stack | 7 |
| [ ] | `D00 T02 §5` | The winui-patterns skill, the UI standard, and the architecture doc | 5 |
| [ ] | `D00 T02 §6` | Retarget the open UI sections of the plan to WinUI | 6 |
| [ ] | `D00 T03 §5` | Unattended proof rules and the checkpoint sweep | 3 |
| [ ] | `D05 T02 §1` | The designed icon and the README banner | 4 |

### Phase 1 -- The Library (M1)

The library is what every later milestone reads and writes: storage first, then the core service that holds the rules, then the window. The vocabulary table lands before the first label is drawn. The premium library (`D01 T02`) follows the surfaces it extends: single instance once the window exists, Trash once delete exists, metadata and tabs once autosave exists.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D01 T01 §1` | Prompt CRUD in the repository | 5 |
| [ ] | `D01 T01 §2` | Folder tree operations in the repository | 5 |
| [ ] | `D01 T01 §3` | LibraryService: rules, clock, and the autosave policy | 5 |
| [ ] | `D01 T01 §4` | The vocabulary string table | 3 |
| [ ] | `D01 T01 §5` | The three-pane main window | 5 |
| [ ] | `D01 T02 §1` | Single instance and command-line forwarding | 4 |
| [ ] | `D01 T01 §6` | Create, rename, move, and delete commands | 5 |
| [ ] | `D01 T01 §7` | Autosave wiring and the status bar | 3 |
| [ ] | `D01 T02 §2` | Trash in storage and core | 4 |
| [ ] | `D01 T02 §3` | Spell metadata in storage and core | 3 |
| [ ] | `D01 T02 §4` | The Trash surface and Move to Trash | 5 |
| [ ] | `D01 T02 §5` | The Details panel: metadata in the editor | 4 |
| [ ] | `D01 T02 §6` | Tabs | 5 |
| [ ] | `D01 T01 §8` | The library user guide | 3 |
| [ ] | `D01 T02 §7` | The premium library guide | 3 |

### Phase 2 -- Import Scrolls and Safety Nets (M2)

The operator's prompts live in `.txt` files today, so importing them is the migration path and outranks search. Automatic backups, restore, and crash recovery land first in this phase, so the real library never enters a Spellbook without a safety net; the `.spell` format is defined here because it is an import format. The operator's acceptance of the real import closes the phase.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D05 T03 §1` | Automatic and pre-migration backups | 5 |
| [ ] | `D05 T03 §2` | Restore from a backup | 3 |
| [ ] | `D05 T03 §3` | Crash dumps and recovery on the next start | 4 |
| [ ] | `D02 T01 §1` | Encoding detection and decoding in core | 5 |
| [ ] | `D02 T01 §2` | The import planner: titles, chapters, duplicates | 5 |
| [ ] | `D02 T01 §3` | The import batches migration and the transactional batch commit | 3 |
| [ ] | `D02 T01 §4` | The Import scrolls preview dialog | 3 |
| [ ] | `D02 T01 §5` | Undo last import, the report, and the user guide | 4 |
| [ ] | `D02 T02 §1` | The .spell format in core | 4 |
| [ ] | `D99 T01 §3` | Accept the import of the real prompt library | 2 |

### Phase 3 -- Find, Cast, Capture, and Share (M3)

With real prompts in the library, finding and using them is the daily job: search, tags, favourites, the clipboard, and the global popup; then capture from any app, sharing `.spell` files (which need tags), and finding duplicates.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D03 T01 §1` | The search query builder and ranked search | 4 |
| [ ] | `D03 T01 §2` | Tags (Sigils): storage, service, and assignment UI | 3 |
| [ ] | `D03 T01 §3` | Favourites, use tracking, and sort modes | 3 |
| [ ] | `D03 T01 §4` | The search box and filters in the main window | 3 |
| [ ] | `D03 T01 §5` | Cast: copy to the clipboard | 4 |
| [ ] | `D03 T01 §6` | The global hotkey and the quick-search popup | 4 |
| [ ] | `D03 T02 §1` | Capture rules in core | 2 |
| [ ] | `D03 T02 §2` | The capture hotkey and flyout | 5 |
| [ ] | `D02 T02 §2` | Share and open .spell files | 5 |
| [ ] | `D02 T02 §3` | Duplicate detection and merge in core | 4 |
| [ ] | `D02 T02 §4` | The Find duplicates surface | 3 |
| [ ] | `D02 T02 §5` | The sharing and duplicates guide | 3 |
| [ ] | `D03 T01 §7` | Keyboard shortcuts and the find guide | 2 |

### Phase 4 -- Runes, Revisions, and the Smart Editor (M4)

Templates build on Cast, and revisions build on autosave. Rich runes and composition extend the parser as soon as it exists; the Jump List waits for Cast through the fill-in dialog so a taskbar cast fills runes like any other.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D04 T01 §1` | The rune syntax and the template parser | 4 |
| [ ] | `D04 T01 §2` | The renderer | 2 |
| [ ] | `D04 T01 §3` | The fill-in dialog | 3 |
| [ ] | `D04 T01 §4` | Cast through the fill-in dialog | 3 |
| [ ] | `D04 T02 §1` | Rich rune syntax in the parser and renderer | 4 |
| [ ] | `D04 T02 §2` | Spell composition: includes, cycles, and rename tracking | 4 |
| [ ] | `D04 T02 §3` | Built-ins at cast time and the upgraded fill-in dialog | 4 |
| [ ] | `D04 T02 §4` | The smart editor: highlighting and counts | 4 |
| [ ] | `D04 T01 §5` | Revisions: written on save, listed, restored | 4 |
| [ ] | `D04 T01 §6` | The line diff and the Compare view | 3 |
| [ ] | `D03 T02 §3` | The Jump List | 6 |
| [ ] | `D03 T02 §4` | The capture and Jump List guide | 3 |
| [ ] | `D04 T01 §7` | The runes and revisions guide | 2 |
| [ ] | `D04 T02 §5` | The rich runes and composition guide | 3 |

### Phase 5 -- Polish (M5)

Polish touches every surface the earlier phases built: theming, the Settings dialog (which the update check, portable mode, and AI then extend), export and restore, accessibility, the update check and the Privacy page, the first-run experience, and portable mode in the app.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D05 T01 §1` | Dark mode for every control | 3 |
| [ ] | `D05 T01 §2` | The settings store and the Settings dialog | 5 |
| [ ] | `D05 T01 §3` | Export to JSON and Markdown | 3 |
| [ ] | `D05 T01 §4` | Restore from a JSON backup | 2 |
| [ ] | `D05 T01 §5` | The accessibility pass | 3 |
| [ ] | `D05 T03 §4` | The update check and the Privacy page | 5 |
| [ ] | `D05 T03 §5` | The backups, recovery, and privacy guide | 3 |
| [ ] | `D05 T04 §1` | The starter grimoire | 4 |
| [ ] | `D05 T04 §2` | The welcome page and the tour | 3 |
| [ ] | `D05 T04 §3` | About, third-party notices, and What's New | 5 |
| [ ] | `D05 T04 §4` | The first-run guide | 3 |
| [ ] | `D05 T02 §6` | Portable mode in the app | 5 |
| [ ] | `D99 T01 §4` | Confirm ownership, branding, and the publisher | 2 |

### Phase 6 -- Intelligence (M6)

AI assist comes after the Settings dialog and the Privacy page it configures through, and after the diff, tabs, capture flyout, and search box it plugs into. Everything is proven against a mock OpenRouter server and a mock ACP agent; no unattended run spends money.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D06 T01 §1` | The AI core: requests, feature prompts, parsers, and the spend ledger | 5 |
| [ ] | `D06 T01 §2` | Credentials, AI settings, and the privacy controls | 4 |
| [ ] | `D06 T01 §3` | The OpenRouter client and its mock server | 5 |
| [ ] | `D06 T01 §4` | The ACP client, the registry, and a mock agent | 5 |
| [ ] | `D06 T01 §5` | Refine and Adapt: suggestions reviewed as a diff | 4 |
| [ ] | `D06 T01 §6` | Write from a description and Rune-ify | 3 |
| [ ] | `D06 T01 §7` | Critique | 3 |
| [ ] | `D06 T01 §8` | Suggest title, description, sigils, and model | 3 |
| [ ] | `D06 T01 §9` | Semantic search | 5 |
| [ ] | `D06 T01 §10` | The AI guide and the privacy page | 4 |

### Phase 7 -- Ship v0.1.0 (M7)

The installer needs everything it installs and registers. Install tests run unattended on this PC and in CI; the operator's clean-machine check, visual and screen-reader pass, live AI trial, and written approval gate the tag, which an unattended run never pushes on its own.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D05 T02 §7` | Installer artwork from the brand masters | 2 |
| [ ] | `D05 T02 §2` | The Inno Setup 7 installer with three modes | 8 |
| [ ] | `D05 T02 §8` | Install tests on this PC and in CI | 3 |
| [ ] | `D05 T02 §9` | Channel manifests: winget, Scoop, Chocolatey | 3 |
| [ ] | `D05 T02 §3` | A draft run of the release pipeline | 3 |
| [ ] | `D99 T01 §10` | The visual and screen-reader pass | 4 |
| [ ] | `D99 T01 §11` | Try AI assist with a real key and a real agent | 3 |
| [ ] | `D99 T01 §6` | Check the release candidate on a clean machine | 2 |
| [ ] | `D05 T02 §4` | The complete user guide | 2 |
| [ ] | `D99 T01 §7` | Approve the v0.1.0 release | 2 |
| [ ] | `D05 T02 §5` | Release v0.1.0 | 3 |

### Phase 8 -- Channels after v0.1.0

Publishing to package managers needs accounts and secrets the operator owns, and the Microsoft Store needs code signing, so these follow the release.

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
| [ ] | `D99 T01 §8` | Channel accounts and secrets: winget, Scoop, Chocolatey | 4 |
| [ ] | `D05 T02 §10` | Publish to winget, Scoop, and Chocolatey | 3 |
| [ ] | `D99 T01 §9` | Code signing and a Partner Center account | 3 |
| [ ] | `D05 T02 §11` | Code signing and the Microsoft Store | 3 |
| [ ] | `D99 T01 §12` | Submit Spellbook to the Microsoft Store | 2 |

---

## What this plan deliberately does not do

- **Two kinds of network traffic only** (ADR 0003, ADR 0004): the update check (on by default, off on the Privacy page) and the AI features (opt in, through the provider the user configured, within the Privacy page's rules and the spending cap). No sync, no telemetry. Ideas for later are in [`backlog.md`](./backlog.md).
- **No test run, cast-and-paste, command palette, or saved searches** in v0.1.0: offered on 2026-10-04 and not chosen; kept in the backlog.
- **No MySQL backend.** `IPromptRepository` keeps the door open (see [`../docs/adr/0001-tech-stack.md`](../docs/adr/0001-tech-stack.md)); SQLite is the only implementation planned.
- **No signed v0.1.0.** Signing and the Microsoft Store follow the release (Phase 8).
