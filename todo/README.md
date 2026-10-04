# TODO System -- Format Spec

The `todo/` tree is the live execution plan for Spellbook. Markdown is canonical; `scripts/todo-graph.py` validates it and derives the boxes in `implementation-plan.md` from it.

One rule governs everything below: **a TODO section must be implementable by someone with zero conversation context.** A fresh session starts with none. If a section only makes sense to someone who was in the room, it is not done.

This system is a port of the Isotone TODO system (2026-10-04), itself a port of the Resolute and ScratchPad ones. What Spellbook keeps and what it leaves out is recorded in [`../docs/reference-conventions.md`](../docs/reference-conventions.md).

## Tree shape

```
todo/
├── README.md               this file
├── TODO-00-INDEX.md        root index: domain order and active work
├── implementation-plan.md  the phase plan, the front door for a run (boxes derived)
├── backlog.md              ideas that are not planned work; never runnable
├── 00-workspace/
│   ├── INDEX.md            domain index: every TODO in this domain
│   └── TODO-01-<short-name>.md
├── 01-library/
└── …
```

Domains are flat-numbered and ordered by allocation. A directory `NN-kebab-name/` holding an `INDEX.md` is a domain; the tooling reads them from the tree. Numbers are stable addresses: a new domain appends after the last one, because `DNN` cross-references encode them. Spellbook's domains follow the milestones (`01-library` is M1, `02-import` is M2, and so on), so a domain owns a subject end to end: core, storage, UI, tests, and docs for it.

**Naming:** `TODO-NN-short-name.md`, where `NN` is the next free number *within that domain*. Numbers are never reused.

## Frontmatter

```yaml
---
schema_version: 1
id: library-crud                     # stable, kebab-case, globally unique
domain: 01-library                   # must match the containing directory
status: draft                        # draft | active | blocked | done | superseded
title: "TODO-01 -- Library CRUD"
depends_on: []                       # optional; prefer section edges
frozen: false                        # optional; true when the file touches a frozen behavior
---
```

## File anatomy

```markdown
# TODO-01 -- Title

> **Goal:** One paragraph. What is true when this file is finished.

> [!IMPORTANT]
> **Current state (verified YYYY-MM-DD):** What exists RIGHT NOW, with real paths and real gaps.

## Inputs

- [`src/storage/...`](...) -- what this file consumes from it
- -> XREF: D00 T01 §4 -- the related work (the target must point back)

## Outcome

- Observable end states, not activities.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | ...         | --         |  [ ]   |

---

## 1. Section Title

One paragraph of context: why this section exists and what it must not break.

- [ ] One action in `a/named/path.cpp`. Done when: the observable end state. Cheaper substitute: the wrong thing a reviewer must refuse.
- [ ] Commit: `"library: one-line commit message"`

**Test checkpoint:** the falsifiable command or drive that proves the section. It must be able to fail.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `python scripts/todo-graph.py validate` clean
```

Sections run `## 1.` to `## N.` in order, with `## Verification` last.

### The Implementation Order table IS the dependency graph

Every `## N.` section has exactly one row and every row one section. `Depends On` uses the reference notation below; `--` means none. `Status` flips to `[x]` **only** when a `> **Verified:**` stamp covers the section, and then every checklist item in it must be ticked (the `Commit:` item is proven by history, not by its box). `validate` enforces all of it.

## Cross-reference notation

| Form         | Means                                 | Example      |
| ------------ | ------------------------------------- | ------------ |
| `§N`         | Section N of this same file           | `§3`         |
| `TNN §N`     | TODO-NN in the same domain, section N | `T02 §1`     |
| `DNN TNN §N` | Domain NN, TODO-NN, section N         | `D03 T01 §4` |

Never a bare number, and never a TODO without a section. An `-> XREF:` is bidirectional: the target file must carry an `-> XREF:` back, or `validate` is FATAL. Skills under `.claude/skills/` cite only full `DNN TNN §N` refs, and only live ones.

## Proof: what a Test checkpoint may cite

Spellbook is C++20 on MSVC, built with CMake presets and tested with Catch2 through CTest. A checkpoint cites one or more of these, and **it must be able to fail**:

| Proof | What it is | What it cannot prove |
| ----- | ---------- | -------------------- |
| **Builds clean** | `pwsh scripts/build.ps1 -Config Debug` and `-Config Release` exit 0 under `/W4 /WX`. | That the code is right. |
| **Static analysis clean** | `pwsh scripts/lint.ps1` (clang-tidy and the layering check) and `pwsh scripts/format.ps1 -Check` report nothing. | Runtime behavior. |
| **Unit test** | A Catch2 `TEST_CASE` run with `pwsh scripts/test.ps1 -Filter <name>`, cited by name. | Anything on the rendered surface. |
| **Driven run with evidence** | Launch the app, drive the surface, and record what it produced: a `spellbook.log` line, a database row read back, a file inspected, or a capture under `docs/captures/`. | Repeatability. |
| **Round-trip proof** | A committed fixture is imported or exported and the result compared with the source byte for byte or field by field. **Every importer and exporter owes this one.** | The experience of using it. |

