---
name: add-todo
description: Front door for new work -- search the tree and the backlog for an existing home first, then route to an existing section, a new section, a whole new file via create-todo, or the backlog. Use whenever work needs capturing, a bug needs a plan home, or a backlog entry is promoted.
---

# Add TODO

New work enters the plan through here. The failure this prevents is the near-duplicate: the same work filed twice, with two owners and neither complete. The second failure is lost work: an idea dropped because it had nowhere to go. Both are worse than a slightly longer section.

## 1. Search before filing

```bash
rg -n -i "<keywords>" todo/ -g "TODO-*.md" | Select-Object -First 30
rg -n -i "<keywords>" todo/backlog.md
python scripts/todo-graph.py query stats
```

Read the candidates. A home exists when a section's scope already covers the work, even if its checklist does not name it yet. Domains follow the milestones, so look in the milestone the work belongs to first, then in `00-workspace` for tooling.

## 2. Route to one of five outcomes

| Outcome | When | How |
| ------- | ---- | --- |
| **Item on an open section** | an open `[ ]` section's scope holds it | add a micro-step with `Done when:`; the row stays where it is |
| **New section in an existing file** | the file's subject owns it but no section does | append `## N.` before `## Verification`, add its Implementation Order row, place it in a phase of `implementation-plan.md` |
| **New file** | no file owns the subject | the `create-todo` skill |
| **New section after a shipped one** | the work changes stamped behavior (a bug, a gap) | a new section; never reopen a stamped checklist |
| **Backlog entry** | worth keeping, not planned for v0.1.0 | one line in `todo/backlog.md` with the next `B-NNN` |

Work the operator asks for in a session is planned work: it gets a section, not a backlog line, unless the operator says "later".

## 3. Write it buildable

Every new item or section follows `todo/README.md`: one action, a named path, `Done when:`, the cheaper substitute on UI or write items, a `Commit:` item, and a falsifiable `Test checkpoint:`. Dependencies go in `Depends On` with `§N`, `TNN §N`, or `DNN TNN §N`.

## 4. Promote a backlog entry

Write the section, then delete the backlog line in the same commit, and name the entry's `source:` key in the section's context paragraph.

## 5. Validate and commit

```bash
python scripts/todo-graph.py plan --sync
python scripts/todo-graph.py validate
```

Commit as `todo: file <what> in DNN TNN §N` (or `todo: backlog B-NNN <title>`).

Codex owns this independent skill. Use `git -c core.hooksPath=.codex/githooks commit` for commits; inspect every dirty file first and preserve safe user side edits.
