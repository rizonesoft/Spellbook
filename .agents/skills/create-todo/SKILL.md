---
name: create-todo
description: Author a whole new TODO file -- frontmatter, Goal, Current state, Inputs, Outcome, Implementation Order, sections, Verification -- then wire the indexes, XREFs, and the plan. Use when add-todo routes here.
---

# Create TODO

A new file is warranted when a subject no existing file owns needs a durable home. Most work does not need one: `add-todo` decides.

## 1. Confirm the home

Name the domain and the next free `TODO-NN` in it. A new domain is allowed when no domain owns the subject: create `todo/NN-kebab-name/INDEX.md` (copy an existing domain index), take the next free number, and add it to the Domain order table in `todo/TODO-00-INDEX.md`.

## 2. Author from the template

Copy [`todo-template.md`](todo-template.md) to `todo/<domain>/TODO-NN-<short-name>.md` and fill every part:

- **Frontmatter:** a globally unique kebab-case `id`, `domain` equal to the folder, `status: draft`, `title`, `frozen: true` when it touches a frozen behavior (`todo/README.md`, Frozen behavior).
- **Goal:** one paragraph, true when the file is done.
- **Current state:** what exists right now, with real paths, verified that day.
- **Inputs:** files, specs, Microsoft Learn pages, and `-> XREF:` lines to related sections.
- **Outcome:** observable end states.
- **Implementation Order:** one row per section, real `Depends On` edges.
- **Sections:** context, micro-steps with `Done when:`, `Commit:`, `Test checkpoint:`; surface sections add `Job:`, `Treatment:`, and `Chrome:`; frozen writes add `Freeze check:`.
- **Verification:** the file-level checks.

Every section must be implementable with zero conversation context: no "as discussed".

## 3. Wire it in

- List the file in the domain `INDEX.md` (the file name must appear verbatim) and, when it is active work, in `todo/TODO-00-INDEX.md`.
- Reciprocate every `-> XREF:`: each target file carries an `-> XREF:` back, or `validate` is FATAL.
- Place every section in exactly one phase table of `todo/implementation-plan.md`, no earlier than anything it depends on.

```bash
python scripts/todo-graph.py plan --sync
python scripts/todo-graph.py validate
```

## 4. Commit and report

Commit as `todo: author <id> (<n> sections)`. Report the file, its phase placement, and its dependency edges.

Codex owns this independent skill. Use `git -c core.hooksPath=.codex/githooks commit` for commits; inspect every dirty file first and preserve safe user side edits.