A checkpoint that cites a gate which does not exist yet is unfalsifiable and is not allowed.

## Stamps

A stamp records verified work, written at the end of the section it covers, after the test checkpoint:

```
> **Verified:** 2026-10-04 | §3 | build clean Debug+Release · 29 tests pass · smoke exit 0
> **Deferred:** the sort menu -> XREF: D03 T01 §3 (item: "Sort by recent") -- needs use tracking first
> **Implementer:** Claude (claude-opus-5-5)
```

- `Verified:` -- date, sections covered (`§1` or `§1-§3`), and the evidence: real command output, never "it works".
- `Deferred:` -- one line per deferral, naming its owner with `-> XREF:` and the `(item: "...")` it hands over. When the owner ships, the deferral is stale and `validate` fails until it is rewritten as `Resolved:` with the date and the commit that closed it.
- `Implementer:` -- optional, `Name (model-id)`.

Re-verification replaces the stamp in place. Never rewrite a stamped section's checklist: new granularity on shipped work is a new section.

## Frozen behavior

Some behaviors write somebody's work: saving a prompt, autosave, import commits, restore from backup, and every migration. A writer that computes the wrong bytes there does not fail a test, it destroys a user's prompts. A TODO touching one sets `frozen: true`, and each section that changes a frozen behavior carries a freeze check beside its test checkpoint:

```
**Freeze check:** The import commit runs in one transaction; killing the process mid-import leaves the database exactly as it was before. Fixture: tests/fixtures/import/.
```

The frozen set today: the migration runner (`src/storage/src/migrator.cpp`) and `migrations/0001_init.sql`, which is shipped and never edited. A behavior joins the set when it ships.

## Surface sections

A section that builds or changes a user-facing surface carries three lines beside its checkpoint, so the runner never reconstructs them from a Goal paragraph:

```
**Job:** <the user> can <the verb this surface exists for>.
**Treatment:** <the asked treatment>. Cheaper substitute that fails the checkpoint: <the wrong thing>.
**Chrome:** consume <the shared pieces: the string table, the theme colours, the DPI helpers>. Do not invent a second <pattern>.
```

It also owes an account of **every control, menu item, and command** on the surface: working (proven on the rendered surface) or deferred to a named section. A control disabled with no named owner is missing, not deferred. Shipping a surface updates `docs/user/` in the same commit, and follows [`../standards/ui.md`](../standards/ui.md).

## Section sizing

Max 30 checklist items per section (`validate` warns above that). Split where the work genuinely divides: a different layer, a different dependency. Split at authoring time, not mid-implementation.

## Work items: one checkbox is one buildable step

1. **One action.** One file, class, function, command, or control.
2. **A named path** in backticks.
3. **Done when:** the observable end state, in the same bullet.
4. **The cheaper substitute** on any UI or write item, so the checkpoint can fail on it.
5. **A source** when behavior is copied: a file and line, or a Microsoft Learn page for a Win32 API.

## The implementation plan

[`implementation-plan.md`](./implementation-plan.md) is prose a person reads, with derived boxes:

- A phase is a heading `### Phase <N> -- <Title>`, one paragraph on why it runs where it does, then one table `| ✔ | Section | Deliverable | Items |`.
- **Every section in the tree appears in exactly one row**, no earlier than anything it depends on.
- The boxes, the Items column, and the `> **Progress:**` line are rewritten by `plan --sync`. **Never tick a box by hand.**

## Tooling

```bash
python scripts/todo-graph.py validate          # structure, graph, stamps, plan parity; FATAL fails
python scripts/todo-graph.py plan --sync       # re-derive the plan boxes, items, and progress
python scripts/todo-graph.py plan --check      # fail if the plan is stale
python scripts/todo-graph.py query ready       # dependency-met sections: runnable now, then runnable elsewhere
python scripts/todo-graph.py query blocked     # sections waiting, and on what
python scripts/todo-graph.py query stats       # tree health
python scripts/todo-graph.py resolve 'D01 T01 §2'   # ref -> file, section, deps; exit 3 shipped, 4 blocked, 5 operator-only
python scripts/todo-graph.py self-test         # the tool's own fixtures
```

**Operator-only work.** Every section in `todo/99-manual/` is work only the operator does (accounts, secrets, approvals, machine-wide installs, judging by eye or ear). `query ready` lists those rows under "runnable elsewhere" and ends with the line `<N> runnable now, <M> runnable elsewhere`; `resolve` exits 5 for one. An agent, and above all an unattended `process-plan` run, never starts an operator-only section; the operator runs it, or passes `--context operator` to see it as runnable now. Nothing outside `todo/99-manual/` may need a person.

`resolve` takes whatever you have in front of you, including a row pasted from the plan, so this is a complete instruction:

```
process todo section: | [ ] | `D01 T01 §1` | Prompt CRUD in the repository | 7 |
```

The commit hook (`tools/githooks/pre-commit`) runs `validate` on the staged tree, and CI runs `self-test`, `validate`, and `plan --check`.
